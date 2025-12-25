/**
 * Google Gemini API Service
 * Extracts structured crop data from conversation transcripts
 */

const GEMINI_API_KEY = import.meta.env.VITE_GEMINI_API_KEY || 'AIzaSyAm_xQf5quGHSqLqe7Ui6lyDVJRdGlBFRU';
const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

// Rate limiting: Free tier allows 5 requests per minute
const MAX_REQUESTS_PER_MINUTE = 5;
const REQUEST_DELAY_MS = 15000; // 15 seconds between requests (60s / 5 = 12s, add 3s buffer for safety)

// Track last request time for rate limiting
let lastRequestTime = 0;
let requestQueue: Array<() => Promise<any>> = [];
let isProcessingQueue = false;

export interface ExtractedCropData {
  cropType?: string;
  variety?: string;
  harvestQuantity?: number;
  sowingDate?: string;
  harvestDate?: string;
  pricePerKg?: number;
  certification?: string;
  grading?: string;
  labTest?: string;
  freshnessDuration?: number;
  farmLocation?: string;
  farmerName?: string;
  confidence?: number;
}

/**
 * Extract structured data from conversation transcript using Gemini AI
 */
export async function extractCropDataFromTranscript(
  transcript: Array<{ sender: string; message: string; timestamp: string }>,
  callSummary?: string
): Promise<ExtractedCropData> {
  if (!GEMINI_API_KEY) {
    console.warn('⚠️ Gemini API key not configured');
    return {};
  }

  try {
    // Build conversation text from transcript
    const conversationText = transcript
      .map((msg) => {
        const sender = msg.sender === 'BOT' ? 'Bot' : 'Farmer';
        return `${sender}: ${msg.message}`;
      })
      .join('\n');

    // Create prompt for Gemini - Focus on essential fields for batch registration
    const prompt = `You are an agricultural data extraction assistant. Analyze the following phone conversation transcript between a bot and a farmer about crop registration, and extract ONLY the essential structured information required for batch registration.

CRITICAL FIELDS TO EXTRACT (These are REQUIRED for batch registration):
1. variety: The specific variety of the crop (e.g., "Basmati", "Pusa Basmati 1121", "Lakadong", "HD-3086")
2. harvestQuantity: The quantity harvested in KILOGRAMS (convert quintals to kg: 1 quintal = 100 kg)
   - If farmer says "100 quintal" or "100 क्विंटल", convert to 10000 kg
   - If farmer says "300 kilo" or "300 kg", use 300 kg
3. sowingDate: Date when crop was sown (format: YYYY-MM-DD)
   - If farmer says "7 January 2024" or "7 जनवरी 2024", convert to "2024-01-07"
   - If only month/year mentioned, use first day of that month
4. harvestDate: Date when crop was harvested (format: YYYY-MM-DD)
   - Extract from conversation or infer from context
5. pricePerKg: Price per kilogram in Indian Rupees (₹)
   - Extract price mentioned, ensure it's per kg (not per quintal)

ADDITIONAL FIELDS (Optional but helpful):
- cropType: The type of crop (e.g., Rice, Wheat, Maize, Turmeric, Black Gram, Green Chili, Coconut, Onion, Potato, Tomato)
- certification: Certification type if mentioned
- grading: Grading if mentioned
- farmLocation: Location/farm location if mentioned

Conversation Transcript:
${conversationText}

${callSummary ? `\nCall Summary: ${callSummary}` : ''}

CRITICAL INSTRUCTIONS:
1. Extract ONLY information explicitly mentioned in the conversation
2. For harvestQuantity: ALWAYS convert to kilograms
   - "100 quintal" or "100 क्विंटल" = 10000 kg
   - "50 quintal" or "50 क्विंटल" = 5000 kg
   - "300 kilo" or "300 kg" = 300 kg
3. For dates: Convert to YYYY-MM-DD format
   - "7 January 2024" = "2024-01-07"
   - "7 जनवरी 2024" = "2024-01-07"
   - If only year mentioned, use current year or reasonable estimate
4. For variety: Extract the exact variety name mentioned (e.g., "Basmati", "बासमती")
5. For pricePerKg: Extract price per kilogram, not per quintal
6. Return ONLY valid JSON format, no additional text or explanation
7. Use null for fields that are NOT mentioned in the conversation
8. Set confidence based on how many critical fields were extracted (0.0 to 1.0)

Return the extracted data as a JSON object with this exact structure:
{
  "variety": "string or null",
  "harvestQuantity": number or null,
  "sowingDate": "YYYY-MM-DD or null",
  "harvestDate": "YYYY-MM-DD or null",
  "pricePerKg": number or null,
  "cropType": "string or null",
  "certification": "string or null",
  "grading": "string or null",
  "farmLocation": "string or null",
  "confidence": number between 0 and 1
}`;

    console.log('🤖 Sending transcript to Gemini API for extraction...');
    console.log('📝 Transcript length:', conversationText.length, 'characters');

    // Rate limiting: Wait if needed before making request
    await waitForRateLimit();

    // Retry logic for rate limit errors
    const maxRetries = 3;
    let lastError: any = null;

    for (let attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        const response = await fetch(`${GEMINI_API_URL}?key=${GEMINI_API_KEY}`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            contents: [
              {
                parts: [
                  {
                    text: prompt,
                  },
                ],
              },
            ],
          }),
        });

        if (!response.ok) {
          const errorText = await response.text();
          let errorData: any = {};
          try {
            errorData = JSON.parse(errorText);
          } catch {
            errorData = { message: errorText };
          }

          // Handle rate limit (429) with retry
          if (response.status === 429) {
            const errorMessage = errorData.error?.message || '';
            const isDailyQuota = errorMessage.includes('20') || 
                                 errorMessage.includes('daily') ||
                                 errorData.error?.details?.some((d: any) => 
                                   d.quotaId?.includes('PerDay') || 
                                   d.quotaValue === '20'
                                 );
            
            if (isDailyQuota) {
              // Daily quota exceeded - don't retry, just throw with specific message
              console.error('❌ Gemini API daily quota exceeded (20 requests/day). Please wait until tomorrow or upgrade your plan.');
              throw new Error('Gemini API daily quota exceeded (20 requests/day). Please wait until tomorrow or upgrade your plan.');
            }
            
            const retryAfter = errorData.error?.details?.find((d: any) => d['@type'] === 'type.googleapis.com/google.rpc.RetryInfo')?.retryDelay;
            const waitTime = retryAfter ? parseInt(retryAfter) * 1000 : Math.pow(2, attempt) * 1000; // Exponential backoff
            
            console.warn(`⚠️ Rate limit hit (429). Attempt ${attempt}/${maxRetries}. Waiting ${waitTime}ms before retry...`);
            
            if (attempt < maxRetries) {
              await new Promise(resolve => setTimeout(resolve, waitTime));
              lastRequestTime = Date.now(); // Reset rate limit timer
              continue; // Retry
            } else {
              console.error('❌ Gemini API rate limit exceeded after retries:', response.status, errorText);
              throw new Error(`Gemini API rate limit exceeded. Please wait a minute and try again. Status: ${response.status}`);
            }
          }

          // For other errors, throw immediately
          console.error('❌ Gemini API error:', response.status, errorText);
          throw new Error(`Gemini API failed: ${response.status} - ${errorText}`);
        }

        // Success - update last request time
        lastRequestTime = Date.now();
        
        // Parse response
        const result = await response.json();
        console.log('✅ Gemini API response received');
        
        // Extract text from Gemini response
        const responseText =
          result.candidates?.[0]?.content?.parts?.[0]?.text || '';

        if (!responseText) {
          console.warn('⚠️ No text in Gemini response');
          return {};
        }

        console.log('📄 Gemini extracted text:', responseText.substring(0, 500));

        // Try to extract JSON from the response
        // Gemini might return text with JSON embedded, so we need to extract it
        let jsonText = responseText.trim();

        // Remove markdown code blocks if present
        jsonText = jsonText.replace(/```json\n?/g, '').replace(/```\n?/g, '');

        // Try to find JSON object in the response
        const jsonMatch = jsonText.match(/\{[\s\S]*\}/);
        if (jsonMatch) {
          jsonText = jsonMatch[0];
        }

        // Parse JSON
        let extractedData: ExtractedCropData;
        try {
          extractedData = JSON.parse(jsonText);
          console.log('✅ Successfully parsed Gemini extraction:', extractedData);
        } catch (parseError) {
          console.error('❌ Failed to parse Gemini JSON:', parseError);
          console.error('📄 Raw response text:', responseText);
          // Try to extract fields manually using regex as fallback
          extractedData = extractFieldsManually(responseText, conversationText);
        }

        // Validate and normalize the extracted data
        return normalizeExtractedData(extractedData);
        
      } catch (error: any) {
        lastError = error;
        if (error.message?.includes('rate limit') && attempt < maxRetries) {
          // Continue retry loop
          continue;
        }
        // If it's not a rate limit error or we've exhausted retries, break
        break;
      }
    }

    // If we get here, all retries failed
    console.error('❌ Error extracting data with Gemini after retries:', lastError);
    throw lastError || new Error('Failed to extract data from Gemini API');
  } catch (error) {
    console.error('❌ Error extracting data with Gemini:', error);
    // Return empty object on error - caller can handle fallback
    return {};
  }
}

/**
 * Rate limiting helper: Wait if needed before making a request
 * Ensures minimum 15 seconds between Gemini API calls
 */
async function waitForRateLimit(): Promise<void> {
  const now = Date.now();
  const timeSinceLastRequest = now - lastRequestTime;
  
  if (timeSinceLastRequest < REQUEST_DELAY_MS) {
    const waitTime = REQUEST_DELAY_MS - timeSinceLastRequest;
    console.log(`⏳ Rate limiting: Waiting ${Math.round(waitTime / 1000)}s before next Gemini API request...`);
    await new Promise(resolve => setTimeout(resolve, waitTime));
  }
  
  // Always update last request time, even if we didn't wait
  lastRequestTime = Date.now();
}

/**
 * Fallback: Manually extract fields using regex patterns
 */
function extractFieldsManually(
  responseText: string,
  conversationText: string
): ExtractedCropData {
  const extracted: ExtractedCropData = {};

  // Extract crop type
  const cropMatch =
    responseText.match(/"cropType"\s*:\s*"([^"]+)"/i) ||
    conversationText.match(/(?:crop|फसल)[\s:]+(?:is|are|का|की)?[\s:]+(Rice|Wheat|Maize|Turmeric|Black Gram|Green Chili|Coconut|Onion|Potato|Tomato|चावल|गेहूं|मक्का|हल्दी)/i);
  if (cropMatch) {
    extracted.cropType = cropMatch[1];
  }

  // Extract variety (Basmati, etc.)
  const varietyMatch =
    responseText.match(/"variety"\s*:\s*"([^"]+)"/i) ||
    conversationText.match(/(Basmati|Pusa|Lakadong|बासमती)/i);
  if (varietyMatch) {
    extracted.variety = varietyMatch[1];
  }

  // Extract quantity
  const qtyMatch =
    responseText.match(/"harvestQuantity"\s*:\s*(\d+)/i) ||
    conversationText.match(/(\d+)\s*(?:quintal|क्विंटल|kg|किलो)/i);
  if (qtyMatch) {
    const qty = parseInt(qtyMatch[1]);
    // Convert quintal to kg if mentioned
    if (
      conversationText.toLowerCase().includes('quintal') ||
      conversationText.includes('क्विंटल')
    ) {
      extracted.harvestQuantity = qty * 100;
    } else {
      extracted.harvestQuantity = qty;
    }
  }

  // Extract location
  const locationMatch =
    responseText.match(/"farmLocation"\s*:\s*"([^"]+)"/i) ||
    conversationText.match(/(?:location|स्थान)[\s:]+([A-Za-z\s,]+)/i);
  if (locationMatch) {
    extracted.farmLocation = locationMatch[1].trim();
  }

  return extracted;
}

/**
 * Normalize and validate extracted data
 */
function normalizeExtractedData(
  data: ExtractedCropData
): ExtractedCropData {
  const normalized: ExtractedCropData = { ...data };

  // Normalize cropType
  if (normalized.cropType) {
    const cropLower = normalized.cropType.toLowerCase();
    if (cropLower.includes('rice') || cropLower.includes('चावल')) {
      normalized.cropType = 'Rice';
    } else if (cropLower.includes('wheat') || cropLower.includes('गेहूं')) {
      normalized.cropType = 'Wheat';
    } else if (cropLower.includes('maize') || cropLower.includes('मक्का')) {
      normalized.cropType = 'Maize';
    } else if (
      cropLower.includes('turmeric') ||
      cropLower.includes('हल्दी')
    ) {
      normalized.cropType = 'Turmeric';
    }
    // Ensure it's a valid crop type
    const validCrops = [
      'Rice',
      'Wheat',
      'Maize',
      'Turmeric',
      'Black Gram',
      'Green Chili',
      'Coconut',
      'Onion',
      'Potato',
      'Tomato',
    ];
    if (!validCrops.includes(normalized.cropType)) {
      // Try to match partial
      const matched = validCrops.find((c) =>
        normalized.cropType?.toLowerCase().includes(c.toLowerCase())
      );
      if (matched) {
        normalized.cropType = matched;
      }
    }
  }

  // Normalize variety (especially for Basmati rice)
  if (normalized.variety) {
    const varietyLower = normalized.variety.toLowerCase();
    if (varietyLower.includes('basmati') || varietyLower.includes('बासमती')) {
      normalized.variety = 'Basmati';
      if (!normalized.cropType) {
        normalized.cropType = 'Rice';
      }
    }
    // Clean up variety name
    normalized.variety = normalized.variety.trim();
  }
  
  // Ensure harvestQuantity is properly converted from quintals
  if (normalized.harvestQuantity) {
    // If it's less than 100, it might be in quintals (assuming farmers usually harvest more than 100 kg)
    // But we trust Gemini's conversion, so just ensure it's a number
    normalized.harvestQuantity = Math.round(Number(normalized.harvestQuantity));
  }
  
  // Normalize dates to YYYY-MM-DD format
  if (normalized.sowingDate && typeof normalized.sowingDate === 'string') {
    // If date is not in YYYY-MM-DD format, try to parse it
    const dateMatch = normalized.sowingDate.match(/(\d{4})-(\d{2})-(\d{2})/);
    if (!dateMatch) {
      // Try to parse other formats
      const parsed = new Date(normalized.sowingDate);
      if (!isNaN(parsed.getTime())) {
        normalized.sowingDate = parsed.toISOString().split('T')[0];
      }
    }
  }
  
  if (normalized.harvestDate && typeof normalized.harvestDate === 'string') {
    const dateMatch = normalized.harvestDate.match(/(\d{4})-(\d{2})-(\d{2})/);
    if (!dateMatch) {
      const parsed = new Date(normalized.harvestDate);
      if (!isNaN(parsed.getTime())) {
        normalized.harvestDate = parsed.toISOString().split('T')[0];
      }
    }
  }

  // Ensure harvestQuantity is a number
  if (normalized.harvestQuantity) {
    normalized.harvestQuantity = Number(normalized.harvestQuantity);
  }

  // Ensure pricePerKg is a number
  if (normalized.pricePerKg) {
    normalized.pricePerKg = Number(normalized.pricePerKg);
  }

  // Set confidence if not provided
  if (!normalized.confidence) {
    // Calculate confidence based on how many fields were extracted
    const fieldsExtracted = [
      normalized.cropType,
      normalized.variety,
      normalized.harvestQuantity,
      normalized.sowingDate,
      normalized.harvestDate,
      normalized.pricePerKg,
    ].filter(Boolean).length;

    normalized.confidence = Math.min(0.5 + fieldsExtracted * 0.1, 0.95);
  }

  return normalized;
}


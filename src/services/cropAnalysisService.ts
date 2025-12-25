/**
 * Crop Analysis Service
 * Sends soil data to Gemini for crop quality analysis based on soil conditions
 */

import { SoilDataResponse } from './iotSoilDataService';

const GEMINI_API_KEY = import.meta.env.VITE_GEMINI_API_KEY || 'AIzaSyAm_xQf5quGHSqLqe7Ui6lyDVJRdGlBFRU';
const GEMINI_API_URL = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent';

export interface CropQualityAnalysisResponse {
  qualityAssessment: string;
  qualityScore: number; // 0-100
  recommendations: string[];
  soilRecommendations: string[];
  overallAssessment: string;
  expectedYield?: string;
  cropQuality?: 'Excellent' | 'Good' | 'Fair' | 'Poor';
}

/**
 * Analyze crop quality based on soil data using Gemini AI
 */
export async function analyzeCropQualityFromSoil(
  soilData: SoilDataResponse,
  cropType?: string,
  variety?: string
): Promise<CropQualityAnalysisResponse> {
  if (!GEMINI_API_KEY) {
    console.error('❌ Gemini API key not configured');
    throw new Error('Gemini API key is required for crop quality analysis. Please configure VITE_GEMINI_API_KEY in your .env file.');
  }

  try {
    // Build analysis prompt focused on crop quality based on soil data
    const prompt = `You are an agricultural expert analyzing crop quality based on soil conditions. Provide a comprehensive analysis based on the following IoT soil sensor data:

CROP INFORMATION:
- Crop Type: ${cropType || 'Not specified'}
- Variety: ${variety || 'Not specified'}

SOIL DATA FROM IoT DEVICE:
${soilData.temperature !== undefined && soilData.temperature !== null ? `- Temperature: ${soilData.temperature}°C` : ''}
${soilData.humidity !== undefined && soilData.humidity !== null ? `- Humidity: ${soilData.humidity}%` : ''}
${(soilData.soilMoisture !== undefined && soilData.soilMoisture !== null) || (soilData.moisture !== undefined && soilData.moisture !== null) ? `- Soil Moisture: ${soilData.soilMoisture !== undefined ? soilData.soilMoisture : soilData.moisture}%` : ''}
${soilData.ldr !== undefined && soilData.ldr !== null ? `- Light Level (LDR): ${soilData.ldr}` : ''}
${soilData.gas !== undefined && soilData.gas !== null ? `- Gas Reading: ${soilData.gas}` : ''}
${soilData.rain !== undefined && soilData.rain !== null ? `- Rain Sensor: ${soilData.rain}` : ''}
${soilData.receivedAt ? `- Data Timestamp: ${soilData.receivedAt}` : ''}
${soilData.ph !== undefined && soilData.ph !== null ? `- pH Level: ${soilData.ph}` : ''}
${soilData.nitrogen !== undefined && soilData.nitrogen !== null ? `- Nitrogen (N): ${soilData.nitrogen} ppm` : ''}
${soilData.phosphorus !== undefined && soilData.phosphorus !== null ? `- Phosphorus (P): ${soilData.phosphorus} ppm` : ''}
${soilData.potassium !== undefined && soilData.potassium !== null ? `- Potassium (K): ${soilData.potassium} ppm` : ''}
${soilData.organicMatter !== undefined && soilData.organicMatter !== null ? `- Organic Matter: ${soilData.organicMatter}%` : ''}

Based on this soil data, analyze the expected crop quality and provide recommendations.

Please provide a comprehensive analysis in the following JSON format:
{
  "qualityAssessment": "Write EXACTLY 5 lines, each on a new line. Use simple, clear language that anyone can understand. Line 1: Overall crop health status (Good/Fair/Poor). Line 2: Main soil condition affecting quality (temperature/moisture/pH). Line 3: Expected crop performance (yield and quality). Line 4: Key quality indicators (grain size/color/aroma). Line 5: Overall outlook (what to expect). Keep each line short (max 15-20 words). Use simple words, avoid technical terms.",
  "qualityScore": 85,
  "recommendations": ["Recommendation 1 for improving crop quality", "Recommendation 2", "Recommendation 3"],
  "soilRecommendations": ["Soil-specific improvement recommendation 1", "Soil-specific improvement recommendation 2"],
  "overallAssessment": "Overall assessment of expected crop quality and yield potential based on current soil conditions (1 paragraph)",
  "expectedYield": "Expected yield potential: High/Medium/Low",
  "cropQuality": "Excellent"
}

Instructions:
1. qualityAssessment MUST be EXACTLY 5 lines - concise, clear, simple language
2. Analyze how soil parameters affect crop quality for ${cropType || 'the crop'} in simple terms
3. Provide a quality score from 0-100 based on soil conditions
4. Categorize crop quality as: "Excellent" (80-100), "Good" (60-79), "Fair" (40-59), or "Poor" (0-39)
5. Give specific, actionable recommendations to improve crop quality
6. Assess expected yield potential based on soil data
7. Use SIMPLE, CLEAR language - avoid complex agricultural terms
8. Return ONLY valid JSON, no additional text or markdown formatting`;

    console.log('🤖 Sending soil data to Gemini for crop quality analysis...');

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
      console.error('❌ Gemini API error:', response.status, errorText);
      throw new Error(`Gemini API failed: ${response.status} - ${errorText}`);
    }

    const result = await response.json();
    console.log('✅ Gemini API response received');
    console.log('📊 Full Gemini Response:', JSON.stringify(result, null, 2));
    console.log('📊 Response Keys:', Object.keys(result));
    console.log('📊 Candidates:', result.candidates);

    // Extract text from Gemini response
    const responseText =
      result.candidates?.[0]?.content?.parts?.[0]?.text || '';

    console.log('📄 Raw Gemini Response Text Length:', responseText.length);
    console.log('📄 Gemini Response Text (first 1000 chars):', responseText.substring(0, 1000));

    if (!responseText) {
      console.error('❌ No text in Gemini response');
      console.error('❌ Full response structure:', result);
      throw new Error('Gemini API returned empty response. Please try again.');
    }

    // Try to extract JSON from the response
    let jsonText = responseText.trim();
    jsonText = jsonText.replace(/```json\n?/g, '').replace(/```\n?/g, '');
    const jsonMatch = jsonText.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      jsonText = jsonMatch[0];
    }

    // Parse JSON
    let analysisData: CropQualityAnalysisResponse;
    try {
      analysisData = JSON.parse(jsonText);
      console.log('✅ Successfully parsed Gemini crop quality analysis:', analysisData);
      
      // Ensure qualityAssessment is exactly 5 lines - from Gemini only, no mock data
      if (analysisData.qualityAssessment) {
        const lines = analysisData.qualityAssessment.split('\n').filter((line: string) => line.trim().length > 0);
        if (lines.length > 5) {
          // Take first 5 lines from Gemini
          analysisData.qualityAssessment = lines.slice(0, 5).join('\n');
          console.log('✅ Quality assessment trimmed to 5 lines from Gemini');
        } else if (lines.length < 5) {
          // If Gemini didn't provide 5 lines, log warning but use what Gemini provided
          console.warn(`⚠️ Gemini provided only ${lines.length} lines, expected 5. Using Gemini's response as-is.`);
          analysisData.qualityAssessment = lines.join('\n');
        } else {
          console.log('✅ Quality assessment has exactly 5 lines from Gemini');
        }
      } else {
        throw new Error('Gemini API did not return qualityAssessment field');
      }
    } catch (parseError) {
      console.error('❌ Failed to parse Gemini JSON:', parseError);
      console.error('❌ Raw response text:', responseText.substring(0, 500));
      throw new Error(`Failed to parse Gemini API response. Please ensure Gemini API is working correctly. Error: ${parseError instanceof Error ? parseError.message : 'Unknown error'}`);
    }

    // Ensure arrays are arrays
    if (!Array.isArray(analysisData.recommendations)) {
      analysisData.recommendations = analysisData.recommendations
        ? [analysisData.recommendations]
        : [];
    }
    if (!Array.isArray(analysisData.soilRecommendations)) {
      analysisData.soilRecommendations = analysisData.soilRecommendations
        ? [analysisData.soilRecommendations]
        : [];
    }

    // Ensure quality score is within 0-100
    if (analysisData.qualityScore < 0) analysisData.qualityScore = 0;
    if (analysisData.qualityScore > 100) analysisData.qualityScore = 100;

    // Determine crop quality category if not provided
    if (!analysisData.cropQuality) {
      if (analysisData.qualityScore >= 80) {
        analysisData.cropQuality = 'Excellent';
      } else if (analysisData.qualityScore >= 60) {
        analysisData.cropQuality = 'Good';
      } else if (analysisData.qualityScore >= 40) {
        analysisData.cropQuality = 'Fair';
      } else {
        analysisData.cropQuality = 'Poor';
      }
    }

    return analysisData;
  } catch (error) {
    console.error('❌ Error analyzing crop quality from soil data:', error);
    // Re-throw error - don't return mock data, let the caller handle it
    throw new Error(`Failed to analyze crop quality with Gemini API: ${error instanceof Error ? error.message : 'Unknown error'}`);
  }
}


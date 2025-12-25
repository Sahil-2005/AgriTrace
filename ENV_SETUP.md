# Environment Variables Setup

## Required Environment Variables

Create a `.env` file in the project root directory with the following variables:

```env
# VoiceGenie API Configuration (Required for Helper Desk)
VITE_VOICEGENIE_API_KEY=your_voicegenie_api_key_here

# Hugging Face API Configuration (Optional - for Crop Health Detection)
# Get your API key from: https://huggingface.co/settings/tokens
VITE_HUGGINGFACE_API_KEY=your_huggingface_api_key_here

# Google Gemini API Configuration (Required for VoiceGenie transcript extraction)
# Get your API key from: https://makersuite.google.com/app/apikey
VITE_GEMINI_API_KEY=your_gemini_api_key_here

# Supabase Configuration (if not already set)
VITE_SUPABASE_URL=your_supabase_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
```

## Quick Setup

1. **Create `.env` file** in the project root:
   ```bash
   touch .env
   ```

2. **Add the VoiceGenie API key**:
   ```env
   VITE_VOICEGENIE_API_KEY=your_actual_api_key_here
   ```

3. **Restart your development server**:
   ```bash
   # Stop the current server (Ctrl+C)
   # Then restart:
   npm run dev
   ```

## Getting Your API Keys

### VoiceGenie API Key

1. Log in to your VoiceGenie account
2. Navigate to API Settings or Developer Settings
3. Generate or copy your API key
4. Add it to your `.env` file

### Hugging Face API Key (Optional - for Crop Health Detection)

1. Go to https://huggingface.co/settings/tokens
2. Sign in or create a free account
3. Click "New token"
4. Give it a name (e.g., "AgriTrace")
5. Select "Read" permission
6. Copy the token
7. Add it to your `.env` file as `VITE_HUGGINGFACE_API_KEY`

**Note:** The Crop Health Detection feature will work without an API key (using mock analysis), but for production use with the actual AI model, you'll need a Hugging Face API key.

### Google Gemini API Key (Required for VoiceGenie transcript extraction)

1. Go to [Google AI Studio](https://makersuite.google.com/app/apikey)
2. Sign in with your Google account
3. Click "Create API Key" or use an existing key
4. Copy the API key
5. Add it to your `.env` file as `VITE_GEMINI_API_KEY`

**Note:** The Gemini API is used to extract structured crop data (cropType, variety, harvestQuantity, sowingDate, harvestDate, pricePerKg) from VoiceGenie conversation transcripts. This makes the data extraction more accurate and reliable. The API key is already hardcoded in the service as a fallback, but it's recommended to set it in your `.env` file.

**Important:** The Gemini API free tier has a rate limit of **5 requests per minute**. The code automatically handles this by:
- Processing calls sequentially (not in parallel)
- Adding delays between requests (13 seconds)
- Retrying with exponential backoff if rate limit is hit
- This means processing 12 calls will take approximately 2-3 minutes

## Important Notes

- **Never commit `.env` to git** - it should be in `.gitignore`
- **Restart required**: After adding/changing environment variables, you must restart the dev server
- **VITE_ prefix**: All environment variables used in Vite must start with `VITE_`
- **No quotes needed**: Don't wrap the API key in quotes in the `.env` file

## Using Test Data (Development)

To use test data instead of the real API (for testing purposes), add this to your `.env`:

```env
VITE_USE_VOICEGENIE_TEST_DATA=true
```

This will use hardcoded test data with complete batch registration information instead of calling the API. Set to `false` or remove to use the real API.

**Test Data Includes:**
- 3 sample calls with all required fields
- Valid crop data (Rice, Turmeric, Wheat)
- High confidence scores (88-95%)
- All validation checks pass

See `voicegenie_test_response.json` for the complete test data structure.

## Troubleshooting

**Issue**: "VoiceGenie API key is not configured"
- ✅ Check that `.env` file exists in project root
- ✅ Check that variable name is exactly `VITE_VOICEGENIE_API_KEY`
- ✅ Check that there are no extra spaces or quotes
- ✅ Restart your development server
- ✅ Or use `VITE_USE_VOICEGENIE_TEST_DATA=true` to bypass API key requirement

**Issue**: Still getting errors after adding key
- Make sure the `.env` file is in the same directory as `package.json`
- Check for typos in the variable name
- Verify the API key is correct
- Clear browser cache and restart dev server
- Use test data mode (`VITE_USE_VOICEGENIE_TEST_DATA=true`) to verify the UI works

**Issue**: "429 Rate Limit Exceeded" errors from Gemini API
- ✅ This is normal for the free tier (5 requests/minute limit)
- ✅ The code automatically handles rate limiting by processing calls sequentially
- ✅ Processing many calls will take time (12 calls = ~2-3 minutes)
- ✅ The code will retry automatically with exponential backoff
- ✅ Consider upgrading to a paid Gemini API plan for higher limits
- ✅ Or wait a minute between batches of calls


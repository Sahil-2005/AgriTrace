# VoiceGenie Test Data Guide

## Overview
This guide explains how to use the test JSON response to test the Helper Desk functionality.

## Test Data File
The file `voicegenie_test_response.json` contains 3 sample calls with complete batch registration data:

1. **Rajesh Kumar** - Rice (Basmati) - 500 kg - ₹80/kg
2. **Priya Devi** - Turmeric (Lakadong) - 300 kg - ₹120/kg  
3. **Amit Singh** - Wheat (HD-3086) - 1000 kg - ₹25/kg

## All Required Fields Included

Each test call includes all required fields:
- ✅ `cropType` - Type of crop (Rice, Turmeric, Wheat)
- ✅ `variety` - Crop variety (Basmati, Lakadong, HD-3086)
- ✅ `harvestQuantity` - Quantity in kg (500, 300, 1000)
- ✅ `sowingDate` - Sowing date (YYYY-MM-DD format)
- ✅ `harvestDate` - Harvest date (YYYY-MM-DD format)
- ✅ `pricePerKg` - Price per kilogram (₹80, ₹120, ₹25)

## Additional Fields Included

- `farmerName` - Name of the farmer
- `location` / `farmLocation` - Location of the farm
- `language` - Language used (hi for Hindi)
- `certification` - Certification type (Organic, Standard)
- `grading` - Grade of the crop (Grade A, Premium)
- `labTest` - Lab test results
- `freshnessDuration` - Freshness duration in days
- `confidenceScore` - Confidence score (0.88 - 0.95)

## How to Use This Test Data

### Option 1: Update Your API Endpoint
Replace the response from `https://voiceagent-6h5b.onrender.com/api/calls` with the content from `voicegenie_test_response.json`.

### Option 2: Mock the API Response (For Development)
You can temporarily modify `src/services/voicegenieService.ts` to return this test data:

```typescript
export async function fetchVoiceGenieCalls(): Promise<VoiceGenieCall[]> {
  // TEMPORARY: Return test data
  const testData = await import('../../voicegenie_test_response.json');
  if (testData.default?.success && testData.default?.data) {
    return testData.default.data.map(mapRawCallToVoiceGenieCall);
  }
  
  // ... rest of the actual API call code
}
```

### Option 3: Use a Mock Server
Set up a local mock server that returns this JSON when called.

## Expected Behavior

When you use this test data:
1. ✅ All 3 calls should appear in the Helper Desk
2. ✅ All calls should show "Valid" status (green badge)
3. ✅ All calls should have high confidence scores (88-95%)
4. ✅ No validation errors should appear
5. ✅ "Approve & Register" button should be enabled (when wallet is connected)
6. ✅ All crop details should be displayed correctly

## Field Validation

The test data passes all validation checks:
- ✅ Harvest quantity is between 1 and 100,000 kg
- ✅ Price per kg is between ₹0.01 and ₹10,000
- ✅ Harvest date is after sowing date
- ✅ Crop types are valid (Rice, Turmeric, Wheat)
- ✅ All dates are in valid format (YYYY-MM-DD)

## Notes

- Phone numbers are dummy numbers (+919876543210, etc.)
- Dates are recent (within the last 6 months)
- All data is realistic and follows Indian agricultural patterns
- Confidence scores are high (0.88-0.95) to simulate successful calls


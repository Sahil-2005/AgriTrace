# OmniDim Integration Roadmap for AgriTrace Batch Registration

## Overview
This document outlines the complete integration plan for using OmniDim AI voice agent to register agricultural batches for farmers without internet access via phone calls.

## Architecture Flow

```
Farmer (No Internet) 
    ↓
OmniDim Outbound Call (Native Language)
    ↓
AI Agent Collects Information
    ↓
JSON File Generated
    ↓
Helper Desk Review Dashboard
    ↓
[APPROVED] → Blockchain Registration + Pinata Upload
[REJECTED] → Notification (Optional Callback)
```

---

## Phase 1: OmniDim Setup & Configuration

### Step 1.1: OmniDim Account Setup
- [ ] Create OmniDim account
- [ ] Configure outbound calling settings
- [ ] Set up phone number for outbound calls
- [ ] Configure call recording (for quality assurance)
- [ ] Set up webhook endpoints for call completion

### Step 1.2: Language Support
- [ ] Configure primary language (Hindi/Odia/Telugu based on region)
- [ ] Set up multi-language support if needed
- [ ] Test voice recognition for regional accents
- [ ] Configure fallback to English if needed

### Step 1.3: API Integration
- [ ] Set up OmniDim API credentials
- [ ] Configure webhook URL: `POST /api/omnidim/call-complete`
- [ ] Set up authentication tokens
- [ ] Test API connectivity

---

## Phase 2: Backend API Development

### Step 2.1: Create Helper Desk API Endpoints

**Endpoint 1: Receive OmniDim Call Data**
```
POST /api/omnidim/call-complete
Body: {
  callId: string,
  farmerPhone: string,
  farmerName: string,
  collectedData: BatchRegistrationData,
  callRecordingUrl?: string,
  language: string,
  confidenceScore: number
}
Response: {
  submissionId: string,
  status: 'pending_review'
}
```

**Endpoint 2: Helper Desk Review**
```
GET /api/helper-desk/pending-submissions
Response: Array<Submission>

GET /api/helper-desk/submission/:id
Response: Submission with full details

POST /api/helper-desk/submission/:id/approve
Body: {
  helperId: string,
  notes?: string
}
Response: {
  batchId: string,
  blockchainHash: string,
  ipfsHash: string,
  status: 'registered'
}

POST /api/helper-desk/submission/:id/reject
Body: {
  helperId: string,
  reason: string,
  notes?: string
}
Response: {
  status: 'rejected',
  notificationSent: boolean
}
```

### Step 2.2: Database Schema

**Create `omnidim_submissions` table:**
```sql
CREATE TABLE omnidim_submissions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  call_id TEXT UNIQUE NOT NULL,
  farmer_phone TEXT NOT NULL,
  farmer_name TEXT,
  farmer_location TEXT,
  submission_data JSONB NOT NULL,
  status TEXT DEFAULT 'pending_review' CHECK (status IN ('pending_review', 'approved', 'rejected', 'registered')),
  language TEXT DEFAULT 'hi',
  confidence_score NUMERIC(3,2),
  call_recording_url TEXT,
  helper_id UUID REFERENCES profiles(id),
  helper_notes TEXT,
  rejection_reason TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  reviewed_at TIMESTAMP WITH TIME ZONE,
  registered_at TIMESTAMP WITH TIME ZONE,
  batch_id UUID REFERENCES batches(id)
);
```

### Step 2.3: Batch Registration Service
- [ ] Create service function: `registerBatchFromOmniDim(submissionData)`
- [ ] Integrate with existing blockchain registration
- [ ] Integrate with Pinata certificate upload
- [ ] Handle errors and rollback logic
- [ ] Send confirmation SMS/callback to farmer

---

## Phase 3: Frontend Helper Desk Dashboard

### Step 3.1: Create Helper Desk Page
- [ ] Route: `/helper-desk` (protected, admin/helper role only)
- [ ] List pending submissions
- [ ] View submission details
- [ ] Approve/Reject buttons
- [ ] Show call recording playback (if available)
- [ ] Display confidence scores

### Step 3.2: Submission Review UI
- [ ] Display collected data in readable format
- [ ] Show farmer information
- [ ] Highlight missing/uncertain fields
- [ ] Allow manual data correction before approval
- [ ] Show validation errors

---

## Phase 4: OmniDim Prompt Development

### Step 4.1: Create Conversation Flow
- [ ] Greeting and introduction
- [ ] Farmer verification (phone number, name)
- [ ] Collect required fields systematically
- [ ] Confirm collected information
- [ ] Thank farmer and explain next steps

### Step 4.2: Error Handling
- [ ] Handle unclear responses
- [ ] Ask for clarification
- [ ] Retry mechanism for critical fields
- [ ] Graceful fallback if farmer hangs up

---

## Phase 5: Testing & Deployment

### Step 5.1: Testing
- [ ] Test with real farmers (pilot group)
- [ ] Validate data accuracy
- [ ] Test approval/rejection flow
- [ ] Test blockchain registration
- [ ] Test Pinata upload
- [ ] Test farmer notification

### Step 5.2: Deployment
- [ ] Deploy backend APIs
- [ ] Deploy helper desk dashboard
- [ ] Configure OmniDim production settings
- [ ] Set up monitoring and alerts
- [ ] Create user documentation

---

## Phase 6: Monitoring & Optimization

### Step 6.1: Analytics
- [ ] Track call success rate
- [ ] Monitor data quality scores
- [ ] Track approval/rejection rates
- [ ] Monitor registration success rate

### Step 6.2: Continuous Improvement
- [ ] Refine OmniDim prompt based on feedback
- [ ] Improve language recognition
- [ ] Optimize conversation flow
- [ ] Reduce call duration
- [ ] Improve data accuracy

---

## Technical Requirements

### Required Fields for Batch Registration

**Required Fields:**
1. `cropType` - Crop type (Rice, Wheat, Maize, Turmeric, Black Gram, Green Chili, Coconut)
2. `variety` - Variety name (e.g., Basmati, Pusa Basmati 1121)
3. `harvestQuantity` - Quantity in kg (number)
4. `sowingDate` - Date (YYYY-MM-DD format)
5. `harvestDate` - Date (YYYY-MM-DD format)
6. `pricePerKg` - Price per kg in ₹ (number)

**Optional Fields:**
7. `certification` - Certification type (Organic, Fair Trade, Standard, Premium)
8. `grading` - Grading (Premium, Standard, Basic) - defaults to "Standard"
9. `labTest` - Lab test results (text)
10. `freshnessDuration` - Freshness duration in days (number) - defaults to 7

**Farmer Information:**
11. `farmerName` - Full name
12. `farmerPhone` - Phone number (for verification)
13. `farmerLocation` - Farm location (optional)

---

## JSON Schema for OmniDim Response

```json
{
  "callId": "string",
  "farmerPhone": "string",
  "farmerName": "string",
  "farmerLocation": "string (optional)",
  "language": "string (e.g., 'hi', 'en', 'or')",
  "confidenceScore": 0.0-1.0,
  "callRecordingUrl": "string (optional)",
  "collectedData": {
    "cropType": "string (required)",
    "variety": "string (required)",
    "harvestQuantity": "number (required)",
    "sowingDate": "string YYYY-MM-DD (required)",
    "harvestDate": "string YYYY-MM-DD (required)",
    "pricePerKg": "number (required)",
    "certification": "string (optional)",
    "grading": "string (optional, default: 'Standard')",
    "labTest": "string (optional)",
    "freshnessDuration": "number (optional, default: 7)"
  },
  "validationErrors": ["string array"],
  "uncertainFields": ["string array"],
  "callDuration": "number (seconds)",
  "timestamp": "ISO 8601 string"
}
```

---

## Security Considerations

1. **Phone Number Verification**: Verify farmer phone number before registration
2. **Data Validation**: Validate all collected data before approval
3. **Helper Authentication**: Only authorized helpers can approve submissions
4. **Audit Trail**: Log all helper actions (approve/reject)
5. **Call Recording**: Store recordings securely for dispute resolution
6. **Rate Limiting**: Prevent spam submissions from same phone number

---

## Cost Considerations

1. **OmniDim Costs**: 
   - Outbound call charges per minute
   - API usage fees
   - Storage for call recordings

2. **Blockchain Costs**:
   - Gas fees for batch registration
   - Transaction fees

3. **Pinata Costs**:
   - IPFS storage costs
   - Bandwidth costs

---

## Success Metrics

1. **Call Success Rate**: % of calls that complete successfully
2. **Data Accuracy**: % of submissions with all required fields
3. **Approval Rate**: % of submissions approved by helpers
4. **Registration Success Rate**: % of approved submissions successfully registered
5. **Average Call Duration**: Target < 5 minutes
6. **Farmer Satisfaction**: Feedback from farmers

---

## Next Steps

1. Review and approve this roadmap
2. Set up OmniDim account and configure
3. Develop backend APIs
4. Create helper desk dashboard
5. Test with pilot farmers
6. Deploy to production
7. Monitor and optimize


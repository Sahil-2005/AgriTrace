# OmniDim Integration Implementation Steps

## Quick Start Guide

### Step 1: Set Up OmniDim Account (Day 1)

1. **Create OmniDim Account**
   - Go to https://omnidim.ai
   - Sign up for account
   - Choose "Outbound Calling" plan
   - Add payment method

2. **Configure Phone Number**
   - Purchase phone number for outbound calls
   - Set up caller ID (should show "AgriTrace" or "Odisha Govt")
   - Configure call recording (enable for quality assurance)

3. **Set Up API Credentials**
   - Generate API key from OmniDim dashboard
   - Save credentials securely (use environment variables)
   - Test API connectivity

---

### Step 2: Create Backend API Endpoints (Days 2-3)

#### 2.1 Create Database Table

Run this SQL in Supabase SQL Editor:

```sql
-- Create omnidim_submissions table
CREATE TABLE IF NOT EXISTS omnidim_submissions (
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

-- Create index for faster queries
CREATE INDEX IF NOT EXISTS idx_omnidim_submissions_status ON omnidim_submissions(status);
CREATE INDEX IF NOT EXISTS idx_omnidim_submissions_created_at ON omnidim_submissions(created_at DESC);

-- Enable RLS
ALTER TABLE omnidim_submissions ENABLE ROW LEVEL SECURITY;

-- Policy: Helpers can view all submissions
CREATE POLICY "Helpers can view all submissions" ON omnidim_submissions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role IN ('helper', 'admin')
    )
  );

-- Policy: Helpers can update submissions
CREATE POLICY "Helpers can update submissions" ON omnidim_submissions
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.id = auth.uid() 
      AND profiles.role IN ('helper', 'admin')
    )
  );

-- Policy: OmniDim webhook can insert submissions
CREATE POLICY "OmniDim webhook can insert" ON omnidim_submissions
  FOR INSERT WITH CHECK (true);
```

#### 2.2 Create API Route Handler

Create file: `src/pages/api/omnidim/call-complete.ts` (or similar based on your framework)

```typescript
import { supabase } from '@/integrations/supabase/client';
import { NextApiRequest, NextApiResponse } from 'next';

export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  // Verify OmniDim webhook signature (if available)
  // const signature = req.headers['x-omnidim-signature'];
  // verifySignature(signature, req.body);

  const {
    callId,
    farmerPhone,
    farmerName,
    farmerLocation,
    language,
    confidenceScore,
    callRecordingUrl,
    callDuration,
    collectedData,
    validationErrors,
    uncertainFields,
    notes
  } = req.body;

  try {
    // Validate required fields
    if (!callId || !farmerPhone || !farmerName || !collectedData) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    // Validate collected data
    const requiredFields = ['cropType', 'variety', 'harvestQuantity', 'sowingDate', 'harvestDate', 'pricePerKg'];
    const missingFields = requiredFields.filter(field => !collectedData[field]);
    
    if (missingFields.length > 0) {
      return res.status(400).json({ 
        error: 'Missing required fields in collectedData',
        missingFields 
      });
    }

    // Insert submission into database
    const { data: submission, error } = await supabase
      .from('omnidim_submissions')
      .insert({
        call_id: callId,
        farmer_phone: farmerPhone,
        farmer_name: farmerName,
        farmer_location: farmerLocation,
        submission_data: collectedData,
        language: language || 'hi',
        confidence_score: confidenceScore || 0.5,
        call_recording_url: callRecordingUrl,
        status: 'pending_review',
        validation_errors: validationErrors || [],
        uncertain_fields: uncertainFields || [],
        notes: notes
      })
      .select()
      .single();

    if (error) {
      console.error('Error saving submission:', error);
      return res.status(500).json({ error: 'Failed to save submission' });
    }

    // Send notification to helper desk (optional)
    // await notifyHelpers(submission.id);

    return res.status(200).json({
      submissionId: submission.id,
      status: 'pending_review',
      message: 'Submission received and queued for review'
    });

  } catch (error) {
    console.error('Error processing OmniDim submission:', error);
    return res.status(500).json({ error: 'Internal server error' });
  }
}
```

#### 2.3 Create Helper Desk API Routes

Create file: `src/pages/api/helper-desk/submissions.ts`

```typescript
import { supabase } from '@/integrations/supabase/client';
import { NextApiRequest, NextApiResponse } from 'next';

// GET /api/helper-desk/submissions
export default async function handler(req: NextApiRequest, res: NextApiResponse) {
  // Verify helper authentication
  const { data: profile } = await supabase
    .from('profiles')
    .select('role')
    .eq('user_id', req.user?.id)
    .single();

  if (!profile || !['helper', 'admin'].includes(profile.role)) {
    return res.status(403).json({ error: 'Unauthorized' });
  }

  if (req.method === 'GET') {
    const { status } = req.query;
    
    let query = supabase
      .from('omnidim_submissions')
      .select('*')
      .order('created_at', { ascending: false });

    if (status) {
      query = query.eq('status', status);
    }

    const { data, error } = await query;

    if (error) {
      return res.status(500).json({ error: error.message });
    }

    return res.status(200).json(data);
  }

  // POST /api/helper-desk/submissions/:id/approve
  if (req.method === 'POST' && req.query.action === 'approve') {
    const { id } = req.query;
    const { notes } = req.body;

    // Get submission
    const { data: submission, error: fetchError } = await supabase
      .from('omnidim_submissions')
      .select('*')
      .eq('id', id)
      .single();

    if (fetchError || !submission) {
      return res.status(404).json({ error: 'Submission not found' });
    }

    // Register batch (use existing batch registration logic)
    const batchResult = await registerBatchFromOmniDim(submission.submission_data, submission.farmer_phone);

    // Update submission status
    const { data: updated, error: updateError } = await supabase
      .from('omnidim_submissions')
      .update({
        status: 'registered',
        helper_id: req.user?.id,
        helper_notes: notes,
        reviewed_at: new Date().toISOString(),
        registered_at: new Date().toISOString(),
        batch_id: batchResult.batchId
      })
      .eq('id', id)
      .select()
      .single();

    if (updateError) {
      return res.status(500).json({ error: updateError.message });
    }

    // Send SMS notification to farmer
    await sendSMSNotification(submission.farmer_phone, {
      message: `Your batch has been registered successfully. Batch ID: ${batchResult.batchId}`,
      batchId: batchResult.batchId
    });

    return res.status(200).json({
      success: true,
      submission: updated,
      batchId: batchResult.batchId
    });
  }

  // POST /api/helper-desk/submissions/:id/reject
  if (req.method === 'POST' && req.query.action === 'reject') {
    const { id } = req.query;
    const { reason, notes } = req.body;

    const { data: updated, error } = await supabase
      .from('omnidim_submissions')
      .update({
        status: 'rejected',
        helper_id: req.user?.id,
        helper_notes: notes,
        rejection_reason: reason,
        reviewed_at: new Date().toISOString()
      })
      .eq('id', id)
      .select()
      .single();

    if (error) {
      return res.status(500).json({ error: error.message });
    }

    // Optional: Schedule callback to farmer
    // await scheduleCallback(updated.farmer_phone, reason);

    return res.status(200).json({ success: true, submission: updated });
  }

  return res.status(405).json({ error: 'Method not allowed' });
}
```

#### 2.4 Create Batch Registration Service Function

Create file: `src/services/omnidimBatchRegistration.ts`

```typescript
import { singleStepGroupManager } from '@/utils/singleStepGroupManager';
import { blockchainTransactionManager } from '@/utils/blockchainTransactionManager';
import { supabase } from '@/integrations/supabase/client';
import { registerBatch } from '@/hooks/useContract';

export async function registerBatchFromOmniDim(
  collectedData: any,
  farmerPhone: string
): Promise<{ batchId: string; blockchainHash: string; ipfsHash: string }> {
  
  // Step 1: Get or create farmer profile
  let farmerProfile = await getOrCreateFarmerProfile(farmerPhone, collectedData.farmerName);
  
  // Step 2: Generate harvest certificate and upload to Pinata
  const harvestData = {
    batchId: Date.now().toString(),
    farmerName: farmerProfile.full_name,
    cropType: collectedData.cropType,
    variety: collectedData.variety,
    harvestQuantity: collectedData.harvestQuantity,
    harvestDate: collectedData.harvestDate,
    grading: collectedData.grading || 'Standard',
    certification: collectedData.certification || 'Standard',
    pricePerKg: collectedData.pricePerKg
  };

  const { pdfBlob, groupId, ipfsHash } = await singleStepGroupManager.uploadHarvestCertificate(harvestData);

  // Step 3: Register on blockchain
  const batchInput = {
    crop: collectedData.cropType,
    variety: collectedData.variety,
    harvestQuantity: collectedData.harvestQuantity.toString(),
    sowingDate: collectedData.sowingDate,
    harvestDate: collectedData.harvestDate,
    freshnessDuration: (collectedData.freshnessDuration || 7).toString(),
    grading: collectedData.grading || 'Standard',
    certification: collectedData.certification || 'Standard',
    labTest: collectedData.labTest || '',
    price: Math.floor(collectedData.harvestQuantity * collectedData.pricePerKg * 100),
    ipfsHash: groupId,
    languageDetected: 'en',
    summary: `Agricultural produce batch: ${collectedData.cropType} - ${collectedData.variety}`,
    callStatus: 'completed',
    offTopicCount: 0
  };

  const receipt = await registerBatch(batchInput);
  const batchId = extractBatchIdFromReceipt(receipt);

  // Step 4: Save to database
  const batchData = {
    farmer_id: farmerProfile.id,
    crop_type: collectedData.cropType,
    variety: collectedData.variety,
    harvest_quantity: collectedData.harvestQuantity,
    sowing_date: collectedData.sowingDate,
    harvest_date: collectedData.harvestDate,
    price_per_kg: collectedData.pricePerKg,
    total_price: collectedData.harvestQuantity * collectedData.pricePerKg,
    grading: collectedData.grading || 'Standard',
    freshness_duration: collectedData.freshnessDuration || 7,
    certification: collectedData.certification || 'Standard',
    status: 'available',
    current_owner: farmerProfile.id,
    group_id: groupId
  };

  const { data: batch, error } = await supabase
    .from('batches')
    .insert(batchData)
    .select()
    .single();

  if (error) {
    throw new Error(`Database error: ${error.message}`);
  }

  // Step 5: Add to marketplace
  const marketplaceData = {
    batch_id: batch.id,
    current_seller_id: farmerProfile.id,
    current_seller_type: 'farmer',
    price: collectedData.harvestQuantity * collectedData.pricePerKg,
    quantity: collectedData.harvestQuantity,
    status: 'available'
  };

  await supabase.from('marketplace').insert(marketplaceData);

  return {
    batchId: batch.id,
    blockchainHash: receipt.transactionHash,
    ipfsHash: groupId
  };
}

async function getOrCreateFarmerProfile(phone: string, name: string) {
  // Check if profile exists
  const { data: existing } = await supabase
    .from('profiles')
    .select('*')
    .eq('phone', phone)
    .single();

  if (existing) {
    return existing;
  }

  // Create new profile (you'll need to create auth user first)
  // This is simplified - you may need to handle auth user creation differently
  const { data: newProfile } = await supabase
    .from('profiles')
    .insert({
      phone: phone,
      full_name: name,
      user_type: 'farmer',
      role: 'farmer'
    })
    .select()
    .single();

  return newProfile;
}

function extractBatchIdFromReceipt(receipt: any): string {
  // Extract batch ID from blockchain receipt
  // Implementation depends on your contract
  return receipt.logs[0].topics[1];
}
```

---

### Step 3: Create Helper Desk Dashboard (Days 4-5)

Create file: `src/pages/HelperDesk.tsx`

```typescript
import { useState, useEffect } from 'react';
import { supabase } from '@/integrations/supabase/client';
import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Badge } from '@/components/ui/badge';
import { useToast } from '@/components/ui/use-toast';

export const HelperDesk = () => {
  const [submissions, setSubmissions] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const { toast } = useToast();

  useEffect(() => {
    fetchSubmissions();
  }, []);

  const fetchSubmissions = async () => {
    const { data } = await supabase
      .from('omnidim_submissions')
      .select('*')
      .eq('status', 'pending_review')
      .order('created_at', { ascending: false });

    setSubmissions(data || []);
    setLoading(false);
  };

  const handleApprove = async (submissionId: string) => {
    const response = await fetch(`/api/helper-desk/submissions/${submissionId}?action=approve`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ notes: 'Approved by helper' })
    });

    if (response.ok) {
      toast({ title: 'Batch registered successfully!' });
      fetchSubmissions();
    }
  };

  const handleReject = async (submissionId: string, reason: string) => {
    const response = await fetch(`/api/helper-desk/submissions/${submissionId}?action=reject`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ reason, notes: 'Rejected by helper' })
    });

    if (response.ok) {
      toast({ title: 'Submission rejected' });
      fetchSubmissions();
    }
  };

  return (
    <div className="container mx-auto py-8">
      <h1 className="text-3xl font-bold mb-6">Helper Desk - OmniDim Submissions</h1>
      
      {submissions.map(submission => (
        <Card key={submission.id} className="mb-4">
          <CardHeader>
            <div className="flex justify-between">
              <CardTitle>{submission.farmer_name}</CardTitle>
              <Badge>{submission.status}</Badge>
            </div>
          </CardHeader>
          <CardContent>
            <div className="grid grid-cols-2 gap-4">
              <div>
                <p><strong>Crop:</strong> {submission.submission_data.cropType}</p>
                <p><strong>Variety:</strong> {submission.submission_data.variety}</p>
                <p><strong>Quantity:</strong> {submission.submission_data.harvestQuantity} kg</p>
                <p><strong>Price:</strong> ₹{submission.submission_data.pricePerKg}/kg</p>
              </div>
              <div>
                <p><strong>Phone:</strong> {submission.farmer_phone}</p>
                <p><strong>Location:</strong> {submission.farmer_location || 'Not provided'}</p>
                <p><strong>Confidence:</strong> {(submission.confidence_score * 100).toFixed(0)}%</p>
              </div>
            </div>
            
            <div className="mt-4 flex gap-2">
              <Button onClick={() => handleApprove(submission.id)}>Approve</Button>
              <Button variant="destructive" onClick={() => handleReject(submission.id, 'Data incomplete')}>
                Reject
              </Button>
            </div>
          </CardContent>
        </Card>
      ))}
    </div>
  );
};
```

---

### Step 4: Configure OmniDim (Day 6)

1. **Set Up Agent in OmniDim Dashboard**
   - Create new agent: "AgriTrace Batch Registration"
   - Copy prompt from `OMNIDIM_PROMPT.md`
   - Configure language: Hindi (primary), English (fallback)
   - Set up webhook URL: `https://yourdomain.com/api/omnidim/call-complete`

2. **Test Configuration**
   - Make test call to your phone
   - Verify JSON is sent to webhook
   - Check database for submission

3. **Production Setup**
   - Configure production phone number
   - Set up call scheduling (if needed)
   - Configure call recording
   - Set up monitoring alerts

---

### Step 5: Testing (Days 7-10)

1. **Internal Testing**
   - Test with team members
   - Verify all fields collected
   - Test approval/rejection flow
   - Test batch registration

2. **Pilot Testing**
   - Select 5-10 farmers for pilot
   - Make test calls
   - Collect feedback
   - Refine prompt based on feedback

3. **Production Testing**
   - Test with real farmers
   - Monitor call quality
   - Track success rates
   - Optimize conversation flow

---

## Environment Variables Needed

```env
OMNIDIM_API_KEY=your_api_key
OMNIDIM_WEBHOOK_SECRET=your_webhook_secret
HELPER_DESK_WEBHOOK_URL=https://yourdomain.com/api/helper-desk/notify
SMS_API_KEY=your_sms_provider_key
```

---

## Monitoring & Alerts

Set up monitoring for:
- Call success rate
- Submission quality scores
- Approval/rejection rates
- Registration success rate
- API errors
- Database errors

---

## Support & Maintenance

1. **Regular Review**
   - Review submissions weekly
   - Identify common issues
   - Update prompt as needed

2. **Farmer Support**
   - Provide helpline for farmers
   - Handle complaints
   - Schedule callbacks if needed

3. **System Maintenance**
   - Monitor API health
   - Update dependencies
   - Backup database regularly


# OmniDim Integration Setup Guide

## Quick Setup Instructions

### 1. Environment Variables

Add to your `.env` file:

```env
VITE_OMNIDIM_API_KEY=your_omnidim_api_key_here
```

### 2. Database Setup

Run this SQL in Supabase SQL Editor to create the `omnidim_submissions` table:

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

-- Create indexes
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

-- Policy: Authenticated users can insert (for webhook)
CREATE POLICY "Authenticated users can insert" ON omnidim_submissions
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');
```

### 3. Add Phone Column to Profiles Table

If not already present:

```sql
-- Add phone column if it doesn't exist
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS phone TEXT;
CREATE INDEX IF NOT EXISTS idx_profiles_phone ON profiles(phone);
```

### 4. Access Helper Desk

1. Navigate to `/helper-desk` in your application
2. Make sure you're logged in with a user that has `role = 'helper'` or `role = 'admin'`
3. Connect your wallet (MetaMask) - required for blockchain registration
4. Click "Refresh" to fetch calls from OmniDim API
5. Review calls and click "Approve & Register" to register batches

### 5. API Endpoint

The Helper Desk fetches calls from:
```
GET https://voiceagent-6h5b.onrender.com/api/calls
Authorization: Bearer {VITE_OMNIDIM_API_KEY}
```

### 6. How It Works

1. **OmniDim makes outbound call** → Farmer answers
2. **AI agent collects data** → Generates JSON
3. **JSON sent to OmniDim API** → Stored in their database
4. **Helper Desk fetches calls** → Displays pending calls
5. **Helper reviews** → Validates data
6. **Helper approves** → Batch registered on:
   - Blockchain (via smart contract)
   - Pinata (certificate uploaded)
   - Supabase (database record)
   - Marketplace (available for purchase)

### 7. Required Fields

The system validates these required fields:
- `cropType` (Rice, Wheat, Maize, Turmeric, Black Gram, Green Chili, Coconut)
- `variety` (e.g., Basmati)
- `harvestQuantity` (number in kg)
- `sowingDate` (YYYY-MM-DD)
- `harvestDate` (YYYY-MM-DD)
- `pricePerKg` (number in ₹)

### 8. Troubleshooting

**Issue: "Wallet Not Connected"**
- Make sure MetaMask is installed and connected
- Check that you're on Sepolia Testnet

**Issue: "Failed to fetch calls"**
- Check `VITE_OMNIDIM_API_KEY` is set correctly
- Verify API endpoint is accessible
- Check browser console for errors

**Issue: "Signer required for blockchain registration"**
- Connect wallet in Helper Desk
- Make sure MetaMask is unlocked

**Issue: "Profile not found"**
- System will auto-create profile from phone number
- Check Supabase logs for errors

### 9. Testing

1. Make a test call via OmniDim
2. Verify call appears in Helper Desk
3. Review call details
4. Approve and verify batch registration
5. Check blockchain transaction on Etherscan
6. Verify certificate on Pinata
7. Check batch appears in marketplace

### 10. Support

For issues:
- Check browser console for errors
- Check Supabase logs
- Verify API key is correct
- Ensure wallet is connected and on correct network


-- Create voicegenie_calls table to cache extracted data
CREATE TABLE IF NOT EXISTS voicegenie_calls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  call_id TEXT UNIQUE NOT NULL,
  phone_number TEXT NOT NULL,
  farmer_name TEXT,
  farmer_location TEXT,
  language TEXT DEFAULT 'hi',
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'registered')),
  
  -- Raw call data from VoiceGenie API
  raw_call_data JSONB,
  transcript JSONB,
  call_summary TEXT,
  call_duration INTEGER,
  call_recording_url TEXT,
  received_at TIMESTAMP WITH TIME ZONE,
  
  -- Extracted data (from Gemini or manual extraction)
  collected_data JSONB,
  confidence_score NUMERIC(3,2),
  validation_errors TEXT[],
  uncertain_fields TEXT[],
  notes TEXT,
  
  -- Helper desk info
  helper_id UUID REFERENCES profiles(id),
  helper_notes TEXT,
  rejection_reason TEXT,
  
  -- Registration info
  batch_id UUID REFERENCES batches(id),
  registered_at TIMESTAMP WITH TIME ZONE,
  
  -- Timestamps
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Gemini extraction info
  gemini_extracted BOOLEAN DEFAULT FALSE,
  gemini_extracted_at TIMESTAMP WITH TIME ZONE
);

-- Create indexes for faster queries
CREATE INDEX IF NOT EXISTS idx_voicegenie_calls_call_id ON voicegenie_calls(call_id);
CREATE INDEX IF NOT EXISTS idx_voicegenie_calls_status ON voicegenie_calls(status);
CREATE INDEX IF NOT EXISTS idx_voicegenie_calls_created_at ON voicegenie_calls(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_voicegenie_calls_gemini_extracted ON voicegenie_calls(gemini_extracted);

-- Enable RLS
ALTER TABLE voicegenie_calls ENABLE ROW LEVEL SECURITY;

-- Policy: Helpers can view all calls
DROP POLICY IF EXISTS "Helpers can view all calls" ON voicegenie_calls;
CREATE POLICY "Helpers can view all calls" ON voicegenie_calls
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.user_id = auth.uid() 
      AND profiles.role IN ('helper', 'admin')
    )
  );

-- Policy: Helpers can update calls
DROP POLICY IF EXISTS "Helpers can update calls" ON voicegenie_calls;
CREATE POLICY "Helpers can update calls" ON voicegenie_calls
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM profiles 
      WHERE profiles.user_id = auth.uid() 
      AND profiles.role IN ('helper', 'admin')
    )
  );

-- Policy: System can insert calls (for API webhooks or manual processing)
DROP POLICY IF EXISTS "System can insert calls" ON voicegenie_calls;
CREATE POLICY "System can insert calls" ON voicegenie_calls
  FOR INSERT WITH CHECK (true);

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_voicegenie_calls_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update updated_at
DROP TRIGGER IF EXISTS update_voicegenie_calls_updated_at ON voicegenie_calls;
CREATE TRIGGER update_voicegenie_calls_updated_at
  BEFORE UPDATE ON voicegenie_calls
  FOR EACH ROW
  EXECUTE FUNCTION update_voicegenie_calls_updated_at();


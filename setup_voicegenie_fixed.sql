-- ============================================
-- Complete VoiceGenie Setup - Fixed Version
-- Run this ENTIRE script in Supabase SQL Editor
-- ============================================

-- STEP 1: Fix Profiles RLS Recursion (MUST RUN FIRST)
-- ============================================
-- Drop ALL existing policies that might cause recursion
DROP POLICY IF EXISTS "Helpers can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Authenticated users can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "System can insert VoiceGenie profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;

-- Create simple, non-recursive SELECT policy
CREATE POLICY "Authenticated users can view all profiles" ON public.profiles
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- Create INSERT policy
CREATE POLICY "Users can insert profiles" ON public.profiles
  FOR INSERT WITH CHECK (
    user_id = auth.uid() OR user_id IS NULL
  );

-- Create UPDATE policy (already dropped above)
CREATE POLICY "Users can update profiles" ON public.profiles
  FOR UPDATE USING (
    user_id = auth.uid() OR user_id IS NULL
  );

-- STEP 2: Create VoiceGenie Calls Table
-- ============================================
CREATE TABLE IF NOT EXISTS voicegenie_calls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  call_id TEXT UNIQUE NOT NULL,
  phone_number TEXT NOT NULL,
  farmer_name TEXT,
  farmer_location TEXT,
  language TEXT DEFAULT 'hi',
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'registered')),
  
  -- Raw call data from VoiceGenie API (stored as JSONB for efficient querying)
  raw_call_data JSONB,
  transcript JSONB,
  call_summary TEXT,
  call_duration INTEGER,
  call_recording_url TEXT,
  received_at TIMESTAMP WITH TIME ZONE,
  
  -- Extracted structured data (from JSON + Gemini)
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
  
  -- Gemini extraction metadata
  gemini_extracted BOOLEAN DEFAULT FALSE,
  gemini_extracted_at TIMESTAMP WITH TIME ZONE
);

-- STEP 3: Create Indexes
-- ============================================
CREATE INDEX IF NOT EXISTS idx_voicegenie_calls_call_id ON voicegenie_calls(call_id);
CREATE INDEX IF NOT EXISTS idx_voicegenie_calls_status ON voicegenie_calls(status);
CREATE INDEX IF NOT EXISTS idx_voicegenie_calls_created_at ON voicegenie_calls(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_voicegenie_calls_gemini_extracted ON voicegenie_calls(gemini_extracted);
CREATE INDEX IF NOT EXISTS idx_voicegenie_calls_phone ON voicegenie_calls(phone_number);

-- STEP 4: Enable RLS
-- ============================================
ALTER TABLE voicegenie_calls ENABLE ROW LEVEL SECURITY;

-- STEP 5: Drop Existing Policies (if any)
-- ============================================
DROP POLICY IF EXISTS "Helpers can view all calls" ON voicegenie_calls;
DROP POLICY IF EXISTS "Authenticated users can view calls" ON voicegenie_calls;
DROP POLICY IF EXISTS "Helpers can update calls" ON voicegenie_calls;
DROP POLICY IF EXISTS "Authenticated users can update calls" ON voicegenie_calls;
DROP POLICY IF EXISTS "System can insert calls" ON voicegenie_calls;
DROP POLICY IF EXISTS "Authenticated users can insert calls" ON voicegenie_calls;

-- STEP 6: Create RLS Policies (Simple, No Recursion)
-- ============================================
-- View: All authenticated users can view calls
CREATE POLICY "Authenticated users can view calls" ON voicegenie_calls
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- Update: All authenticated users can update calls
CREATE POLICY "Authenticated users can update calls" ON voicegenie_calls
  FOR UPDATE USING (auth.uid() IS NOT NULL);

-- Insert: All authenticated users can insert calls
CREATE POLICY "Authenticated users can insert calls" ON voicegenie_calls
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- STEP 7: Create Trigger Function
-- ============================================
CREATE OR REPLACE FUNCTION update_voicegenie_calls_updated_at()
RETURNS TRIGGER 
LANGUAGE plpgsql
AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$;

-- STEP 8: Create Trigger
-- ============================================
DROP TRIGGER IF EXISTS update_voicegenie_calls_updated_at ON voicegenie_calls;

CREATE TRIGGER update_voicegenie_calls_updated_at
  BEFORE UPDATE ON voicegenie_calls
  FOR EACH ROW
  EXECUTE FUNCTION update_voicegenie_calls_updated_at();

-- STEP 9: Grant Permissions
-- ============================================
GRANT SELECT, INSERT, UPDATE ON voicegenie_calls TO authenticated;
GRANT SELECT ON voicegenie_calls TO anon;

-- STEP 10: Verify Setup
-- ============================================
SELECT 
  '✅ Setup Complete!' as status,
  (SELECT COUNT(*) FROM voicegenie_calls) as existing_calls,
  (SELECT COUNT(*) FROM pg_policies WHERE tablename = 'voicegenie_calls') as policies_created;


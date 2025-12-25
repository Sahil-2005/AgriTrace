-- Complete setup for VoiceGenie integration
-- Run this script in Supabase SQL Editor
-- This script fixes RLS recursion and creates voicegenie_calls table

-- ============================================
-- PART 1: Fix Profiles RLS Recursion Issue
-- ============================================

-- Drop problematic policies that cause recursion
DROP POLICY IF EXISTS "Helpers can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Authenticated users can view all profiles" ON public.profiles;

-- Create simple, non-recursive policies
CREATE POLICY "Users can view profiles" ON public.profiles
  FOR SELECT USING (
    user_id = auth.uid() OR  -- Own profile
    user_id IS NULL          -- VoiceGenie profiles (no auth user)
  );

-- Allow authenticated users to view all profiles (for helper desk)
CREATE POLICY "Authenticated users can view all profiles" ON public.profiles
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- Update insert policy
DROP POLICY IF EXISTS "System can insert VoiceGenie profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;

CREATE POLICY "Users can insert profiles" ON public.profiles
  FOR INSERT WITH CHECK (
    user_id = auth.uid() OR  -- Own profile
    user_id IS NULL          -- VoiceGenie profiles
  );

-- ============================================
-- PART 2: Create VoiceGenie Calls Table
-- ============================================

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

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Helpers can view all calls" ON voicegenie_calls;
DROP POLICY IF EXISTS "Authenticated users can view calls" ON voicegenie_calls;
DROP POLICY IF EXISTS "Helpers can update calls" ON voicegenie_calls;
DROP POLICY IF EXISTS "System can insert calls" ON voicegenie_calls;

-- Policy: Authenticated users can view all calls
CREATE POLICY "Authenticated users can view calls" ON voicegenie_calls
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- Policy: Authenticated users can update calls
CREATE POLICY "Authenticated users can update calls" ON voicegenie_calls
  FOR UPDATE USING (auth.uid() IS NOT NULL);

-- Policy: Authenticated users can insert calls
CREATE POLICY "Authenticated users can insert calls" ON voicegenie_calls
  FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);

-- ============================================
-- PART 3: Create Trigger Function
-- ============================================

-- Function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_voicegenie_calls_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop trigger if exists
DROP TRIGGER IF EXISTS update_voicegenie_calls_updated_at ON voicegenie_calls;

-- Create trigger to auto-update updated_at
CREATE TRIGGER update_voicegenie_calls_updated_at
  BEFORE UPDATE ON voicegenie_calls
  FOR EACH ROW
  EXECUTE FUNCTION update_voicegenie_calls_updated_at();

-- ============================================
-- PART 4: Grant Permissions
-- ============================================

-- Grant permissions on voicegenie_calls table
GRANT SELECT, INSERT, UPDATE ON voicegenie_calls TO authenticated;
GRANT SELECT ON voicegenie_calls TO anon;

-- ============================================
-- Success Message
-- ============================================

SELECT '✅ VoiceGenie setup completed successfully!' as status;


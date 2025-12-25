-- Fix profiles table to allow VoiceGenie farmers without auth users
-- This allows creating profiles for farmers who registered via phone calls

-- Step 1: Make user_id nullable (if not already)
ALTER TABLE public.profiles 
  ALTER COLUMN user_id DROP NOT NULL;

-- Step 2: Add unique constraint on phone for VoiceGenie profiles
-- This ensures we can find profiles by phone number
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_phone_unique 
  ON public.profiles(phone) 
  WHERE phone IS NOT NULL;

-- Step 3: Update RLS policies to allow VoiceGenie profiles
-- Allow helpers to view all profiles (including VoiceGenie ones)
DROP POLICY IF EXISTS "Helpers can view all profiles" ON public.profiles;
CREATE POLICY "Helpers can view all profiles" ON public.profiles
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM profiles p
      WHERE p.user_id = auth.uid()
      AND p.role IN ('helper', 'admin')
    )
    OR user_id IS NULL -- Allow viewing VoiceGenie profiles
  );

-- Step 4: Allow inserting profiles without user_id (for VoiceGenie)
DROP POLICY IF EXISTS "System can insert VoiceGenie profiles" ON public.profiles;
CREATE POLICY "System can insert VoiceGenie profiles" ON public.profiles
  FOR INSERT WITH CHECK (
    user_id IS NULL OR -- VoiceGenie profiles
    user_id = auth.uid() -- Regular profiles
  );

-- Step 5: Add comment to explain VoiceGenie profiles
COMMENT ON COLUMN public.profiles.user_id IS 
  'References auth.users(id). NULL for VoiceGenie farmers who registered via phone call.';


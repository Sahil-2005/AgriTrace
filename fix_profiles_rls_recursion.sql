-- Fix infinite recursion in profiles RLS policy
-- The policy was querying profiles table while checking profiles access, causing recursion
-- Run this FIRST before creating voicegenie_calls table

-- Step 1: Drop ALL existing policies that might cause recursion
DROP POLICY IF EXISTS "Helpers can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Authenticated users can view all profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.profiles;
DROP POLICY IF EXISTS "System can insert VoiceGenie profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update profiles" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;

-- Step 2: Create simple, non-recursive SELECT policy
-- Allow all authenticated users to view all profiles (no recursion)
CREATE POLICY "Authenticated users can view all profiles" ON public.profiles
  FOR SELECT USING (auth.uid() IS NOT NULL);

-- Step 3: Create INSERT policy
CREATE POLICY "Users can insert profiles" ON public.profiles
  FOR INSERT WITH CHECK (
    user_id = auth.uid() OR  -- Own profile
    user_id IS NULL          -- VoiceGenie profiles (no auth user)
  );

-- Step 4: Create UPDATE policy
CREATE POLICY "Users can update profiles" ON public.profiles
  FOR UPDATE USING (
    user_id = auth.uid() OR  -- Own profile
    user_id IS NULL          -- VoiceGenie profiles
  );

-- Success message
SELECT '✅ Profiles RLS policies fixed - no more recursion!' as status;


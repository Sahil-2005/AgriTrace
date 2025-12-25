-- Create profiles for existing users who don't have one
-- Run this in your Supabase SQL Editor to fix missing profiles
-- NOTE: If you get column errors, run fix_profiles_table_and_create_missing.sql instead

-- Step 1: Ensure columns exist (add if missing)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS user_type TEXT DEFAULT 'farmer';
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS farm_location TEXT;

-- Step 2: Create profiles for all users who don't have one
INSERT INTO public.profiles (user_id, full_name, email, user_type, farm_location)
SELECT 
  u.id as user_id,
  COALESCE(
    u.raw_user_meta_data->>'full_name',
    u.email,
    'User'
  ) as full_name,
  u.email,
  COALESCE(
    u.raw_user_meta_data->>'user_type',
    'farmer'
  ) as user_type,
  u.raw_user_meta_data->>'farm_location' as farm_location
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.user_id
WHERE p.user_id IS NULL
ON CONFLICT (user_id) DO NOTHING;

-- Step 2: Verify profiles were created
SELECT 
  'Profiles created successfully!' as message,
  COUNT(*) as total_profiles
FROM public.profiles;

-- Step 3: Show users without profiles (should be 0)
SELECT 
  'Users without profiles:' as check,
  COUNT(*) as count
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.user_id
WHERE p.user_id IS NULL;

-- Step 4: Verify the trigger exists
SELECT 
  'Trigger check:' as check,
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM pg_trigger 
      WHERE tgname = 'on_auth_user_created'
    ) THEN '✅ Trigger exists'
    ELSE '❌ Trigger missing - run fix_signup_500_error.sql'
  END as status;


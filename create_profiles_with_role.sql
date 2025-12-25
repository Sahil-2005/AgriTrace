-- Create profiles for existing users (includes role column)
-- Run this in your Supabase SQL Editor

-- Step 1: Set default for role column to avoid NOT NULL constraint errors
ALTER TABLE public.profiles ALTER COLUMN role SET DEFAULT 'farmer';

-- Step 2: Create profiles for all users who don't have one
INSERT INTO public.profiles (
  user_id, 
  full_name, 
  email, 
  user_type, 
  farm_location,
  role
)
SELECT 
  u.id as user_id,
  COALESCE(
    u.raw_user_meta_data->>'full_name',
    SPLIT_PART(u.email, '@', 1),
    'User'
  ) as full_name,
  u.email,
  COALESCE(
    u.raw_user_meta_data->>'user_type',
    'farmer'
  ) as user_type,
  u.raw_user_meta_data->>'farm_location' as farm_location,
  COALESCE(
    u.raw_user_meta_data->>'user_type',
    u.raw_user_meta_data->>'role',
    'farmer'
  ) as role
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.user_id
WHERE p.user_id IS NULL
ON CONFLICT (user_id) DO UPDATE
SET
  full_name = COALESCE(EXCLUDED.full_name, profiles.full_name),
  email = COALESCE(EXCLUDED.email, profiles.email),
  user_type = COALESCE(EXCLUDED.user_type, profiles.user_type),
  farm_location = COALESCE(EXCLUDED.farm_location, profiles.farm_location),
  role = COALESCE(EXCLUDED.role, profiles.role),
  updated_at = NOW();

-- Step 3: Verify profiles were created
SELECT 
  'Profiles created successfully!' as message,
  COUNT(*) as total_profiles
FROM public.profiles;

-- Step 4: Show users without profiles (should be 0)
SELECT 
  'Users without profiles:' as check,
  COUNT(*) as count
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.user_id
WHERE p.user_id IS NULL;


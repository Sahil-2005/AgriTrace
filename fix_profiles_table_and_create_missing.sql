-- Fix profiles table structure and create missing profiles
-- Run this in your Supabase SQL Editor

-- Step 1: Check and add missing columns to profiles table
DO $$
BEGIN
  -- Add user_type column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'profiles' 
    AND column_name = 'user_type'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN user_type TEXT DEFAULT 'farmer';
    ALTER TABLE public.profiles ADD CONSTRAINT profiles_user_type_check 
      CHECK (user_type IN ('farmer', 'distributor', 'retailer', 'helper', 'admin'));
  END IF;

  -- Add email column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'profiles' 
    AND column_name = 'email'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN email TEXT;
  END IF;

  -- Add full_name column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'profiles' 
    AND column_name = 'full_name'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN full_name TEXT;
  END IF;

  -- Add farm_location column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'profiles' 
    AND column_name = 'farm_location'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN farm_location TEXT;
  END IF;

  -- Add wallet_address column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'profiles' 
    AND column_name = 'wallet_address'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN wallet_address TEXT;
  END IF;

  -- Add created_at column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'profiles' 
    AND column_name = 'created_at'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
  END IF;

  -- Add updated_at column if it doesn't exist
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'profiles' 
    AND column_name = 'updated_at'
  ) THEN
    ALTER TABLE public.profiles ADD COLUMN updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();
  END IF;
END $$;

-- Step 2: Ensure profiles table has the correct structure
-- Create table if it doesn't exist
CREATE TABLE IF NOT EXISTS public.profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
  full_name TEXT,
  email TEXT,
  user_type TEXT DEFAULT 'farmer' CHECK (user_type IN ('farmer', 'distributor', 'retailer', 'helper', 'admin')),
  farm_location TEXT,
  wallet_address TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 3: Set default for role column if it exists and is NOT NULL
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'profiles' 
    AND column_name = 'role'
    AND is_nullable = 'NO'
  ) THEN
    -- Set default value for role column if it doesn't have one
    BEGIN
      ALTER TABLE public.profiles ALTER COLUMN role SET DEFAULT 'farmer';
    EXCEPTION
      WHEN OTHERS THEN
        NULL; -- Ignore if can't set default
    END;
  END IF;
END $$;

-- Step 4: Create profiles for all users who don't have one
-- This handles the role column if it exists
DO $$
DECLARE
  role_exists BOOLEAN;
BEGIN
  -- Check if role column exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'profiles' 
    AND column_name = 'role'
  ) INTO role_exists;

  IF role_exists THEN
    -- Insert with role column
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
  ELSE
    -- Insert without role column
    INSERT INTO public.profiles (
      user_id, 
      full_name, 
      email, 
      user_type, 
      farm_location
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
      u.raw_user_meta_data->>'farm_location' as farm_location
    FROM auth.users u
    LEFT JOIN public.profiles p ON u.id = p.user_id
    WHERE p.user_id IS NULL
    ON CONFLICT (user_id) DO UPDATE
    SET
      full_name = COALESCE(EXCLUDED.full_name, profiles.full_name),
      email = COALESCE(EXCLUDED.email, profiles.email),
      user_type = COALESCE(EXCLUDED.user_type, profiles.user_type),
      farm_location = COALESCE(EXCLUDED.farm_location, profiles.farm_location),
      updated_at = NOW();
  END IF;
END $$;

-- Step 5: Verify profiles were created
SELECT 
  'Profiles created successfully!' as message,
  COUNT(*) as total_profiles
FROM public.profiles;

-- Step 6: Show users without profiles (should be 0)
SELECT 
  'Users without profiles:' as check,
  COUNT(*) as count
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.user_id
WHERE p.user_id IS NULL;

-- Step 7: Show current profiles table structure
SELECT 
  'Current profiles table structure:' as info,
  column_name, 
  data_type, 
  is_nullable, 
  column_default
FROM information_schema.columns 
WHERE table_schema = 'public' 
AND table_name = 'profiles' 
ORDER BY ordinal_position;


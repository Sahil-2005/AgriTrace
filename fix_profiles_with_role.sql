-- Fix profiles table and create missing profiles (handles role column)
-- Run this in your Supabase SQL Editor

-- Step 1: Check if role column exists and what its constraints are
DO $$
DECLARE
  role_column_exists BOOLEAN;
  role_is_nullable BOOLEAN;
BEGIN
  -- Check if role column exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'profiles' 
    AND column_name = 'role'
  ) INTO role_column_exists;

  -- If role column exists, check if it's nullable
  IF role_column_exists THEN
    SELECT is_nullable = 'YES' INTO role_is_nullable
    FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'profiles' 
    AND column_name = 'role';
    
    -- If role is NOT NULL and has no default, set a default
    IF NOT role_is_nullable THEN
      -- Try to set a default if it doesn't have one
      BEGIN
        ALTER TABLE public.profiles ALTER COLUMN role SET DEFAULT 'farmer';
      EXCEPTION
        WHEN OTHERS THEN
          NULL; -- Ignore if default already exists or can't be set
      END;
    END IF;
  END IF;
END $$;

-- Step 2: Ensure all required columns exist
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
END $$;

-- Step 3: Create profiles for all users who don't have one
-- This version handles the role column dynamically
DO $$
DECLARE
  role_column_exists BOOLEAN;
  sql_text TEXT;
BEGIN
  -- Check if role column exists
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' 
    AND table_name = 'profiles' 
    AND column_name = 'role'
  ) INTO role_column_exists;

  -- Build INSERT statement based on whether role column exists
  IF role_column_exists THEN
    sql_text := '
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
          u.raw_user_meta_data->>''full_name'',
          SPLIT_PART(u.email, ''@'', 1),
          ''User''
        ) as full_name,
        u.email,
        COALESCE(
          u.raw_user_meta_data->>''user_type'',
          ''farmer''
        ) as user_type,
        u.raw_user_meta_data->>''farm_location'' as farm_location,
        COALESCE(
          u.raw_user_meta_data->>''user_type'',
          u.raw_user_meta_data->>''role'',
          ''farmer''
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
    ';
  ELSE
    sql_text := '
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
          u.raw_user_meta_data->>''full_name'',
          SPLIT_PART(u.email, ''@'', 1),
          ''User''
        ) as full_name,
        u.email,
        COALESCE(
          u.raw_user_meta_data->>''user_type'',
          ''farmer''
        ) as user_type,
        u.raw_user_meta_data->>''farm_location'' as farm_location
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
    ';
  END IF;

  -- Execute the dynamic SQL
  EXECUTE sql_text;
END $$;

-- Step 4: Verify profiles were created
SELECT 
  'Profiles created successfully!' as message,
  COUNT(*) as total_profiles
FROM public.profiles;

-- Step 5: Show users without profiles (should be 0)
SELECT 
  'Users without profiles:' as check,
  COUNT(*) as count
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.user_id
WHERE p.user_id IS NULL;

-- Step 6: Show current profiles table structure
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


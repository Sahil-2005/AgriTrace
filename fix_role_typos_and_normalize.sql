-- Fix role typos and normalize user_type/role values
-- This script fixes typos and ensures role matches user_type correctly

-- Step 1: Fix typos in user_type column
UPDATE public.profiles
SET user_type = CASE
  WHEN LOWER(user_type) = 'distirbutor' THEN 'distributor'
  WHEN LOWER(user_type) = 'distributer' THEN 'distributor'
  WHEN LOWER(user_type) = 'retailer' THEN 'retailer'
  WHEN LOWER(user_type) = 'helper' THEN 'helper'
  WHEN LOWER(user_type) = 'admin' THEN 'admin'
  WHEN LOWER(user_type) = 'farmer' THEN 'farmer'
  WHEN user_type IS NULL THEN 'farmer'
  ELSE LOWER(user_type)
END
WHERE user_type IS NOT NULL;

-- Step 2: Fix typos in role column and ensure it matches user_type
UPDATE public.profiles
SET role = CASE
  -- Fix typos
  WHEN LOWER(role) = 'distirbutor' THEN 'distributor'
  WHEN LOWER(role) = 'distributer' THEN 'distributor'
  -- Normalize to match user_type if role doesn't match
  WHEN role IS NULL OR role = '' THEN COALESCE(user_type, 'farmer')
  WHEN LOWER(role) NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') THEN COALESCE(user_type, 'farmer')
  ELSE LOWER(role)
END;

-- Step 3: Ensure role matches user_type (role should mirror user_type)
UPDATE public.profiles
SET role = CASE
  WHEN user_type IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') THEN user_type
  WHEN user_type IS NULL THEN 'farmer'
  ELSE 'farmer' -- Default fallback
END
WHERE role IS NULL 
   OR role NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin')
   OR role != user_type;

-- Step 4: Update the trigger function to normalize and validate values
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  normalized_user_type TEXT;
  normalized_role TEXT;
BEGIN
  -- Normalize user_type (fix typos and ensure valid values)
  normalized_user_type := CASE
    WHEN LOWER(COALESCE(NEW.raw_user_meta_data->>'user_type', '')) = 'distirbutor' THEN 'distributor'
    WHEN LOWER(COALESCE(NEW.raw_user_meta_data->>'user_type', '')) = 'distributer' THEN 'distributor'
    WHEN LOWER(COALESCE(NEW.raw_user_meta_data->>'user_type', '')) IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') 
      THEN LOWER(NEW.raw_user_meta_data->>'user_type')
    ELSE 'farmer' -- Default to farmer
  END;

  -- Normalize role (use role from metadata if valid, otherwise use user_type)
  normalized_role := CASE
    WHEN LOWER(COALESCE(NEW.raw_user_meta_data->>'role', '')) IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') 
      THEN LOWER(NEW.raw_user_meta_data->>'role')
    WHEN LOWER(COALESCE(NEW.raw_user_meta_data->>'role', '')) = 'distirbutor' THEN 'distributor'
    WHEN LOWER(COALESCE(NEW.raw_user_meta_data->>'role', '')) = 'distributer' THEN 'distributor'
    ELSE normalized_user_type -- Fallback to normalized user_type
  END;

  -- Insert profile with normalized values
  INSERT INTO public.profiles (
    user_id, 
    full_name, 
    email, 
    user_type, 
    farm_location,
    role
  )
  VALUES (
    NEW.id,
    NEW.raw_user_meta_data->>'full_name',
    NEW.email,
    normalized_user_type,
    NEW.raw_user_meta_data->>'farm_location',
    normalized_role
  )
  ON CONFLICT (user_id) DO UPDATE
  SET
    full_name = COALESCE(EXCLUDED.full_name, profiles.full_name),
    email = COALESCE(EXCLUDED.email, profiles.email),
    user_type = COALESCE(EXCLUDED.user_type, profiles.user_type),
    farm_location = COALESCE(EXCLUDED.farm_location, profiles.farm_location),
    role = COALESCE(EXCLUDED.role, profiles.role),
    updated_at = NOW();
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error creating profile for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 5: Verify fixes
SELECT 
  'Fixed profiles' as status,
  COUNT(*) as total_profiles,
  COUNT(CASE WHEN role NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') THEN 1 END) as invalid_roles,
  COUNT(CASE WHEN user_type NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') THEN 1 END) as invalid_user_types,
  COUNT(CASE WHEN role != user_type THEN 1 END) as mismatched_role_user_type
FROM public.profiles;

-- Step 6: Show any remaining issues
SELECT 
  id,
  email,
  user_type,
  role,
  CASE 
    WHEN role NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') THEN 'INVALID ROLE'
    WHEN user_type NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') THEN 'INVALID USER_TYPE'
    WHEN role != user_type THEN 'MISMATCH'
    ELSE 'OK'
  END as issue
FROM public.profiles
WHERE role NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin')
   OR user_type NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin')
   OR role != user_type;


-- Complete fix for role constraint violation
-- This script fixes the constraint and ensures all data is normalized

-- Step 1: Drop ALL constraints related to role and user_type
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_user_type_check;

-- Step 2: Normalize ALL existing data (fix typos, trim whitespace, lowercase)
-- Fix user_type first
UPDATE public.profiles
SET user_type = LOWER(TRIM(COALESCE(user_type, 'farmer')))
WHERE user_type IS NOT NULL;

UPDATE public.profiles
SET user_type = CASE
  WHEN user_type = 'distirbutor' THEN 'distributor'
  WHEN user_type = 'distributer' THEN 'distributor'
  WHEN user_type IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') THEN user_type
  ELSE 'farmer'
END
WHERE user_type IS NOT NULL;

-- Fix role
UPDATE public.profiles
SET role = LOWER(TRIM(COALESCE(role, user_type, 'farmer')))
WHERE role IS NOT NULL OR role IS NULL;

UPDATE public.profiles
SET role = CASE
  WHEN role = 'distirbutor' THEN 'distributor'
  WHEN role = 'distributer' THEN 'distributor'
  WHEN role IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') THEN role
  ELSE COALESCE(user_type, 'farmer')
END;

-- Step 3: Ensure role matches user_type
UPDATE public.profiles
SET role = COALESCE(user_type, 'farmer')
WHERE role IS NULL 
   OR role NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin')
   OR role != COALESCE(user_type, 'farmer');

-- Step 4: Set defaults for NULL values
UPDATE public.profiles
SET user_type = 'farmer'
WHERE user_type IS NULL;

UPDATE public.profiles
SET role = COALESCE(user_type, 'farmer')
WHERE role IS NULL;

-- Step 5: Final normalization pass - ensure everything is clean
UPDATE public.profiles
SET 
  user_type = LOWER(TRIM(user_type)),
  role = LOWER(TRIM(role))
WHERE user_type != LOWER(TRIM(user_type)) 
   OR role != LOWER(TRIM(role));

-- Step 6: Ensure role always matches user_type
UPDATE public.profiles
SET role = user_type
WHERE role != user_type;

-- Step 7: Recreate constraints (simple, exact match)
ALTER TABLE public.profiles 
ADD CONSTRAINT profiles_role_check 
CHECK (role IS NOT NULL AND role IN ('farmer', 'distributor', 'retailer', 'helper', 'admin'));

ALTER TABLE public.profiles 
ADD CONSTRAINT profiles_user_type_check 
CHECK (user_type IS NOT NULL AND user_type IN ('farmer', 'distributor', 'retailer', 'helper', 'admin'));

-- Step 8: Update trigger function to normalize BEFORE insertion
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  normalized_user_type TEXT;
  normalized_role TEXT;
BEGIN
  -- Normalize user_type (fix typos and ensure valid values)
  normalized_user_type := LOWER(TRIM(COALESCE(NEW.raw_user_meta_data->>'user_type', 'farmer')));
  
  -- Fix common typos
  IF normalized_user_type = 'distirbutor' OR normalized_user_type = 'distributer' THEN
    normalized_user_type := 'distributor';
  END IF;
  
  -- Validate and default to farmer if invalid
  IF normalized_user_type NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') THEN
    normalized_user_type := 'farmer';
  END IF;

  -- Normalize role (use role from metadata if valid, otherwise use user_type)
  normalized_role := LOWER(TRIM(COALESCE(NEW.raw_user_meta_data->>'role', normalized_user_type)));
  
  -- Fix common typos
  IF normalized_role = 'distirbutor' OR normalized_role = 'distributer' THEN
    normalized_role := 'distributor';
  END IF;
  
  -- Validate and default to user_type if invalid
  IF normalized_role NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') THEN
    normalized_role := normalized_user_type;
  END IF;

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
    user_type = CASE
      WHEN EXCLUDED.user_type IS NOT NULL THEN
        CASE
          WHEN LOWER(TRIM(EXCLUDED.user_type)) = 'distirbutor' THEN 'distributor'
          WHEN LOWER(TRIM(EXCLUDED.user_type)) = 'distributer' THEN 'distributor'
          WHEN LOWER(TRIM(EXCLUDED.user_type)) IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') 
            THEN LOWER(TRIM(EXCLUDED.user_type))
          ELSE profiles.user_type
        END
      ELSE profiles.user_type
    END,
    farm_location = COALESCE(EXCLUDED.farm_location, profiles.farm_location),
    role = CASE
      WHEN EXCLUDED.role IS NOT NULL THEN
        CASE
          WHEN LOWER(TRIM(EXCLUDED.role)) = 'distirbutor' THEN 'distributor'
          WHEN LOWER(TRIM(EXCLUDED.role)) = 'distributer' THEN 'distributor'
          WHEN LOWER(TRIM(EXCLUDED.role)) IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') 
            THEN LOWER(TRIM(EXCLUDED.role))
          ELSE profiles.user_type -- Use user_type as fallback
        END
      ELSE profiles.user_type -- Use user_type as fallback
    END,
    updated_at = NOW();
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error creating profile for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 9: Verify all data is correct
SELECT 
  'Data Verification' as check_type,
  COUNT(*) as total_profiles,
  COUNT(CASE WHEN role NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') THEN 1 END) as invalid_roles,
  COUNT(CASE WHEN user_type NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') THEN 1 END) as invalid_user_types,
  COUNT(CASE WHEN role != user_type THEN 1 END) as mismatched_role_user_type,
  COUNT(CASE WHEN role IS NULL THEN 1 END) as null_roles,
  COUNT(CASE WHEN user_type IS NULL THEN 1 END) as null_user_types
FROM public.profiles;

-- Step 10: Show any problematic rows
SELECT 
  id,
  email,
  user_type,
  role,
  CASE 
    WHEN role IS NULL THEN 'NULL ROLE'
    WHEN user_type IS NULL THEN 'NULL USER_TYPE'
    WHEN role NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') THEN 'INVALID ROLE: ' || role
    WHEN user_type NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') THEN 'INVALID USER_TYPE: ' || user_type
    WHEN role != user_type THEN 'MISMATCH: role=' || role || ', user_type=' || user_type
    ELSE 'OK'
  END as issue
FROM public.profiles
WHERE role IS NULL
   OR user_type IS NULL
   OR role NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin')
   OR user_type NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin')
   OR role != user_type;


-- Fix role constraint and normalize all data
-- This script fixes the constraint definition and all existing data

-- Step 1: Drop the existing constraint if it exists
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;

-- Step 2: Fix all existing data first (normalize and fix typos)
UPDATE public.profiles
SET user_type = CASE
  WHEN LOWER(TRIM(user_type)) = 'distirbutor' THEN 'distributor'
  WHEN LOWER(TRIM(user_type)) = 'distributer' THEN 'distributor'
  WHEN LOWER(TRIM(user_type)) IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') 
    THEN LOWER(TRIM(user_type))
  WHEN user_type IS NULL OR TRIM(user_type) = '' THEN 'farmer'
  ELSE 'farmer' -- Default fallback for any invalid values
END;

UPDATE public.profiles
SET role = CASE
  -- Fix typos
  WHEN LOWER(TRIM(role)) = 'distirbutor' THEN 'distributor'
  WHEN LOWER(TRIM(role)) = 'distributer' THEN 'distributor'
  -- Normalize to match user_type if role doesn't match
  WHEN role IS NULL OR TRIM(role) = '' THEN COALESCE(user_type, 'farmer')
  WHEN LOWER(TRIM(role)) NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') 
    THEN COALESCE(user_type, 'farmer')
  ELSE LOWER(TRIM(role))
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

-- Step 4: Ensure user_type and role are lowercase and trimmed
UPDATE public.profiles
SET 
  user_type = LOWER(TRIM(user_type)),
  role = LOWER(TRIM(role))
WHERE user_type != LOWER(TRIM(user_type)) 
   OR role != LOWER(TRIM(role));

-- Step 5: Recreate the constraint with proper definition
-- Since we've normalized all data above, we can use a simple constraint
-- But PostgreSQL CHECK constraints can't use functions reliably, so we ensure data is normalized first
ALTER TABLE public.profiles 
ADD CONSTRAINT profiles_role_check 
CHECK (role IN ('farmer', 'distributor', 'retailer', 'helper', 'admin'));

-- Step 6: Also add constraint for user_type
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_user_type_check;
ALTER TABLE public.profiles 
ADD CONSTRAINT profiles_user_type_check 
CHECK (user_type IN ('farmer', 'distributor', 'retailer', 'helper', 'admin'));

-- Step 7: Update the trigger function to normalize and validate values
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
DECLARE
  normalized_user_type TEXT;
  normalized_role TEXT;
BEGIN
  -- Normalize user_type (fix typos and ensure valid values)
  normalized_user_type := CASE
    WHEN LOWER(TRIM(COALESCE(NEW.raw_user_meta_data->>'user_type', ''))) = 'distirbutor' THEN 'distributor'
    WHEN LOWER(TRIM(COALESCE(NEW.raw_user_meta_data->>'user_type', ''))) = 'distributer' THEN 'distributor'
    WHEN LOWER(TRIM(COALESCE(NEW.raw_user_meta_data->>'user_type', ''))) IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') 
      THEN LOWER(TRIM(NEW.raw_user_meta_data->>'user_type'))
    ELSE 'farmer' -- Default to farmer
  END;

  -- Normalize role (use role from metadata if valid, otherwise use user_type)
  normalized_role := CASE
    WHEN LOWER(TRIM(COALESCE(NEW.raw_user_meta_data->>'role', ''))) IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') 
      THEN LOWER(TRIM(NEW.raw_user_meta_data->>'role'))
    WHEN LOWER(TRIM(COALESCE(NEW.raw_user_meta_data->>'role', ''))) = 'distirbutor' THEN 'distributor'
    WHEN LOWER(TRIM(COALESCE(NEW.raw_user_meta_data->>'role', ''))) = 'distributer' THEN 'distributor'
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
          ELSE profiles.role
        END
      ELSE profiles.role
    END,
    updated_at = NOW();
  
  RETURN NEW;
EXCEPTION
  WHEN OTHERS THEN
    RAISE WARNING 'Error creating profile for user %: %', NEW.id, SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Step 8: Verify all data is correct
SELECT 
  'Data Verification' as check_type,
  COUNT(*) as total_profiles,
  COUNT(CASE WHEN LOWER(TRIM(role)) NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') THEN 1 END) as invalid_roles,
  COUNT(CASE WHEN LOWER(TRIM(user_type)) NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') THEN 1 END) as invalid_user_types,
  COUNT(CASE WHEN LOWER(TRIM(role)) != LOWER(TRIM(user_type)) THEN 1 END) as mismatched_role_user_type,
  COUNT(CASE WHEN role != LOWER(TRIM(role)) THEN 1 END) as uppercase_roles,
  COUNT(CASE WHEN user_type != LOWER(TRIM(user_type)) THEN 1 END) as uppercase_user_types
FROM public.profiles;

-- Step 9: Show any remaining problematic rows
SELECT 
  id,
  email,
  user_type,
  role,
  LENGTH(user_type) as user_type_length,
  LENGTH(role) as role_length,
  CASE 
    WHEN LOWER(TRIM(role)) NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') THEN 'INVALID ROLE: ' || role
    WHEN LOWER(TRIM(user_type)) NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin') THEN 'INVALID USER_TYPE: ' || user_type
    WHEN LOWER(TRIM(role)) != LOWER(TRIM(user_type)) THEN 'MISMATCH: role=' || role || ', user_type=' || user_type
    WHEN role != LOWER(TRIM(role)) THEN 'UPPERCASE ROLE: ' || role
    WHEN user_type != LOWER(TRIM(user_type)) THEN 'UPPERCASE USER_TYPE: ' || user_type
    ELSE 'OK'
  END as issue
FROM public.profiles
WHERE LOWER(TRIM(role)) NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin')
   OR LOWER(TRIM(user_type)) NOT IN ('farmer', 'distributor', 'retailer', 'helper', 'admin')
   OR LOWER(TRIM(role)) != LOWER(TRIM(user_type))
   OR role != LOWER(TRIM(role))
   OR user_type != LOWER(TRIM(user_type));


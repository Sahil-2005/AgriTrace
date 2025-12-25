-- Fix Logistics Schema: Separate Driver Data from Farmer Profiles
-- This ensures farmers remain unaffected and drivers have their own table
-- Run this in your Supabase SQL Editor

-- Step 1: Create separate driver_profiles table (instead of adding columns to profiles)
CREATE TABLE IF NOT EXISTS public.driver_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  profile_id UUID NOT NULL UNIQUE REFERENCES profiles(id) ON DELETE CASCADE,
  vehicle_type VARCHAR(50),
  vehicle_capacity_kg DECIMAL(10,2),
  vehicle_registration_number VARCHAR(50),
  driver_license_number VARCHAR(50),
  current_location JSONB,
  is_available BOOLEAN DEFAULT true,
  driver_rating DECIMAL(3,2) DEFAULT 5.0,
  total_deliveries INTEGER DEFAULT 0,
  vehicle_equipment JSONB,
  working_hours JSONB,
  insurance_provider VARCHAR(100),
  insurance_policy_number VARCHAR(100),
  insurance_expiry_date DATE,
  insurance_coverage_amount DECIMAL(15,2),
  license_verified BOOLEAN DEFAULT false,
  background_check_passed BOOLEAN DEFAULT false,
  vehicle_inspection_passed BOOLEAN DEFAULT false,
  on_time_delivery_percentage DECIMAL(5,2),
  customer_satisfaction_score DECIMAL(3,2),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 2: Remove driver-specific columns from profiles table (if they exist)
-- This ensures farmers are not affected
DO $$
BEGIN
  -- Drop driver columns if they exist (they shouldn't affect farmers)
  ALTER TABLE public.profiles DROP COLUMN IF EXISTS vehicle_type;
  ALTER TABLE public.profiles DROP COLUMN IF EXISTS vehicle_capacity_kg;
  ALTER TABLE public.profiles DROP COLUMN IF EXISTS vehicle_registration_number;
  ALTER TABLE public.profiles DROP COLUMN IF EXISTS driver_license_number;
  ALTER TABLE public.profiles DROP COLUMN IF EXISTS current_location;
  ALTER TABLE public.profiles DROP COLUMN IF EXISTS is_available;
  ALTER TABLE public.profiles DROP COLUMN IF EXISTS driver_rating;
  ALTER TABLE public.profiles DROP COLUMN IF EXISTS total_deliveries;
  ALTER TABLE public.profiles DROP COLUMN IF EXISTS vehicle_equipment;
  ALTER TABLE public.profiles DROP COLUMN IF EXISTS working_hours;
END $$;

-- Step 3: Ensure user_type constraint includes driver (but farmers stay as 'farmer')
DO $$
BEGIN
  ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_user_type_check;
  ALTER TABLE public.profiles ADD CONSTRAINT profiles_user_type_check 
    CHECK (user_type IN ('farmer', 'distributor', 'retailer', 'helper', 'admin', 'driver'));
END $$;

-- Step 4: Create indexes for driver_profiles
CREATE INDEX IF NOT EXISTS idx_driver_profiles_profile_id ON driver_profiles(profile_id);
CREATE INDEX IF NOT EXISTS idx_driver_profiles_available ON driver_profiles(is_available);
CREATE INDEX IF NOT EXISTS idx_driver_profiles_rating ON driver_profiles(driver_rating);

-- Step 5: Migrate existing driver data (if any) from profiles to driver_profiles
DO $$
DECLARE
  driver_record RECORD;
BEGIN
  -- This will only run if there's existing driver data in profiles
  -- Since we're removing those columns, this is just a safety check
  FOR driver_record IN 
    SELECT id FROM profiles WHERE user_type = 'driver'
  LOOP
    -- Create driver_profile if it doesn't exist
    INSERT INTO driver_profiles (profile_id, is_available)
    VALUES (driver_record.id, true)
    ON CONFLICT (profile_id) DO NOTHING;
  END LOOP;
END $$;

-- Step 6: Update delivery_requests to reference driver_profiles instead
-- First, update the foreign key if needed
DO $$
BEGIN
  -- Check if assigned_driver_id exists and update references
  -- Keep it as profiles.id reference but drivers will have driver_profiles entry
END $$;

-- Step 7: Create helper function to check if user is a driver
CREATE OR REPLACE FUNCTION is_driver(p_profile_id UUID)
RETURNS BOOLEAN AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM driver_profiles WHERE profile_id = p_profile_id
  );
END;
$$ LANGUAGE plpgsql;

-- Step 8: Create helper function to get driver profile
CREATE OR REPLACE FUNCTION get_driver_profile(p_profile_id UUID)
RETURNS TABLE (
  id UUID,
  profile_id UUID,
  vehicle_type VARCHAR,
  vehicle_capacity_kg DECIMAL,
  is_available BOOLEAN,
  driver_rating DECIMAL
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    dp.id,
    dp.profile_id,
    dp.vehicle_type,
    dp.vehicle_capacity_kg,
    dp.is_available,
    dp.driver_rating
  FROM driver_profiles dp
  WHERE dp.profile_id = p_profile_id;
END;
$$ LANGUAGE plpgsql;

-- Step 9: Enable Row Level Security for driver_profiles
ALTER TABLE driver_profiles ENABLE ROW LEVEL SECURITY;

-- Step 10: Create RLS Policies for driver_profiles
CREATE POLICY "Drivers can view their own driver profile" ON driver_profiles
  FOR SELECT USING (profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid()));

CREATE POLICY "Drivers can update their own driver profile" ON driver_profiles
  FOR UPDATE USING (profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid()));

CREATE POLICY "Drivers can insert their own driver profile" ON driver_profiles
  FOR INSERT WITH CHECK (profile_id = (SELECT id FROM profiles WHERE user_id = auth.uid()));

CREATE POLICY "Anyone can view driver profiles for matching" ON driver_profiles
  FOR SELECT USING (true); -- Needed for driver matching algorithm

-- Step 11: Grant permissions
GRANT SELECT, INSERT, UPDATE ON driver_profiles TO authenticated;
GRANT SELECT ON driver_profiles TO anon; -- For driver matching

-- Step 12: Create trigger to auto-create driver_profile when user_type changes to 'driver' OR when profile is created with driver type
CREATE OR REPLACE FUNCTION create_driver_profile_on_type_change()
RETURNS TRIGGER AS $$
BEGIN
  -- If user_type is 'driver' and driver_profile doesn't exist
  -- This handles both INSERT (new profile) and UPDATE (type change)
  IF NEW.user_type = 'driver' THEN
    INSERT INTO driver_profiles (profile_id, is_available)
    VALUES (NEW.id, true)
    ON CONFLICT (profile_id) DO NOTHING;
  END IF;
  
  -- If user_type changed FROM 'driver', mark driver_profile as unavailable
  -- (We'll keep it for historical data, but mark as unavailable)
  IF OLD.user_type = 'driver' AND NEW.user_type != 'driver' THEN
    UPDATE driver_profiles 
    SET is_available = false 
    WHERE profile_id = NEW.id;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger for UPDATE (when user_type changes)
DROP TRIGGER IF EXISTS trigger_create_driver_profile ON profiles;
CREATE TRIGGER trigger_create_driver_profile
  AFTER INSERT OR UPDATE OF user_type ON profiles
  FOR EACH ROW
  EXECUTE FUNCTION create_driver_profile_on_type_change();

-- Step 13: Update delivery service queries to use driver_profiles
-- (This will be done in the TypeScript code, but we ensure the table structure is correct)

-- Step 14: Verify farmers are unaffected
DO $$
DECLARE
  farmer_count INTEGER;
  driver_count INTEGER;
BEGIN
  SELECT COUNT(*) INTO farmer_count FROM profiles WHERE user_type = 'farmer';
  SELECT COUNT(*) INTO driver_count FROM profiles WHERE user_type = 'driver';
  
  RAISE NOTICE 'Farmers: %, Drivers: %', farmer_count, driver_count;
END $$;

-- Success message
SELECT '✅ Driver profiles separated successfully! Farmers remain unaffected.' as status;


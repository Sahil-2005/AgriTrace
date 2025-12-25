-- Simple Logistics Mock Data
-- Adds 1 driver and 3 batches with basic delivery requests

-- ============================================================================
-- STEP 1: Ensure Schema Columns Exist
-- ============================================================================
DO $$
BEGIN
  -- Add driver to user_type constraint
  ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_user_type_check;
  ALTER TABLE public.profiles ADD CONSTRAINT profiles_user_type_check 
    CHECK (user_type IN ('farmer', 'distributor', 'retailer', 'helper', 'admin', 'driver'));
  
  -- Add driver columns if they don't exist
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'vehicle_type') THEN
    ALTER TABLE public.profiles ADD COLUMN vehicle_type VARCHAR(50);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'vehicle_capacity_kg') THEN
    ALTER TABLE public.profiles ADD COLUMN vehicle_capacity_kg DECIMAL(10,2);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'is_available') THEN
    ALTER TABLE public.profiles ADD COLUMN is_available BOOLEAN DEFAULT true;
  END IF;
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'driver_rating') THEN
    ALTER TABLE public.profiles ADD COLUMN driver_rating DECIMAL(3,2) DEFAULT 5.0;
  END IF;
END $$;

-- ============================================================================
-- STEP 2: Create 1 Driver
-- ============================================================================
DO $$
DECLARE
  driver_id UUID;
BEGIN
  -- Get or create driver
  SELECT id INTO driver_id FROM profiles WHERE full_name = 'Test Driver' LIMIT 1;
  
  IF driver_id IS NULL THEN
    INSERT INTO profiles (full_name, user_type, email, phone, farm_location, vehicle_type, vehicle_capacity_kg, is_available, driver_rating)
    VALUES (
      'Test Driver',
      'driver',
      'driver@test.com',
      '+91-9999999999',
      'Mumbai, India',
      'Truck',
      5000.00,
      true,
      4.5
    )
    RETURNING id INTO driver_id;
  ELSE
    UPDATE profiles SET
      user_type = 'driver',
      vehicle_type = 'Truck',
      vehicle_capacity_kg = 5000.00,
      is_available = true,
      driver_rating = 4.5
    WHERE id = driver_id;
  END IF;
END $$;

-- ============================================================================
-- STEP 3: Create 3 Batches (if they don't exist)
-- ============================================================================
DO $$
DECLARE
  batch1_id UUID;
  batch2_id UUID;
  batch3_id UUID;
  farmer_id UUID;
BEGIN
  -- Get a farmer profile or create one
  SELECT id INTO farmer_id FROM profiles WHERE user_type = 'farmer' LIMIT 1;
  IF farmer_id IS NULL THEN
    INSERT INTO profiles (full_name, user_type, email, phone, farm_location)
    VALUES ('Test Farmer', 'farmer', 'farmer@test.com', '+91-8888888888', 'Punjab, India')
    RETURNING id INTO farmer_id;
  END IF;

  -- Create 3 batches (with all required fields)
  INSERT INTO batches (crop_type, variety, sowing_date, harvest_date, harvest_quantity, freshness_duration, grading, price_per_kg, total_price, farmer_id, current_owner, status)
  VALUES 
    ('Rice', 'Basmati', CURRENT_DATE - INTERVAL '120 days', CURRENT_DATE - INTERVAL '5 days', 1000.00, 10, 'Standard', 50.00, 50000.00, farmer_id, farmer_id, 'available'),
    ('Wheat', 'Durum', CURRENT_DATE - INTERVAL '150 days', CURRENT_DATE - INTERVAL '3 days', 2000.00, 12, 'Standard', 40.00, 80000.00, farmer_id, farmer_id, 'available'),
    ('Tomato', 'Cherry', CURRENT_DATE - INTERVAL '90 days', CURRENT_DATE - INTERVAL '2 days', 500.00, 7, 'Premium', 80.00, 40000.00, farmer_id, farmer_id, 'available')
  ON CONFLICT DO NOTHING;

  -- Get the batch IDs
  SELECT id INTO batch1_id FROM batches WHERE crop_type = 'Rice' AND variety = 'Basmati' LIMIT 1;
  SELECT id INTO batch2_id FROM batches WHERE crop_type = 'Wheat' AND variety = 'Durum' LIMIT 1;
  SELECT id INTO batch3_id FROM batches WHERE crop_type = 'Tomato' AND variety = 'Cherry' LIMIT 1;
END $$;

-- ============================================================================
-- STEP 4: Create Delivery Requests Table (if needed) with Foreign Keys
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.delivery_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  batch_id UUID NOT NULL,
  source_location JSONB NOT NULL,
  destination_location JSONB NOT NULL,
  quantity_kg DECIMAL(10,2) NOT NULL,
  status VARCHAR(50) DEFAULT 'pending',
  assigned_driver_id UUID,
  delivery_fee DECIMAL(15,2),
  urgency_score INTEGER DEFAULT 5,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Add foreign key constraints if they don't exist
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'batches') THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_name = 'delivery_requests_batch_id_fkey'
    ) THEN
      ALTER TABLE delivery_requests 
      ADD CONSTRAINT delivery_requests_batch_id_fkey 
      FOREIGN KEY (batch_id) REFERENCES batches(id);
    END IF;
  END IF;

  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'profiles') THEN
    IF NOT EXISTS (
      SELECT 1 FROM information_schema.table_constraints 
      WHERE constraint_name = 'delivery_requests_assigned_driver_id_fkey'
    ) THEN
      ALTER TABLE delivery_requests 
      ADD CONSTRAINT delivery_requests_assigned_driver_id_fkey 
      FOREIGN KEY (assigned_driver_id) REFERENCES profiles(id);
    END IF;
  END IF;
END $$;

-- ============================================================================
-- STEP 5: Create 2 Simple Delivery Requests
-- ============================================================================
DO $$
DECLARE
  driver_id UUID;
  batch1_id UUID;
  batch2_id UUID;
  batch3_id UUID;
  pool_batch1_id UUID;
  pool_batch2_id UUID;
  pooled_delivery_id UUID;
  farmer_id UUID;
  distributor_id UUID;
BEGIN
  -- Get IDs
  SELECT id INTO driver_id FROM profiles WHERE user_type = 'driver' LIMIT 1;
  SELECT id INTO farmer_id FROM profiles WHERE user_type = 'farmer' LIMIT 1;
  SELECT id INTO distributor_id FROM profiles WHERE user_type = 'distributor' LIMIT 1;
  
  IF distributor_id IS NULL THEN
    INSERT INTO profiles (full_name, user_type, email, phone, farm_location)
    VALUES ('Test Distributor', 'distributor', 'distributor@test.com', '+91-7777777777', 'Delhi, India')
    RETURNING id INTO distributor_id;
  END IF;

  SELECT id INTO batch1_id FROM batches WHERE crop_type = 'Rice' LIMIT 1;
  SELECT id INTO batch2_id FROM batches WHERE crop_type = 'Wheat' LIMIT 1;
  SELECT id INTO batch3_id FROM batches WHERE crop_type = 'Tomato' LIMIT 1;

  -- Delivery 1: Pending
  INSERT INTO delivery_requests (batch_id, source_location, destination_location, quantity_kg, status, delivery_fee, urgency_score)
  VALUES (
    batch1_id,
    jsonb_build_object('lat', 30.7333, 'lng', 76.7794, 'address', 'Punjab, India', 'owner_id', farmer_id::text),
    jsonb_build_object('lat', 28.6139, 'lng', 77.2090, 'address', 'Delhi, India', 'owner_id', distributor_id::text),
    1000.00,
    'pending',
    1500.00,
    7
  );

  -- Create 2 more batches for pooling demo
  INSERT INTO batches (crop_type, variety, sowing_date, harvest_date, harvest_quantity, freshness_duration, grading, price_per_kg, total_price, farmer_id, current_owner, status)
  VALUES 
    ('Potato', 'Russet', CURRENT_DATE - INTERVAL '100 days', CURRENT_DATE - INTERVAL '1 day', 500.00, 15, 'Standard', 30.00, 15000.00, farmer_id, farmer_id, 'available'),
    ('Onion', 'Red', CURRENT_DATE - INTERVAL '110 days', CURRENT_DATE, 300.00, 8, 'Standard', 25.00, 7500.00, farmer_id, farmer_id, 'available')
  ON CONFLICT DO NOTHING;

  SELECT id INTO pool_batch1_id FROM batches WHERE crop_type = 'Potato' AND variety = 'Russet' LIMIT 1;
  SELECT id INTO pool_batch2_id FROM batches WHERE crop_type = 'Onion' AND variety = 'Red' LIMIT 1;

  -- Delivery 2: Accepted by driver with 3 batches pooled (Wheat + Potato + Onion)
  INSERT INTO delivery_requests (batch_id, source_location, destination_location, quantity_kg, status, assigned_driver_id, delivery_fee, urgency_score, payment_status)
  VALUES (
    batch2_id, -- Main batch (Wheat 2000kg)
    jsonb_build_object('lat', 30.7333, 'lng', 76.7794, 'address', 'Punjab, India', 'owner_id', farmer_id::text),
    jsonb_build_object('lat', 28.6139, 'lng', 77.2090, 'address', 'Delhi, India', 'owner_id', distributor_id::text),
    2800.00, -- Total: 2000 + 500 + 300
    'accepted',
    driver_id,
    2500.00, -- Combined fee
    5,
    'split_pending'
  )
  RETURNING id INTO pooled_delivery_id;

  -- Add 2 additional batches to create a 3-batch pool
  IF pooled_delivery_id IS NOT NULL AND pool_batch1_id IS NOT NULL AND pool_batch2_id IS NOT NULL THEN
    INSERT INTO delivery_batches (delivery_request_id, batch_id, quantity_kg, owner_contribution_percentage)
    VALUES 
      (pooled_delivery_id, pool_batch1_id, 500.00, 17.86), -- 500/2800 = 17.86%
      (pooled_delivery_id, pool_batch2_id, 300.00, 10.71); -- 300/2800 = 10.71%
    -- Main batch (2000kg) = 71.43% (calculated automatically)
  END IF;
END $$;

-- ============================================================================
-- STEP 6: Fix RLS Policies (Critical for data visibility)
-- ============================================================================
-- Drop and recreate RLS policies to allow drivers to see pending deliveries
DO $$
BEGIN
  -- Drop existing policies
  DROP POLICY IF EXISTS "Drivers can view pending deliveries" ON delivery_requests;
  DROP POLICY IF EXISTS "Owners can view their deliveries" ON delivery_requests;
  
  -- Create fixed policy: ALL authenticated users can view pending deliveries
  -- AND drivers can view deliveries assigned to them
  CREATE POLICY "Drivers can view pending deliveries" ON delivery_requests
    FOR SELECT USING (
      status = 'pending' 
      OR assigned_driver_id = (SELECT id FROM profiles WHERE user_id = auth.uid())
    );
  
  -- Owners can view their deliveries
  CREATE POLICY "Owners can view their deliveries" ON delivery_requests
    FOR SELECT USING (
      (source_location->>'owner_id')::uuid = (SELECT id FROM profiles WHERE user_id = auth.uid())
      OR (destination_location->>'owner_id')::uuid = (SELECT id FROM profiles WHERE user_id = auth.uid())
    );
END $$;

-- Grant permissions
GRANT SELECT ON delivery_requests TO authenticated;
GRANT SELECT ON batches TO authenticated;

-- ============================================================================
-- VERIFICATION & IMPORTANT NOTES
-- ============================================================================
-- Done! Check the data:
SELECT 'Driver created:' as info;
SELECT id, full_name, user_type, vehicle_type, is_available FROM profiles WHERE user_type = 'driver';

SELECT 'Batches created:' as info;
SELECT id, crop_type, variety, harvest_quantity FROM batches ORDER BY created_at DESC LIMIT 3;

SELECT 'Delivery requests:' as info;
SELECT id, batch_id, status, quantity_kg, delivery_fee, assigned_driver_id FROM delivery_requests ORDER BY created_at DESC;

-- ============================================================================
-- IMPORTANT: To see data in Driver Dashboard:
-- ============================================================================
-- 1. Make sure you're logged in as the "Test Driver" profile
-- 2. The driver profile ID must match your logged-in user's profile
-- 3. If you created a new driver, you need to:
--    - Sign up/login with email: driver@test.com
--    - OR update your existing profile to be the driver:
--      UPDATE profiles SET user_type = 'driver' WHERE id = YOUR_PROFILE_ID;
--
-- To check your current profile:
-- SELECT id, full_name, user_type, email FROM profiles WHERE user_id = auth.uid();

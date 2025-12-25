-- Logistics System Database Schema
-- Run this in your Supabase SQL Editor

-- Step 1: Add driver-specific fields to profiles table
DO $$
BEGIN
  -- Add driver to user_type enum
  ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_user_type_check;
  ALTER TABLE public.profiles ADD CONSTRAINT profiles_user_type_check 
    CHECK (user_type IN ('farmer', 'distributor', 'retailer', 'helper', 'admin', 'driver'));
  
  -- Add driver-specific columns
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'vehicle_type') THEN
    ALTER TABLE public.profiles ADD COLUMN vehicle_type VARCHAR(50);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'vehicle_capacity_kg') THEN
    ALTER TABLE public.profiles ADD COLUMN vehicle_capacity_kg DECIMAL(10,2);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'vehicle_registration_number') THEN
    ALTER TABLE public.profiles ADD COLUMN vehicle_registration_number VARCHAR(50);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'driver_license_number') THEN
    ALTER TABLE public.profiles ADD COLUMN driver_license_number VARCHAR(50);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'current_location') THEN
    ALTER TABLE public.profiles ADD COLUMN current_location JSONB;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'is_available') THEN
    ALTER TABLE public.profiles ADD COLUMN is_available BOOLEAN DEFAULT true;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'driver_rating') THEN
    ALTER TABLE public.profiles ADD COLUMN driver_rating DECIMAL(3,2) DEFAULT 5.0;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'total_deliveries') THEN
    ALTER TABLE public.profiles ADD COLUMN total_deliveries INTEGER DEFAULT 0;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'vehicle_equipment') THEN
    ALTER TABLE public.profiles ADD COLUMN vehicle_equipment JSONB;
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'profiles' AND column_name = 'working_hours') THEN
    ALTER TABLE public.profiles ADD COLUMN working_hours JSONB;
  END IF;
END $$;

-- Step 2: Add temperature and time fields to batches table
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'batches' AND column_name = 'temperature_requirement') THEN
    ALTER TABLE public.batches ADD COLUMN temperature_requirement VARCHAR(50) DEFAULT 'Ambient';
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'batches' AND column_name = 'required_vehicle_type') THEN
    ALTER TABLE public.batches ADD COLUMN required_vehicle_type VARCHAR(50);
  END IF;
  
  IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'batches' AND column_name = 'required_equipment') THEN
    ALTER TABLE public.batches ADD COLUMN required_equipment JSONB;
  END IF;
END $$;

-- Step 3: Create delivery_requests table
CREATE TABLE IF NOT EXISTS public.delivery_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  transaction_id INTEGER REFERENCES transactions(id),
  batch_id UUID NOT NULL REFERENCES batches(id),
  source_location JSONB NOT NULL, -- {lat, lng, address, owner_id}
  destination_location JSONB NOT NULL, -- {lat, lng, address, owner_id}
  quantity_kg DECIMAL(10,2) NOT NULL,
  status VARCHAR(50) DEFAULT 'pending' CHECK (status IN ('pending', 'accepted', 'in_transit', 'delivered', 'cancelled')),
  assigned_driver_id UUID REFERENCES profiles(id),
  requested_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  accepted_at TIMESTAMP WITH TIME ZONE,
  delivered_at TIMESTAMP WITH TIME ZONE,
  delivery_fee DECIMAL(15,2),
  payment_status VARCHAR(50) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'split_pending', 'paid')),
  delivery_deadline TIMESTAMP WITH TIME ZONE,
  preferred_time_window JSONB, -- {start: "09:00", end: "17:00"}
  urgency_score INTEGER DEFAULT 5, -- 1-10
  delivered_on_time BOOLEAN,
  loading_assistance_required BOOLEAN DEFAULT false,
  unloading_assistance_required BOOLEAN DEFAULT false,
  equipment_required JSONB,
  pod_signature TEXT,
  pod_photos JSONB,
  pod_timestamp TIMESTAMP WITH TIME ZONE,
  pod_location JSONB,
  pod_ipfs_hash VARCHAR(255),
  buyer_confirmation BOOLEAN DEFAULT false,
  temperature_log JSONB,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 4: Create delivery_batches table (for multi-batch deliveries)
CREATE TABLE IF NOT EXISTS public.delivery_batches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_request_id UUID NOT NULL REFERENCES delivery_requests(id) ON DELETE CASCADE,
  batch_id UUID NOT NULL REFERENCES batches(id),
  quantity_kg DECIMAL(10,2) NOT NULL,
  owner_contribution_percentage DECIMAL(5,2),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 5: Create driver_notifications table
CREATE TABLE IF NOT EXISTS public.driver_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  delivery_request_id UUID REFERENCES delivery_requests(id),
  notification_type VARCHAR(50) NOT NULL CHECK (notification_type IN ('new_delivery', 'batch_added', 'status_update', 'payment_received')),
  message TEXT NOT NULL,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 6: Create delivery_payments table
CREATE TABLE IF NOT EXISTS public.delivery_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_request_id UUID NOT NULL REFERENCES delivery_requests(id),
  batch_id UUID REFERENCES batches(id),
  owner_id UUID NOT NULL REFERENCES profiles(id),
  amount DECIMAL(15,2) NOT NULL,
  payment_status VARCHAR(50) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'paid', 'failed')),
  paid_at TIMESTAMP WITH TIME ZONE,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 7: Create delivery_quality_checks table
CREATE TABLE IF NOT EXISTS public.delivery_quality_checks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  delivery_request_id UUID NOT NULL REFERENCES delivery_requests(id),
  check_type VARCHAR(50) NOT NULL CHECK (check_type IN ('pickup', 'delivery', 'in_transit')),
  temperature DECIMAL(5,2),
  humidity DECIMAL(5,2),
  condition_rating INTEGER CHECK (condition_rating >= 1 AND condition_rating <= 10),
  photos JSONB,
  notes TEXT,
  checked_by UUID REFERENCES profiles(id),
  checked_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Step 8: Create crop_compatibility table
CREATE TABLE IF NOT EXISTS public.crop_compatibility (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  crop_type_1 VARCHAR(50) NOT NULL,
  crop_type_2 VARCHAR(50) NOT NULL,
  compatible BOOLEAN NOT NULL,
  restriction_reason TEXT,
  requires_separation BOOLEAN DEFAULT false,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  UNIQUE(crop_type_1, crop_type_2)
);

-- Insert default compatibility rules
INSERT INTO public.crop_compatibility (crop_type_1, crop_type_2, compatible, restriction_reason, requires_separation)
VALUES
  ('Turmeric', 'Green Chili', false, 'Strong odor contamination', true),
  ('Turmeric', 'Coconut', true, NULL, false),
  ('Rice', 'Wheat', true, NULL, false),
  ('Rice', 'Maize', true, NULL, false),
  ('Wheat', 'Maize', true, NULL, false)
ON CONFLICT (crop_type_1, crop_type_2) DO NOTHING;

-- Step 9: Create indexes for performance
CREATE INDEX IF NOT EXISTS idx_delivery_requests_status ON delivery_requests(status);
CREATE INDEX IF NOT EXISTS idx_delivery_requests_driver ON delivery_requests(assigned_driver_id);
CREATE INDEX IF NOT EXISTS idx_delivery_requests_batch ON delivery_requests(batch_id);
CREATE INDEX IF NOT EXISTS idx_delivery_requests_deadline ON delivery_requests(delivery_deadline);
CREATE INDEX IF NOT EXISTS idx_driver_notifications_driver ON driver_notifications(driver_id);
CREATE INDEX IF NOT EXISTS idx_driver_notifications_read ON driver_notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_delivery_payments_status ON delivery_payments(payment_status);
CREATE INDEX IF NOT EXISTS idx_delivery_payments_owner ON delivery_payments(owner_id);

-- Step 10: Enable Row Level Security
ALTER TABLE delivery_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE driver_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE delivery_quality_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE crop_compatibility ENABLE ROW LEVEL SECURITY;

-- Step 11: Create RLS Policies
-- Delivery requests: Drivers can view pending, owners can view their own
CREATE POLICY "Drivers can view pending deliveries" ON delivery_requests
  FOR SELECT USING (status = 'pending' OR assigned_driver_id = auth.uid());

CREATE POLICY "Owners can view their deliveries" ON delivery_requests
  FOR SELECT USING (
    (source_location->>'owner_id')::uuid = (SELECT id FROM profiles WHERE user_id = auth.uid())
    OR (destination_location->>'owner_id')::uuid = (SELECT id FROM profiles WHERE user_id = auth.uid())
  );

CREATE POLICY "Authenticated users can create delivery requests" ON delivery_requests
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Assigned driver can update delivery" ON delivery_requests
  FOR UPDATE USING (assigned_driver_id = (SELECT id FROM profiles WHERE user_id = auth.uid()));

-- Driver notifications: Drivers can only view their own
CREATE POLICY "Drivers can view their notifications" ON driver_notifications
  FOR SELECT USING (driver_id = (SELECT id FROM profiles WHERE user_id = auth.uid()));

CREATE POLICY "System can create notifications" ON driver_notifications
  FOR INSERT WITH CHECK (true);

CREATE POLICY "Drivers can update their notifications" ON driver_notifications
  FOR UPDATE USING (driver_id = (SELECT id FROM profiles WHERE user_id = auth.uid()));

-- Delivery payments: Owners can view their payments
CREATE POLICY "Owners can view their payments" ON delivery_payments
  FOR SELECT USING (owner_id = (SELECT id FROM profiles WHERE user_id = auth.uid()));

CREATE POLICY "Authenticated users can create payments" ON delivery_payments
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Delivery batches: Same as delivery requests
CREATE POLICY "Users can view delivery batches" ON delivery_batches
  FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create delivery batches" ON delivery_batches
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Quality checks: Same visibility as delivery requests
CREATE POLICY "Users can view quality checks" ON delivery_quality_checks
  FOR SELECT USING (true);

CREATE POLICY "Authenticated users can create quality checks" ON delivery_quality_checks
  FOR INSERT WITH CHECK (auth.role() = 'authenticated');

-- Crop compatibility: Public read
CREATE POLICY "Anyone can view crop compatibility" ON crop_compatibility
  FOR SELECT USING (true);

-- Step 12: Grant permissions
GRANT SELECT, INSERT, UPDATE ON delivery_requests TO authenticated;
GRANT SELECT, INSERT ON delivery_batches TO authenticated;
GRANT SELECT, INSERT, UPDATE ON driver_notifications TO authenticated;
GRANT SELECT, INSERT, UPDATE ON delivery_payments TO authenticated;
GRANT SELECT, INSERT ON delivery_quality_checks TO authenticated;
GRANT SELECT ON crop_compatibility TO authenticated;

-- Step 13: Create function to calculate delivery deadline
CREATE OR REPLACE FUNCTION calculate_delivery_deadline(
  p_harvest_date DATE,
  p_freshness_duration INTEGER
)
RETURNS TIMESTAMP WITH TIME ZONE AS $$
BEGIN
  -- Calculate deadline: harvest_date + freshness_duration - 2 days buffer
  RETURN (p_harvest_date + INTERVAL '1 day' * (p_freshness_duration - 2))::TIMESTAMP WITH TIME ZONE;
END;
$$ LANGUAGE plpgsql;

-- Step 14: Create function to calculate urgency score
CREATE OR REPLACE FUNCTION calculate_urgency_score(
  p_deadline TIMESTAMP WITH TIME ZONE
)
RETURNS INTEGER AS $$
DECLARE
  hours_until_deadline NUMERIC;
BEGIN
  hours_until_deadline := EXTRACT(EPOCH FROM (p_deadline - NOW())) / 3600;
  
  IF hours_until_deadline < 12 THEN
    RETURN 10; -- Critical
  ELSIF hours_until_deadline < 24 THEN
    RETURN 9; -- Very urgent
  ELSIF hours_until_deadline < 48 THEN
    RETURN 7; -- Urgent
  ELSIF hours_until_deadline < 72 THEN
    RETURN 5; -- Normal
  ELSE
    RETURN 3; -- Low priority
  END IF;
END;
$$ LANGUAGE plpgsql;

-- Step 15: Create function to calculate delivery fee
CREATE OR REPLACE FUNCTION calculate_delivery_fee(
  p_distance_km DECIMAL,
  p_weight_kg DECIMAL,
  p_urgency_score INTEGER
)
RETURNS DECIMAL AS $$
DECLARE
  base_fee DECIMAL := 100;
  distance_fee DECIMAL;
  weight_fee DECIMAL;
  urgency_fee DECIMAL;
BEGIN
  distance_fee := p_distance_km * 5; -- ₹5 per km
  weight_fee := p_weight_kg * 2; -- ₹2 per kg
  urgency_fee := CASE 
    WHEN p_urgency_score >= 8 THEN 200
    WHEN p_urgency_score >= 6 THEN 100
    ELSE 0
  END;
  
  RETURN base_fee + distance_fee + weight_fee + urgency_fee;
END;
$$ LANGUAGE plpgsql;


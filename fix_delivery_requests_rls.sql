-- Fix RLS Policies for Delivery Requests
-- This fixes the issue where drivers can't see pending deliveries

-- Drop existing policies
DROP POLICY IF EXISTS "Drivers can view pending deliveries" ON delivery_requests;
DROP POLICY IF EXISTS "Owners can view their deliveries" ON delivery_requests;

-- Fix the policy: Drivers can view ALL pending deliveries (not just their own)
-- And drivers can view deliveries assigned to them
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

-- Make sure authenticated users can read delivery requests
GRANT SELECT ON delivery_requests TO authenticated;


-- Quick Fix: Make delivery_requests visible to all authenticated users
-- Run this in Supabase SQL Editor to fix the dashboard data visibility issue

-- Drop restrictive policies
DROP POLICY IF EXISTS "Drivers can view pending deliveries" ON delivery_requests;
DROP POLICY IF EXISTS "Owners can view their deliveries" ON delivery_requests;

-- Create simple, permissive policy: All authenticated users can view all delivery requests
-- This allows drivers to see pending deliveries and their assigned deliveries
CREATE POLICY "Authenticated users can view delivery requests" ON delivery_requests
  FOR SELECT USING (auth.role() = 'authenticated');

-- Also ensure batches are visible
GRANT SELECT ON batches TO authenticated;
GRANT SELECT ON delivery_requests TO authenticated;

-- Verify the data exists
SELECT 'Total delivery requests:' as info, COUNT(*) as count FROM delivery_requests;
SELECT 'Pending delivery requests:' as info, COUNT(*) as count FROM delivery_requests WHERE status = 'pending';
SELECT 'Active delivery requests:' as info, COUNT(*) as count FROM delivery_requests WHERE status IN ('accepted', 'in_transit');

-- Show your current profile
SELECT 'Your profile:' as info, id, full_name, user_type, email FROM profiles WHERE user_id = auth.uid();


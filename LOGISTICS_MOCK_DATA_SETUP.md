# Logistics Mock Data Setup Guide

This guide explains how to set up dummy/mock data for the logistics system in AgriTrace.

## 📋 Prerequisites

1. **Database Schema**: Make sure you've run `create_logistics_schema.sql` first
   - This creates all the necessary tables, functions, and RLS policies
   - Run it in your Supabase SQL Editor

2. **Supabase Access**: You need access to your Supabase project's SQL Editor

## 🚀 Quick Setup

### Step 1: Run the Schema (if not already done)
```sql
-- Run create_logistics_schema.sql in Supabase SQL Editor
```

### Step 2: Insert Mock Data
```sql
-- Run insert_logistics_mock_data.sql in Supabase SQL Editor
```

That's it! The script will automatically:
- Create or update driver profiles
- Create delivery requests with various statuses
- Create driver notifications
- Create delivery batches (multi-batch deliveries)
- Create delivery payments
- Create quality checks

## 📊 What Data Gets Created

### 1. **Driver Profiles** (3 drivers)
- **Rajesh Kumar**: Truck driver (5000kg capacity) - Available
- **Priya Sharma**: Van driver (2000kg capacity) - Available  
- **Amit Patel**: Motorcycle driver (100kg capacity) - Currently on delivery

### 2. **Delivery Requests** (6 deliveries)
- **Pending (High Urgency)**: Rice delivery - 1000kg, 12 hours deadline
- **Accepted**: Wheat delivery - 2000kg, assigned to Rajesh
- **In Transit**: Tomato delivery (refrigerated) - 500kg, assigned to Priya
- **Delivered**: Potato delivery - 1500kg, completed by Amit
- **Pending (Low Urgency)**: Onion delivery - 800kg, 5 days deadline
- **Multi-Batch Pending**: Combined Maize + Soybean - 2500kg total

### 3. **Driver Notifications** (Multiple)
- New delivery notifications for all drivers
- Status update notifications
- Payment received notifications

### 4. **Delivery Payments**
- Completed delivery payments (split between seller and buyer)
- Pending payments for accepted deliveries

### 5. **Quality Checks**
- Pickup quality checks
- In-transit quality checks
- Delivery quality checks

## 🔍 Verifying the Data

After running the script, you can verify the data using the verification queries at the end of the SQL file, or run these:

```sql
-- Check drivers
SELECT full_name, vehicle_type, is_available, driver_rating 
FROM profiles 
WHERE user_type = 'driver';

-- Check delivery requests
SELECT status, quantity_kg, delivery_fee, urgency_score 
FROM delivery_requests 
ORDER BY created_at DESC;

-- Check notifications
SELECT notification_type, message, is_read 
FROM driver_notifications 
ORDER BY created_at DESC;
```

## 🎯 Testing Scenarios

With this mock data, you can test:

1. **Driver Dashboard**
   - View pending deliveries
   - Accept/reject deliveries
   - See active deliveries
   - View delivery history

2. **My Deliveries**
   - View deliveries as buyer
   - View deliveries as seller
   - Track delivery status

3. **Notifications**
   - See new delivery notifications
   - Mark notifications as read
   - View payment notifications

4. **Delivery Flow**
   - Accept a pending delivery
   - Start an accepted delivery
   - Complete an in-transit delivery
   - View proof of delivery

## 🔄 Resetting Mock Data

If you want to reset and re-insert the mock data:

```sql
-- Delete existing mock data (be careful!)
DELETE FROM delivery_quality_checks;
DELETE FROM delivery_payments;
DELETE FROM delivery_batches;
DELETE FROM driver_notifications;
DELETE FROM delivery_requests;
-- Note: This won't delete driver profiles, just their delivery data

-- Then re-run insert_logistics_mock_data.sql
```

## ⚠️ Important Notes

1. **Existing Data**: The script is designed to work with existing profiles and batches
   - If profiles/batches exist, it will use them
   - If they don't exist, it will create new ones

2. **Driver Profiles**: The script updates existing profiles to be drivers
   - If a profile with the same name exists, it will be updated
   - Otherwise, new driver profiles will be created

3. **Foreign Keys**: All foreign key relationships are properly maintained
   - Delivery requests reference valid batches
   - Notifications reference valid drivers
   - Payments reference valid owners

4. **RLS Policies**: Make sure RLS policies are set up correctly
   - Run `create_logistics_schema.sql` first
   - The mock data respects RLS policies

## 🐛 Troubleshooting

### Issue: "Foreign key constraint violation"
- **Solution**: Make sure you've run `create_logistics_schema.sql` first
- Check that the `batches` and `profiles` tables exist

### Issue: "Column does not exist"
- **Solution**: Run `create_logistics_schema.sql` to add all required columns
- The schema script adds driver-specific columns to profiles table

### Issue: "Permission denied"
- **Solution**: Check RLS policies in `create_logistics_schema.sql`
- Make sure you're running as an authenticated user or admin

### Issue: "No batches found"
- **Solution**: The script will create batches if none exist
- If you have existing batches, it will use those instead

## 📝 Customizing Mock Data

You can customize the mock data by editing `insert_logistics_mock_data.sql`:

1. **Add More Drivers**: Add more driver profiles in the DECLARE section
2. **Change Locations**: Update lat/lng coordinates for different cities
3. **Adjust Quantities**: Modify quantity_kg values
4. **Change Statuses**: Create more deliveries with different statuses
5. **Add More Notifications**: Create additional notification scenarios

## 🎉 Next Steps

After setting up mock data:

1. **Test the UI**: Navigate to Driver Dashboard and My Deliveries
2. **Test Notifications**: Check driver notifications
3. **Test Delivery Flow**: Accept, start, and complete deliveries
4. **Test Payments**: Verify payment splitting works correctly
5. **Test Quality Checks**: View quality check records

## 📚 Related Files

- `create_logistics_schema.sql` - Database schema setup
- `src/services/deliveryService.ts` - Delivery service functions
- `src/hooks/useDeliveryRequests.ts` - React hooks for deliveries
- `src/pages/DriverDashboard.tsx` - Driver dashboard UI
- `src/pages/MyDeliveries.tsx` - My deliveries page

---

**Need Help?** Check the main documentation in `LOGISTICS_IMPLEMENTATION_SUMMARY.md`


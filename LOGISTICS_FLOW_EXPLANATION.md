# Logistics Flow Explanation

## How Deliveries Appear in "My Deliveries"

### **The Complete Flow:**

1. **Purchase Made** (Farmer → Distributor)
   - Distributor buys batch from farmer
   - Purchase happens in `UltraSimplePurchaseModal`
   - Transaction is recorded in `transactions` table

2. **Delivery Request Created** (Automatic)
   - After successful purchase, code automatically calls `createDeliveryRequest()`
   - Creates entry in `delivery_requests` table with:
     - `source_location`: { lat, lng, address, owner_id: **seller's profile.id** }
     - `destination_location`: { lat, lng, address, owner_id: **buyer's profile.id** }
     - `batch_id`: The purchased batch
     - `status`: 'pending'
     - `delivery_fee`: Calculated based on distance, weight, urgency

3. **My Deliveries Query**
   - When you open "My Deliveries" page
   - It calls `getUserDeliveryRequests(profile.id)`
   - Queries `delivery_requests` table
   - Filters where:
     - `source_location->>'owner_id'` = your profile.id (you're the seller)
     - OR `destination_location->>'owner_id'` = your profile.id (you're the buyer)

4. **Display**
   - Shows all deliveries where you're either buyer or seller
   - Displays status, locations, fees, etc.

---

## **Why It Might Not Show Up:**

### **Issue 1: Delivery Request Not Created**
- Check browser console for errors
- Look for: `✅ Delivery request created` or `⚠️ Failed to create delivery request`
- If error, check:
  - Database schema is run correctly
  - `delivery_requests` table exists
  - Permissions are set correctly

### **Issue 2: Profile ID Mismatch**
- The `owner_id` in `source_location`/`destination_location` must match your `profile.id`
- Check:
  - What is your `profile.id`? (Check in browser console or Profile page)
  - What is stored in `delivery_requests.source_location.owner_id`?
  - They must be **exact match** (UUID format)

### **Issue 3: Query Not Working**
- The JSONB query might not work correctly
- **Fixed**: Now fetches all and filters in JavaScript (more reliable)

---

## **Debugging Steps:**

### **Step 1: Check if Delivery Request Was Created**
```sql
-- Run in Supabase SQL Editor
SELECT * FROM delivery_requests 
ORDER BY created_at DESC 
LIMIT 5;
```

Check:
- Does a delivery request exist for your purchase?
- What are the `source_location` and `destination_location` values?
- What is the `owner_id` in each?

### **Step 2: Check Your Profile ID**
```sql
-- Run in Supabase SQL Editor
SELECT id, full_name, user_type, email 
FROM profiles 
WHERE user_id = auth.uid();
```

Note your `profile.id` (UUID)

### **Step 3: Compare IDs**
- Check if `delivery_requests.destination_location->>'owner_id'` matches your `profile.id`
- They must be **exact match**

### **Step 4: Check Browser Console**
- Open browser DevTools (F12)
- Go to Console tab
- Look for logs:
  - `🚚 Creating delivery request:`
  - `✅ Delivery request created successfully:`
  - `🔍 Fetching delivery requests for user:`
  - `✅ Found matching delivery:`

---

## **Common Issues & Fixes:**

### **Issue: "Delivery request not created"**
**Cause:** Error during creation (caught silently)
**Fix:** 
- Check browser console for errors
- Verify database schema is correct
- Check RLS policies allow INSERT

### **Issue: "Delivery exists but not showing"**
**Cause:** Profile ID mismatch
**Fix:**
- Ensure `profile.id` matches `destination_location.owner_id`
- Check if profile was created correctly
- Verify UUID format matches

### **Issue: "Query returns empty"**
**Cause:** JSONB query syntax issue
**Fix:**
- **Already fixed** - Now uses JavaScript filtering
- Refresh the page
- Check console logs

---

## **How to Test:**

1. **Make a Purchase:**
   - Go to Marketplace
   - Buy a batch
   - Enter delivery address
   - Complete purchase

2. **Check Console:**
   - Open DevTools (F12)
   - Look for: `✅ Delivery request created successfully: [UUID]`

3. **Check Database:**
   ```sql
   SELECT * FROM delivery_requests 
   WHERE destination_location->>'owner_id' = 'YOUR_PROFILE_ID'
   ORDER BY created_at DESC;
   ```

4. **Check My Deliveries:**
   - Go to Account → My Deliveries
   - Should see the delivery request
   - Check console for: `✅ Found matching delivery:`

---

## **Updated Code:**

The query has been **improved** to:
1. Fetch all delivery requests
2. Filter in JavaScript (more reliable than JSONB queries)
3. Add detailed logging for debugging
4. Handle both string and object JSONB formats

**Refresh your browser** and try again!

---

## **Still Not Working?**

1. **Check Database:**
   - Run the SQL queries above
   - Verify data exists

2. **Check Console:**
   - Look for error messages
   - Check the logs

3. **Check Profile:**
   - Make sure you're logged in
   - Verify `profile.id` exists

4. **Try Manual Test:**
   - Create a delivery request manually in database
   - Check if it shows up

If still not working, share:
- Browser console logs
- Database query results
- Your profile.id
- Delivery request data


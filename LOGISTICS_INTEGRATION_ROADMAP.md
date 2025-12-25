# Logistics Integration Roadmap

## Overview
This roadmap outlines the integration of logistics functionality where drivers receive notifications for deliveries, can view routes on maps, accept/reject deliveries, handle multi-batch deliveries, and receive split payments.

---

## Phase 1: Database Schema & Foundation

### 1.1 Driver Profile Extension
- **Add `driver` to user_type enum** in profiles table
- **Add driver-specific fields** to profiles:
  - `vehicle_type` (truck, van, motorcycle, etc.)
  - `vehicle_capacity_kg` (maximum weight capacity)
  - `vehicle_registration_number`
  - `driver_license_number`
  - `current_location` (lat/lng JSONB)
  - `is_available` (boolean)
  - `rating` (decimal)
  - `total_deliveries` (integer)

### 1.2 Delivery Requests Table
- **Create `delivery_requests` table**:
  - `id` (UUID primary key)
  - `transaction_id` (UUID, references transactions.id)
  - `batch_id` (UUID, references batches.id)
  - `source_location` (JSONB: {lat, lng, address, owner_id})
  - `destination_location` (JSONB: {lat, lng, address, owner_id})
  - `quantity_kg` (decimal)
  - `status` (enum: 'pending', 'accepted', 'in_transit', 'delivered', 'cancelled')
  - `assigned_driver_id` (UUID, nullable, references profiles.id)
  - `requested_at` (timestamp)
  - `accepted_at` (timestamp, nullable)
  - `delivered_at` (timestamp, nullable)
  - `delivery_fee` (decimal)
  - `payment_status` (enum: 'pending', 'split_pending', 'paid')
  - `created_at`, `updated_at`

### 1.3 Multi-Batch Delivery Support
- **Create `delivery_batches` junction table**:
  - `id` (UUID primary key)
  - `delivery_request_id` (UUID, references delivery_requests.id)
  - `batch_id` (UUID, references batches.id)
  - `quantity_kg` (decimal)
  - `owner_contribution_percentage` (decimal, for split payment)
  - `created_at`

### 1.4 Driver Notifications Table
- **Create `driver_notifications` table**:
  - `id` (UUID primary key)
  - `driver_id` (UUID, references profiles.id)
  - `delivery_request_id` (UUID, references delivery_requests.id)
  - `notification_type` (enum: 'new_delivery', 'batch_added', 'status_update')
  - `message` (text)
  - `is_read` (boolean, default false)
  - `created_at`

### 1.5 Payment Splitting Table
- **Create `delivery_payments` table**:
  - `id` (UUID primary key)
  - `delivery_request_id` (UUID, references delivery_requests.id)
  - `batch_id` (UUID, references batches.id)
  - `owner_id` (UUID, references profiles.id)
  - `amount` (decimal)
  - `payment_status` (enum: 'pending', 'paid', 'failed')
  - `paid_at` (timestamp, nullable)
  - `created_at`, `updated_at`

---

## Phase 2: Backend Services & Functions

### 2.1 Purchase Transaction Hook
- **Modify purchase completion flow** (`UltraSimplePurchaseModal.tsx`):
  - After successful purchase transaction
  - Extract source location from seller's profile (`farm_location` or geocoded address)
  - Extract destination location from buyer's delivery address
  - Create delivery request with status 'pending'
  - Trigger driver notification system

### 2.2 Delivery Request Service
- **Create `deliveryRequestService.ts`**:
  - `createDeliveryRequest(transactionId, batchId, source, destination, quantity)`
  - `findAvailableDrivers(sourceLocation, requiredCapacity)`
  - `notifyDrivers(deliveryRequestId)`
  - `acceptDeliveryRequest(driverId, deliveryRequestId)`
  - `rejectDeliveryRequest(driverId, deliveryRequestId)`
  - `addBatchToDelivery(deliveryRequestId, batchId, quantity)` (for multi-batch)
  - `calculateSplitPayment(deliveryRequestId)`
  - `updateDeliveryStatus(deliveryRequestId, status)`

### 2.3 Route Matching Algorithm
- **Create `routeMatchingService.ts`**:
  - `findMatchingDeliveries(sourceLocation, destinationLocation, currentCapacity)`
  - Algorithm:
    1. Find all pending deliveries between same source/destination
    2. Check if current delivery can accommodate additional batches
    3. Calculate route efficiency (distance optimization)
    4. Return matching delivery requests
  - `calculateRouteDistance(source, destination)` (using map API)
  - `checkCapacityAvailability(deliveryRequestId, additionalQuantity)`

### 2.4 Geocoding Service
- **Create `geocodingService.ts`**:
  - `geocodeAddress(address)` → returns {lat, lng}
  - Use Google Maps Geocoding API or similar
  - Cache geocoded addresses in database
  - `reverseGeocode(lat, lng)` → returns address

### 2.5 Payment Splitting Service
- **Create `paymentSplittingService.ts`**:
  - `calculateSplitAmounts(deliveryRequestId)`:
    - Get all batches in delivery
    - Calculate total delivery fee
    - Split proportionally based on:
      - Batch quantity (weight-based split)
      - OR equal split
      - OR distance-based split (if source locations differ)
  - `processSplitPayment(deliveryRequestId)`:
    - Create payment records for each batch owner
    - Update payment status
    - Trigger payment notifications

### 2.6 Supabase Database Functions
- **Create RPC functions**:
  - `create_delivery_request(transaction_id, batch_id, source, dest, quantity)`
  - `notify_drivers_for_delivery(delivery_request_id)`
  - `accept_delivery(driver_id, delivery_request_id)`
  - `add_batch_to_delivery(delivery_request_id, batch_id, quantity)`
  - `calculate_delivery_fee(source, destination, quantity)`
  - `split_delivery_payment(delivery_request_id)`

### 2.7 Real-time Notifications
- **Set up Supabase Realtime**:
  - Subscribe to `delivery_requests` table changes
  - Subscribe to `driver_notifications` table changes
  - Push notifications to driver's device/browser
  - Use Supabase Realtime channels for instant updates

---

## Phase 3: Map Integration

### 3.1 Map Library Setup
- **Install map library** (Google Maps, Mapbox, or Leaflet):
  - `@react-google-maps/api` (for Google Maps)
  - OR `react-map-gl` (for Mapbox)
  - OR `react-leaflet` (for OpenStreetMap/Leaflet)

### 3.2 Map Component
- **Create `DeliveryMap.tsx` component**:
  - Display source location marker
  - Display destination location marker
  - Draw route between source and destination
  - Show intermediate stops (if multi-batch)
  - Display driver's current location (if accepted)
  - Show estimated distance and time
  - Interactive map controls

### 3.3 Route Optimization
- **Integrate route API**:
  - Google Maps Directions API
  - OR Mapbox Directions API
  - Calculate optimal route
  - Show turn-by-turn directions
  - Estimate delivery time

### 3.4 Location Services
- **Driver location tracking**:
  - Request location permissions
  - Update driver's `current_location` periodically
  - Show real-time driver position on map
  - Track delivery progress

---

## Phase 4: Driver Dashboard & UI

### 4.1 Driver Registration Flow
- **Create driver signup page** (`/driver-signup`):
  - Vehicle information form
  - License verification
  - Capacity input
  - Location setup

### 4.2 Driver Dashboard
- **Create `/driver-dashboard` page**:
  - List of available delivery requests
  - Map view of all pending deliveries
  - Current active deliveries
  - Delivery history
  - Earnings summary
  - Rating display

### 4.3 Delivery Request Card Component
- **Create `DeliveryRequestCard.tsx`**:
  - Source and destination addresses
  - Batch details (crop type, quantity)
  - Delivery fee amount
  - Distance and estimated time
  - "Accept" and "Reject" buttons
  - Map preview (small)
  - Multi-batch indicator (if applicable)

### 4.4 Delivery Details Modal
- **Create `DeliveryDetailsModal.tsx`**:
  - Full map with route
  - All batch details in delivery
  - Payment split breakdown
  - Contact information (seller/buyer)
  - Delivery instructions
  - Status tracking
  - "Start Delivery" button
  - "Mark as Delivered" button

### 4.5 Multi-Batch Selection UI
- **When driver views delivery request**:
  - Show "Find Additional Batches" button
  - Display matching deliveries on route
  - Show capacity availability
  - Allow driver to add batches to current delivery
  - Update delivery fee calculation
  - Show updated payment split

---

## Phase 5: Notification System

### 5.1 Real-time Driver Notifications
- **Implement notification service**:
  - WebSocket connection (Supabase Realtime)
  - Push notifications (if mobile app)
  - In-app notification bell
  - Sound alerts for new deliveries

### 5.2 Notification Types
- **New delivery request**:
  - "New delivery available: [Source] → [Destination]"
  - Show on map
  - Display delivery fee
- **Batch added to delivery**:
  - "Additional batch added to your delivery"
  - Updated payment split
- **Delivery status updates**:
  - "Delivery accepted"
  - "Delivery started"
  - "Delivery completed"
  - "Payment received"

### 5.3 Notification Preferences
- **Driver settings**:
  - Notification radius (only show deliveries within X km)
  - Minimum delivery fee filter
  - Vehicle capacity filter
  - Working hours preferences

---

## Phase 6: Multi-Batch Delivery Logic

### 6.1 Batch Matching Algorithm
- **When driver accepts a delivery**:
  1. Get source and destination of accepted delivery
  2. Query all pending deliveries:
     - Same source location (or nearby, e.g., within 5km)
     - Same destination location (or nearby)
     - Combined quantity ≤ driver's vehicle capacity
  3. Display matching deliveries to driver
  4. Driver can select additional batches
  5. Update delivery request with added batches
  6. Recalculate delivery fee and split payment

### 6.2 Capacity Management
- **Check available capacity**:
  - Current delivery quantity
  - Driver's vehicle capacity
  - Additional batch quantities
  - Ensure total ≤ capacity
  - Show capacity percentage indicator

### 6.3 Payment Split Calculation
- **Multi-batch payment split**:
  - Option 1: **Weight-based split**
    - Each batch owner pays: `(batch_quantity / total_quantity) × delivery_fee`
  - Option 2: **Equal split**
    - Each batch owner pays: `delivery_fee / number_of_batches`
  - Option 3: **Distance-based split** (if sources differ)
    - Calculate distance from each source to destination
    - Split proportionally: `(source_distance / total_distance) × delivery_fee`
  - **Default: Weight-based split**

---

## Phase 7: Payment Integration

### 7.1 Payment Flow
- **After delivery completion**:
  1. Mark delivery as 'delivered'
  2. Calculate split amounts for each batch owner
  3. Create payment records in `delivery_payments` table
  4. Send payment requests to batch owners
  5. Process payments (via payment gateway or wallet)
  6. Update payment status
  7. Transfer funds to driver

### 7.2 Payment Gateway Integration
- **Integrate payment provider**:
  - Razorpay / Stripe / PayPal
  - OR blockchain wallet payments
  - Handle split payments
  - Payment confirmation webhooks

### 7.3 Payment Notifications
- **Notify batch owners**:
  - "Payment required for delivery: ₹X"
  - Link to payment page
- **Notify driver**:
  - "Payment received: ₹X from [Owner 1], ₹Y from [Owner 2]"
  - Total earnings update

---

## Phase 8: Testing & Optimization

### 8.1 Unit Tests
- Test delivery request creation
- Test route matching algorithm
- Test payment split calculations
- Test capacity checks

### 8.2 Integration Tests
- Test complete delivery flow:
  - Purchase → Delivery Request → Driver Notification → Acceptance → Delivery → Payment
- Test multi-batch flow
- Test payment splitting

### 8.3 Performance Optimization
- Optimize driver matching queries
- Cache geocoded addresses
- Optimize map rendering
- Reduce real-time subscription overhead

### 8.4 User Testing
- Driver usability testing
- Farmer/distributor/retailer feedback
- Map accuracy testing
- Payment flow testing

---

## Phase 9: Security & Permissions

### 9.1 Row Level Security (RLS)
- **Delivery requests**:
  - Drivers can view pending deliveries
  - Only assigned driver can update status
  - Batch owners can view their delivery requests
- **Driver notifications**:
  - Drivers can only view their own notifications
- **Payment records**:
  - Batch owners can view their payment records
  - Drivers can view payment status for their deliveries

### 9.2 Data Validation
- Validate location coordinates
- Validate capacity calculations
- Validate payment amounts
- Prevent duplicate deliveries

---

## Phase 10: Mobile App (Optional)

### 10.1 Driver Mobile App
- React Native / Flutter app
- GPS tracking
- Push notifications
- Offline map support
- Photo upload for delivery proof

---

## Implementation Priority

### High Priority (MVP):
1. Phase 1: Database Schema
2. Phase 2.1-2.2: Purchase Hook & Delivery Request Service
3. Phase 3: Map Integration (basic)
4. Phase 4.2-4.4: Driver Dashboard & Delivery Details
5. Phase 5.1: Basic Notifications

### Medium Priority:
6. Phase 6: Multi-Batch Delivery Logic
7. Phase 7: Payment Integration
8. Phase 2.3-2.6: Advanced Services

### Low Priority (Future Enhancements):
9. Phase 8: Testing & Optimization
10. Phase 9: Security Enhancements
11. Phase 10: Mobile App

---

## Technical Stack Recommendations

- **Maps**: Google Maps API (most reliable) or Mapbox
- **Geocoding**: Google Geocoding API
- **Real-time**: Supabase Realtime (already in use)
- **Payments**: Razorpay (India) or Stripe
- **Location Tracking**: Browser Geolocation API + periodic updates

---

## Estimated Timeline

- **Phase 1-2**: 1-2 weeks (Database + Backend Services)
- **Phase 3**: 1 week (Map Integration)
- **Phase 4**: 1-2 weeks (Driver UI)
- **Phase 5**: 3-5 days (Notifications)
- **Phase 6**: 1 week (Multi-batch Logic)
- **Phase 7**: 1 week (Payment Integration)
- **Phase 8-9**: Ongoing (Testing & Security)

**Total MVP**: ~6-8 weeks
**Full Implementation**: ~10-12 weeks


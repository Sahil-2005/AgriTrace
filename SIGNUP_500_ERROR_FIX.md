# Fix for Supabase 500 Error on Signup

## Problem
You were experiencing a 500 error from Supabase when trying to sign up new users. The error message showed "Error sending confirmation email" and the console displayed:
```
Failed to load resource: the server responded with a status of 500 ()
POST https://klkrexlivtmluosdztxt.supabase.co/auth/v1/signup?redirect_to=http%3A%2F%2Flocalhost%3A8080%2F 500 (Internal Server Error)
AuthApiError: Error sending confirmation email
```

## Root Causes
The 500 error can be caused by:
1. **Email service not configured** - No SMTP settings in Supabase (most common)
2. **Missing database trigger** - No trigger function exists to create profile on signup
3. **Redirect URL not whitelisted** - `http://localhost:8080/` not in allowed URLs
4. **RLS policy blocking** - Row Level Security policies preventing profile creation

## Root Cause
The 500 error was likely caused by one of these issues:
1. **Missing database trigger**: No trigger function exists to automatically create a profile entry when a new user signs up
2. **Failing trigger**: A trigger exists but is failing due to missing columns, constraints, or RLS policy issues
3. **RLS policy blocking**: Row Level Security policies are preventing the profile creation

## Solution

### Step 1: Disable Email Confirmation (Quick Fix for Development)
**This is the fastest fix if you just need to get signup working:**

1. Go to **Supabase Dashboard** → **Authentication** → **Settings**
2. Scroll to **Email Auth** section
3. **Disable "Enable email confirmations"** toggle
4. Click **Save**

This will allow users to sign up immediately without email verification. Perfect for development/testing.

> **Note:** For production, you'll need to configure SMTP settings instead. See `fix_supabase_email_configuration.md` for details.

### Step 2: Run the SQL Fix
Execute the SQL script `fix_signup_500_error.sql` in your Supabase SQL Editor. This script will:

1. **Create/Update profiles table** with the correct structure:
   - `id` (UUID, primary key)
   - `user_id` (UUID, references auth.users)
   - `full_name`, `email`, `user_type`, `farm_location`, `wallet_address`
   - Timestamps (`created_at`, `updated_at`)

2. **Create a trigger function** (`handle_new_user`) that:
   - Automatically creates a profile entry when a new user signs up
   - Extracts user metadata (full_name, user_type, farm_location) from the signup data
   - Handles errors gracefully without blocking user creation

3. **Set up RLS policies** that allow:
   - Anyone to view profiles (SELECT)
   - Users to insert their own profile (INSERT)
   - Users to update their own profile (UPDATE)

4. **Create the trigger** on `auth.users` table that fires after a new user is inserted

### Step 3: Whitelist Redirect URL
Ensure your redirect URL is whitelisted:

1. Go to **Supabase Dashboard** → **Authentication** → **Settings**
2. Scroll to **URL Configuration**
3. Under **Redirect URLs**, add:
   - `http://localhost:8080`
   - `http://localhost:8080/`
   - `http://localhost:8080/**` (wildcard for all paths)
4. Click **Save**

### Step 4: Test Signup
1. Try signing up with a new email address
2. Check the browser console for any errors
3. Verify that a profile entry is created in the `profiles` table

## Files Modified
- `fix_signup_500_error.sql` - SQL script to fix the database trigger issue
- `src/pages/Auth/Signup.tsx` - Improved error handling and logging

## Additional Notes
- The trigger function uses `SECURITY DEFINER` to bypass RLS when creating profiles
- The function includes error handling to prevent user creation from failing if profile creation fails
- All RLS policies are permissive to ensure smooth operation during development

## If Issues Persist
1. Check Supabase logs in the Dashboard → Logs → Postgres Logs
2. Verify the trigger exists: `SELECT * FROM pg_trigger WHERE tgname = 'on_auth_user_created';`
3. Check if profiles table exists: `SELECT * FROM information_schema.tables WHERE table_name = 'profiles';`
4. Verify RLS policies: `SELECT * FROM pg_policies WHERE tablename = 'profiles';`


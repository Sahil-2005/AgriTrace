# Fix: Profile 406 Error - "Cannot coerce the result to a single JSON object"

## Error Message
```
GET /rest/v1/profiles?select=*&user_id=eq.a45c8f96-d02e-4159-b42b-feb660577efb 406 (Not Acceptable)
Profile not found: Cannot coerce the result to a single JSON object
```

## Root Cause
The user signed up successfully, but **no profile was created** in the `profiles` table. This happens when:
1. The database trigger wasn't set up when the user signed up
2. The trigger failed silently
3. The user was created before the trigger was configured

## Solution

### Step 1: Fix Profiles Table Structure and Create Missing Profiles (Immediate Fix)

**Use this script:** `fix_profiles_table_and_create_missing.sql`

This script will:
1. Add any missing columns to the profiles table (user_type, email, full_name, etc.)
2. Create profiles for all existing users who don't have one

**Steps:**
1. Open **Supabase Dashboard** → **SQL Editor**
2. Copy and paste the contents of `fix_profiles_table_and_create_missing.sql`
3. Click **Run**
4. This will fix the table structure and create profiles for all users

**Alternative:** If you already ran `create_missing_profiles.sql` and got column errors, run `fix_profiles_table_and_create_missing.sql` instead - it handles missing columns automatically.

### Step 2: Ensure Trigger is Set Up (Prevent Future Issues)
Run the trigger setup script:

**File:** `fix_signup_500_error.sql`

1. Open **Supabase Dashboard** → **SQL Editor**
2. Copy and paste the contents of `fix_signup_500_error.sql`
3. Click **Run**
4. This ensures new signups automatically create profiles

### Step 3: Code Fix (Already Applied)
The `AuthContext.tsx` has been updated to:
- Use `.maybeSingle()` instead of `.single()` to handle missing profiles gracefully
- Automatically create a profile if one doesn't exist when fetching
- Extract user metadata from auth user data

## What Changed in Code

### Before:
```typescript
.single() // Fails with 406 if no profile exists
```

### After:
```typescript
.maybeSingle() // Returns null if no profile exists
// Then automatically creates profile from user metadata if missing
```

## Verification

After running the SQL scripts, verify:

1. **Check profiles exist:**
   ```sql
   SELECT * FROM profiles;
   ```

2. **Check trigger exists:**
   ```sql
   SELECT * FROM pg_trigger WHERE tgname = 'on_auth_user_created';
   ```

3. **Test signup:**
   - Sign up a new user
   - Check that profile is created automatically
   - No 406 error should appear

## Quick Fix Summary

1. ✅ **Run `create_missing_profiles.sql`** - Creates profiles for existing users
2. ✅ **Run `fix_signup_500_error.sql`** - Sets up trigger for future signups
3. ✅ **Code updated** - AuthContext now handles missing profiles gracefully

After these steps, the 406 error should be resolved! 🎉


# 🚀 QUICK FIX: Profile 406 Error

## Error
```
null value in column "role" of relation "profiles" violates not-null constraint
```

## Solution (2 minutes)

### Run This SQL Script

**File:** `create_profiles_with_role.sql` (simplest fix)

OR

**File:** `fix_profiles_table_and_create_missing.sql` (comprehensive fix)

1. **Open Supabase Dashboard** → **SQL Editor**
2. **Copy and paste** the entire contents of `fix_profiles_table_and_create_missing.sql`
3. **Click Run**
4. **Done!** ✅

## What This Script Does

1. ✅ **Adds missing columns** to profiles table (user_type, email, full_name, etc.)
2. ✅ **Creates profiles** for all existing users who don't have one
3. ✅ **Shows verification** that everything worked

## After Running

- Refresh your app
- The 406 error should be gone
- All users will have profiles

## If You Still Get Errors

Make sure you run `fix_signup_500_error.sql` first to ensure the profiles table structure is correct, then run `fix_profiles_table_and_create_missing.sql`.


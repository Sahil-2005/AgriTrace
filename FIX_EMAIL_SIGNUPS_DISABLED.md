# Fix: "Email signups are disabled" Error

## Error Message
```
AuthApiError: Email signups are disabled
```

## What Happened
You accidentally disabled **email signups** entirely, when you only needed to disable **email confirmations**. These are two different settings!

## Solution: Re-enable Email Signups

### Step 1: Go to Sign In / Providers
1. In Supabase Dashboard → **Authentication** section
2. Click **"Sign In / Providers"** (under CONFIGURATION)
3. Click on **"Email"** provider

### Step 2: Enable Email Signups
You should see these settings:

- ✅ **Enable email signups** ← **Turn this ON** (must be enabled)
- ❌ **Enable email confirmations** ← **Keep this OFF** (for development)

### Step 3: Save
Click **"Save"** at the bottom

## Visual Guide

```
Sign In / Providers → Email Settings:

┌─────────────────────────────────────┐
│ Email Provider Settings             │
├─────────────────────────────────────┤
│ ✅ Enable email signups             │ ← MUST BE ON
│ ❌ Enable email confirmations       │ ← Keep OFF for dev
│                                     │
│ [Save] [Cancel]                     │
└─────────────────────────────────────┘
```

## The Difference

- **Enable email signups** = Allows users to sign up with email/password (MUST be ON)
- **Enable email confirmations** = Requires email verification before login (can be OFF for dev)

## After Fixing

1. **Enable email signups** = ON ✅
2. **Enable email confirmations** = OFF ✅
3. **Save** changes
4. **Test signup** - should work now!

## Quick Checklist

- [ ] Go to Authentication → Sign In / Providers → Email
- [ ] Turn ON "Enable email signups"
- [ ] Turn OFF "Enable email confirmations" (if not already)
- [ ] Click Save
- [ ] Test signup again

That's it! Signup should work now. 🎉


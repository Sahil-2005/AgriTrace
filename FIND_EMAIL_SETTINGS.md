# How to Find Email Confirmation Settings in Supabase

## Step-by-Step Instructions

### Method 1: Through Sign In / Providers (Most Common)

1. **In the Supabase Dashboard**, you're already in **Authentication** section ✅

2. **Look at the left sidebar** under **"CONFIGURATION"**

3. **Click on "Sign In / Providers"** (it's in the CONFIGURATION list)

4. **You'll see different authentication providers:**
   - Email
   - Google
   - GitHub
   - etc.

5. **Click on "Email"** provider

6. **You'll see email settings including:**
   - Enable email confirmations (toggle switch)
   - Email templates
   - SMTP settings
   - etc.

7. **Turn OFF "Enable email confirmations"** toggle

8. **Click "Save"** at the bottom

### Method 2: Through URL Configuration

1. **Click on "URL Configuration"** (also in CONFIGURATION section)

2. **Scroll down** to find email-related settings

3. **Look for "Enable email confirmations"** toggle

### Method 3: Direct URL

If you can't find it, try this direct URL pattern:
```
https://supabase.com/dashboard/project/[YOUR_PROJECT_ID]/auth/providers
```

Replace `[YOUR_PROJECT_ID]` with your project ID: `klkrexlivtmluosdztxt`

So it would be:
```
https://supabase.com/dashboard/project/klkrexlivtmluosdztxt/auth/providers
```

## Visual Guide

Based on your current view:

```
Authentication (left sidebar)
├── MANAGE
│   ├── Users ← You are here
│   └── OAuth Apps
├── NOTIFICATIONS
│   └── Email
└── CONFIGURATION
    ├── Policies
    ├── Sign In / Providers ← CLICK HERE! ⬅️
    ├── OAuth Server
    ├── Sessions
    ├── Rate Limits
    ├── Multi-Factor
    ├── URL Configuration ← Or try here
    ├── Attack Protection
    ├── Auth Hooks
    ├── Audit Logs
    └── Performance
```

## What You're Looking For

Once you click "Sign In / Providers" → "Email", you should see:

- ✅ **Enable email confirmations** (toggle switch) ← **Turn this OFF**
- Email templates section
- SMTP settings (if configured)
- Other email-related options

## Quick Alternative: Check URL Configuration

If "Sign In / Providers" doesn't show email settings:

1. Click **"URL Configuration"** instead
2. Look for email confirmation settings there
3. Some Supabase versions have it in this section

## Still Can't Find It?

The setting might be in a different location depending on your Supabase version. Try:

1. **Click the gear icon** (⚙️) in the far-left sidebar (general project Settings)
2. Look for **"Auth"** or **"Authentication"** section
3. Check for **"Email"** or **"Email Auth"** subsection

Let me know what you see when you click "Sign In / Providers"!


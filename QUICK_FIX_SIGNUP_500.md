# 🚀 QUICK FIX: Signup 500 Error

## Immediate Fix (2 minutes)

### Option A: Configure Email Settings (Fastest)

1. **Open Supabase Dashboard**
   - Go to: https://supabase.com/dashboard
   - Select your project: `klkrexlivtmluosdztxt`

2. **Go to Email Provider Settings**
   - Navigate to: **Authentication** → **Sign In / Providers** → **Email**
   - You'll see two important toggles:

3. **Configure Settings**
   - ✅ **Enable email signups** ← **MUST BE ON** (allows signup)
   - ❌ **Enable email confirmations** ← **Turn OFF** (skip email verification)
   - Click **Save**

4. **Test Signup**
   - Try signing up again
   - Should work immediately! ✅

**Important:** Make sure "Enable email signups" is ON, otherwise you'll get "Email signups are disabled" error!

### Option B: Configure SMTP (For Production)

1. **Go to SMTP Settings**
   - **Settings** → **Auth** → **SMTP Settings**

2. **Configure Gmail (Example)**
   ```
   Host: smtp.gmail.com
   Port: 587
   Username: your-email@gmail.com
   Password: [App-specific password]
   Sender email: your-email@gmail.com
   Sender name: AgriTrace
   ```

3. **Get Gmail App Password**
   - Google Account → Security → 2-Step Verification → App passwords
   - Generate password for "Mail"

## Also Run Database Fix

Run `fix_signup_500_error.sql` in Supabase SQL Editor to ensure profile creation works.

## That's It!

After disabling email confirmation, signup should work immediately. Users will be created without needing to verify email.

---

**For production:** Re-enable email confirmation and configure proper SMTP settings.


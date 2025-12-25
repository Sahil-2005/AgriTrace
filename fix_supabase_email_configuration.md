# Fix Supabase Email Configuration Error

## Error Message
```
Error sending confirmation email
POST https://klkrexlivtmluosdztxt.supabase.co/auth/v1/signup?redirect_to=http%3A%2F%2Flocalhost%3A8080%2F 500 (Internal Server Error)
```

## Root Causes
The 500 error when sending confirmation emails can be caused by:

1. **Email service not configured** - No SMTP settings in Supabase
2. **Redirect URL not whitelisted** - `http://localhost:8080/` not in allowed URLs
3. **Email rate limits exceeded** - Free tier has email sending limits
4. **Database trigger failing** - Profile creation trigger causing email send to fail

## Solution Options

### Option 1: Disable Email Confirmation (Recommended for Development)

1. Go to **Supabase Dashboard** → **Authentication** → **Settings**
2. Scroll down to **Email Auth** section
3. **Disable "Enable email confirmations"** toggle
4. Save changes

**Pros:** 
- Immediate fix, no email configuration needed
- Good for development/testing

**Cons:**
- Users can sign up without email verification
- Not recommended for production

### Option 2: Configure SMTP Settings (Required for Production)

1. Go to **Supabase Dashboard** → **Settings** → **Auth**
2. Scroll to **SMTP Settings**
3. Configure your SMTP provider:
   - **Host:** Your SMTP server (e.g., `smtp.gmail.com`)
   - **Port:** Usually `587` for TLS
   - **Username:** Your email address
   - **Password:** Your email password or app-specific password
   - **Sender email:** Email address to send from
   - **Sender name:** Display name (e.g., "AgriTrace")

**Popular SMTP Providers:**
- **Gmail:** `smtp.gmail.com:587` (requires app password)
- **SendGrid:** Use SendGrid SMTP settings
- **Mailgun:** Use Mailgun SMTP settings
- **AWS SES:** Use AWS SES SMTP settings

### Option 3: Whitelist Redirect URL

1. Go to **Supabase Dashboard** → **Authentication** → **URL Configuration**
2. Under **Redirect URLs**, add:
   - `http://localhost:8080`
   - `http://localhost:8080/`
   - `http://localhost:8080/**` (wildcard)
3. Save changes

### Option 4: Run Database Fix First

Before configuring email, ensure the database trigger is set up correctly:

1. Run `fix_signup_500_error.sql` in Supabase SQL Editor
2. This ensures profile creation doesn't fail and cause email errors

## Step-by-Step Fix (Quick Development Setup)

### Step 1: Disable Email Confirmation
1. Open Supabase Dashboard
2. Navigate to **Authentication** → **Settings**
3. Find **"Enable email confirmations"** toggle
4. **Turn it OFF**
5. Click **Save**

### Step 2: Run Database Fix
1. Open **SQL Editor** in Supabase Dashboard
2. Copy contents of `fix_signup_500_error.sql`
3. Run the SQL script
4. Verify success message appears

### Step 3: Whitelist Redirect URL
1. Still in **Authentication** → **Settings**
2. Scroll to **URL Configuration**
3. Under **Redirect URLs**, add:
   ```
   http://localhost:8080
   http://localhost:8080/**
   ```
4. Click **Save**

### Step 4: Test Signup
1. Try signing up with a new email
2. User should be created immediately without email confirmation
3. Check browser console for any errors

## Production Setup

For production, you **MUST**:

1. **Enable email confirmations** (turn it back ON)
2. **Configure SMTP settings** with a production email service
3. **Whitelist your production domain** in redirect URLs
4. **Test email delivery** before going live

## Troubleshooting

### Still Getting 500 Error?

1. **Check Supabase Logs:**
   - Dashboard → Logs → Postgres Logs
   - Look for trigger errors or constraint violations

2. **Verify Database Trigger:**
   ```sql
   SELECT * FROM pg_trigger WHERE tgname = 'on_auth_user_created';
   ```

3. **Check Profiles Table:**
   ```sql
   SELECT * FROM profiles ORDER BY created_at DESC LIMIT 5;
   ```

4. **Test Email Configuration:**
   - Dashboard → Authentication → Users
   - Try manually sending a password reset email
   - If that fails, SMTP is not configured correctly

### Email Not Sending?

1. Check SMTP credentials are correct
2. Verify sender email is verified (for some providers)
3. Check spam folder
4. Review email provider's rate limits
5. Check Supabase email logs in Dashboard → Logs

## Quick Test

After applying fixes, test with this:

```javascript
// In browser console
const { data, error } = await supabase.auth.signUp({
  email: 'test@example.com',
  password: 'testpassword123'
});
console.log('Signup result:', { data, error });
```

If `error` is null, the fix worked!


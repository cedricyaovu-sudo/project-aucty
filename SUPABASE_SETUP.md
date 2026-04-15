# KINETIC — Supabase Backend Setup Guide

This guide walks you through connecting your KINETIC auction app to a real Supabase backend. When finished, your app will have real user accounts, persistent bids, live auction updates, messaging, image uploads, and more.

**Total time: ~30-45 minutes**

---

## Part 1 — Create Your Supabase Project

### 1.1 Sign up for Supabase

1. Go to https://supabase.com
2. Click **Start your project** (top right)
3. Sign up with GitHub, Google, or email
4. You'll be taken to your dashboard

### 1.2 Create a new project

1. Click **New Project**
2. Select your organization (or create one — free tier works)
3. Fill in:
   - **Name:** `kinetic-auctions` (or whatever you prefer)
   - **Database Password:** Generate a strong one and **save it somewhere safe** (you'll rarely need it, but you can't recover it)
   - **Region:** Pick the one closest to your users (e.g., `us-east-1` for East Coast USA)
   - **Pricing Plan:** Free tier is fine to start (500MB DB, 2GB bandwidth, 50k monthly active users)
4. Click **Create new project**
5. Wait 1-2 minutes while Supabase provisions your database

### 1.3 Grab your API credentials

1. In your project dashboard, click the **gear icon** (Settings) in the left sidebar
2. Click **API**
3. Copy two values (you'll paste them into the app later):
   - **Project URL** — looks like `https://xxxxxxxxxxxx.supabase.co`
   - **anon public** key — a long string starting with `eyJ...`

⚠️ **Never share the `service_role` key** — that's the admin key. Only the `anon` key goes in your app.

---

## Part 2 — Set Up the Database Schema

### 2.1 Open the SQL Editor

1. In your Supabase dashboard, click **SQL Editor** in the left sidebar
2. Click **+ New query**

### 2.2 Run the schema

1. Open the file `schema.sql` in this folder
2. Copy the entire contents
3. Paste into the Supabase SQL Editor
4. Click **Run** (or press Cmd/Ctrl + Enter)

You should see "Success. No rows returned." This creates:
- `profiles` — user info (linked to auth.users)
- `auctions` — listings
- `bids` — bid history
- `watchlist` — saved items
- `messages` — DMs between users
- `notifications` — in-app alerts
- `transactions` — payment/bid records
- `reviews` — creator ratings
- `payment_methods` — saved cards (tokenized)

### 2.3 Verify tables were created

Click **Table Editor** in the sidebar. You should see all 9 tables listed.

---

## Part 3 — Enable Authentication

### 3.1 Configure auth providers

1. Click **Authentication** in the left sidebar
2. Click **Providers**
3. **Email** is enabled by default — good.
4. (Optional) Enable **Google**, **Apple**, or other providers:
   - Follow Supabase's per-provider setup: https://supabase.com/docs/guides/auth/social-login
   - Get OAuth client IDs from Google Cloud Console / Apple Developer, paste into Supabase

### 3.2 Configure email templates

1. Click **Authentication** → **Email Templates**
2. Customize the **Confirm signup** and **Reset password** templates with your branding
3. Save

### 3.3 Set up redirect URLs

1. Click **Authentication** → **URL Configuration**
2. Add your app URL(s) under **Redirect URLs**:
   - For local testing: `http://localhost:*`
   - For production: `https://yourdomain.com`

---

## Part 4 — Set Up Storage for Images

### 4.1 Create buckets

1. Click **Storage** in the left sidebar
2. Click **New bucket**
3. Create three buckets:

   **Bucket 1: `auction-images`**
   - Public bucket: ✅ Yes
   - File size limit: 10 MB
   - Allowed MIME types: `image/*`

   **Bucket 2: `avatars`**
   - Public bucket: ✅ Yes
   - File size limit: 2 MB
   - Allowed MIME types: `image/*`

   **Bucket 3: `banners`**
   - Public bucket: ✅ Yes
   - File size limit: 5 MB
   - Allowed MIME types: `image/*`

### 4.2 Set storage policies

For each bucket, click it, then click **Policies** tab, then **New Policy**. Use the "Give users access to a folder only to own folder" template or paste these:

```sql
-- Anyone can view
CREATE POLICY "Public can view" ON storage.objects FOR SELECT USING (bucket_id = 'auction-images');

-- Authenticated users can upload
CREATE POLICY "Auth users can upload" ON storage.objects FOR INSERT TO authenticated 
  WITH CHECK (bucket_id = 'auction-images' AND (storage.foldername(name))[1] = auth.uid()::text);

-- Users can delete their own
CREATE POLICY "Users can delete own" ON storage.objects FOR DELETE TO authenticated 
  USING (bucket_id = 'auction-images' AND (storage.foldername(name))[1] = auth.uid()::text);
```

Repeat for `avatars` and `banners` buckets (just change bucket_id).

---

## Part 5 — Enable Realtime

Realtime lets the app push live bid updates, chat messages, and notifications instantly.

1. Click **Database** → **Replication** in the sidebar
2. Find the `supabase_realtime` publication
3. Click **0 tables** and toggle ON these tables:
   - `bids` (so live bids appear for everyone watching)
   - `messages` (for live chat)
   - `notifications` (for live alerts)
   - `auctions` (for live viewer counts, status changes)
4. Click **Save**

---

## Part 6 — Connect the App

### Option A: Via the Settings UI (easiest)

1. Open your KINETIC app in a browser
2. Tap the hamburger menu (☰) top left
3. Tap **Connect Backend**
4. Paste your **Project URL** and **anon key**
5. Tap **Test Connection**
6. Tap **Save & Restart**

The app now runs against your live Supabase backend.

### Option B: Directly in the code

1. Open `/sessions/bold-zen-ramanujan/mnt/outputs/kinetic-auctions/index.html`
2. Find the config block at the top of the `<script>` tag:

```javascript
const SUPABASE_URL = 'YOUR_SUPABASE_URL_HERE';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY_HERE';
const USE_SUPABASE = false;
```

3. Replace with your credentials and set `USE_SUPABASE = true`:

```javascript
const SUPABASE_URL = 'https://xxxxxxxxxxxx.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIs...';
const USE_SUPABASE = true;
```

4. Save and refresh the app in the browser

---

## Part 7 — Test the Integration

Go through these flows in order to make sure everything works:

### 7.1 Sign up
- Create a new account with a real email
- Check your inbox for the confirmation email, click the link
- Sign in with your new account
- Verify your profile was created: in Supabase, go to Table Editor → `profiles` — your row should be there

### 7.2 List an item
- Tap the **+ floating button** on Discovery
- Fill out the form and upload an image
- Submit — verify the item appears in Discovery
- Check Supabase Table Editor → `auctions` — your item should be there
- Check Storage → `auction-images` — your uploaded image should be there

### 7.3 Place a bid
- Open another browser (incognito) or device, sign up as a second user
- Find the item you listed, tap **Bid Now**, place a bid
- Switch back to the first browser — you should see the new bid appear in real-time (via Realtime subscription)
- Check Supabase Table Editor → `bids` — the bid should be there

### 7.4 Watchlist
- Star an item on an auction card
- Verify it appears in the Bids tab under Watchlist
- Check Supabase Table Editor → `watchlist` — the row should exist

### 7.5 Messages
- From a creator's profile, tap **Message Creator**
- Send a message
- On the other account, check Messages tab — the message should arrive in real-time

### 7.6 Notifications
- Get outbid on an auction
- The other user should receive an "outbid" notification via Realtime

---

## Part 8 — Deploy to Production

### 8.1 Host your app

The app is a single `index.html` file, so any static host works:
- **Vercel:** `vercel deploy` (free, zero-config)
- **Netlify:** Drag-and-drop upload
- **GitHub Pages:** Push to a repo, enable Pages in settings
- **Cloudflare Pages:** Also free

### 8.2 Update Supabase redirect URLs

1. In Supabase: Authentication → URL Configuration
2. Add your production URL (e.g., `https://kinetic.yourdomain.com`)

### 8.3 Upgrade Supabase plan (when you grow)

Free tier limits:
- 500 MB database
- 2 GB bandwidth/month
- 50,000 monthly active users
- 1 GB file storage

When you approach these, upgrade to Pro ($25/month) — much higher limits and daily backups.

---

## Part 9 — Add Payments (Stripe)

The app has payment UI but no real charging. To add real payments:

1. Sign up at https://stripe.com
2. Grab your **publishable key** and **secret key** from the Stripe dashboard
3. Create a Supabase Edge Function to handle Stripe checkout sessions:
   ```bash
   supabase functions new create-checkout
   ```
4. In the function, use Stripe's Node SDK to create a checkout session
5. Call that function from the app when a user places a winning bid
6. Use Stripe webhooks to confirm payment and mark transactions as paid

Full guide: https://supabase.com/docs/guides/functions/examples/stripe-webhooks

---

## Part 10 — Security Checklist

Before going public, verify:

- ✅ **RLS is enabled** on all tables (the schema.sql does this automatically)
- ✅ **Only `anon` key in frontend code** — never the `service_role` key
- ✅ **Email confirmation is required** for sign-up (Supabase default)
- ✅ **Rate limiting** on auth (configurable in Supabase)
- ✅ **Storage policies** prevent users from overwriting others' files
- ✅ **Strong password requirements** (Authentication → Providers → Email)
- ✅ **2FA enabled** on your Supabase account
- ✅ **Production `anon` key** rotated if the original one was ever committed to public git

---

## Troubleshooting

**"Failed to fetch" or CORS errors**
- Make sure your app's URL is in Supabase → Authentication → URL Configuration → Site URL / Redirect URLs
- Check browser console for the exact error

**Bids don't update live**
- Verify Realtime is enabled for the `bids` table (Part 5)
- Check the browser console — should see "subscribed to channel: bids"

**Sign-up email never arrives**
- Check spam folder
- In Supabase → Authentication → Email → verify SMTP settings (default uses Supabase's sender, which can be slow)
- For production, configure custom SMTP (SendGrid, Resend, Postmark)

**"Row-level security policy violation"**
- A table's RLS policy is blocking the query
- Go to Authentication → Policies, review the rule, make sure `auth.uid()` matches what you're inserting

**Images don't upload**
- Check bucket is set to `public`
- Verify storage policy allows authenticated uploads
- Check file size is under the bucket's limit

---

## What the data service layer looks like

Your app's code has a `dataService` object that swaps between demo data and Supabase based on the `USE_SUPABASE` flag:

```javascript
const dataService = {
  async getAuctions(filters = {}) {
    if (!USE_SUPABASE) return DEMO_AUCTIONS;
    let query = supabase.from('auctions').select('*, creator:profiles(*)').eq('status', 'active');
    if (filters.category) query = query.eq('category', filters.category);
    const { data, error } = await query.order('created_at', { ascending: false });
    if (error) throw error;
    return data;
  },

  async placeBid(auctionId, amount) {
    if (!USE_SUPABASE) return simulateBid(auctionId, amount);
    const { data: { user } } = await supabase.auth.getUser();
    return await supabase.from('bids').insert({
      auction_id: auctionId,
      bidder_id: user.id,
      amount,
    });
  },

  subscribeToBids(auctionId, callback) {
    if (!USE_SUPABASE) return null;
    return supabase
      .channel(`bids:${auctionId}`)
      .on('postgres_changes', {
        event: 'INSERT',
        schema: 'public',
        table: 'bids',
        filter: `auction_id=eq.${auctionId}`,
      }, callback)
      .subscribe();
  },
  // ... other methods
};
```

All the integration points are already built — you're just flipping a switch.

---

## Next Steps

Once the backend is live, consider:

1. **Analytics** — Add PostHog or Mixpanel for user behavior tracking
2. **Email notifications** — Use Supabase Edge Functions + Resend for bid outbid/won emails
3. **Mobile app** — Wrap the React code in Capacitor or React Native for iOS/App Store
4. **Admin dashboard** — Build a separate interface (or use Retool) to moderate listings and users
5. **Fraud detection** — Stripe Radar handles most payment fraud out of the box
6. **Customer support** — Intercom or Crisp for live chat

---

## Support

- Supabase docs: https://supabase.com/docs
- Supabase Discord: https://discord.supabase.com
- KINETIC app code: see `index.html` — all integration points are marked with `// SUPABASE:` comments

Good luck shipping KINETIC!

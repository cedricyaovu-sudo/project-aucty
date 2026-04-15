# KINETIC — Creator Auction Platform

A publish-ready mobile auction app for content creators. Runs standalone in demo mode or connects to Supabase for a full production backend.

## Files in this folder

- **`index.html`** — the full app (React 18 + Supabase-ready). Open in any browser to run.
- **`SUPABASE_SETUP.md`** — step-by-step guide to connecting a real backend (30-45 min).
- **`schema.sql`** — database schema to paste into the Supabase SQL editor.
- **`README.md`** — this file.

## Quick start (demo mode)

Just open `index.html` in a browser. Everything works — auctions, bids, watchlist, messages, notifications — it's all live with demo data.

## Production setup

1. Read `SUPABASE_SETUP.md`
2. Run `schema.sql` in the Supabase SQL Editor
3. Paste your Supabase URL + anon key into the app (via Settings → Connect Backend, or directly in `index.html`)
4. Deploy `index.html` to any static host (Vercel, Netlify, Cloudflare Pages)

## Feature list

### Auctions
- Live countdown timers
- Real-time bid updates
- Auto-bidding with max cap
- Multi-image carousels
- Price history charts
- Bid history with timestamps
- Community chat per auction
- Emoji reactions
- "Hot", "Trending", "Live Now" badges

### Discovery
- Category filters (Art, Fashion, Tech, Music, Collectibles, Gaming, Photography)
- Full-text search across items and creators
- Creator spotlights
- Trending drops
- Recently viewed
- Advanced filter drawer (price range, sort, verified only)

### User accounts
- Sign up / sign in (email, Google, Apple)
- 3-step onboarding
- Profile with bio, banner, avatar
- Creator verification badges (3 levels)
- Star ratings and reviews
- Follower/following social graph

### Bids tab
- Active bids with status (winning, outbid)
- Watchlist with live updates
- Won / Lost history
- Spending summary (monthly totals)
- Auto-bid management
- Notifications center

### Selling
- List new item flow (+ FAB)
- Upload multiple images
- Set starting price, reserve, duration
- Seller dashboard (revenue, sales stats)
- Order management
- Withdraw funds

### Payments
- Saved payment methods
- Add / remove cards
- Full checkout flow (shipping, payment, review)
- Order tracking (paid → shipped → delivered)
- Transaction history with CSV export

### Messaging
- Direct messages between users
- Conversation list with unread badges
- Typing indicators
- Read receipts
- Message creator button on profiles

### Polish
- Light + dark mode toggle
- Smooth animations throughout
- Loading skeletons
- Empty states with CTAs
- Toast notifications
- Haptic-feel button presses
- Mobile-first (360-420px phone frame)
- Accessibility-minded contrast and labels

## Tech stack

- **Frontend:** React 18, Babel standalone (all via CDN)
- **Backend (optional):** Supabase (Postgres + Auth + Realtime + Storage)
- **Payments (to add):** Stripe (see `SUPABASE_SETUP.md` Part 9)
- **Hosting:** Any static host

## License

Yours to use as you see fit.

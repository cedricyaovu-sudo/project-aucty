-- ============================================================
-- KINETIC Auction Platform — Supabase Schema
-- Run this entire file in Supabase SQL Editor
-- ============================================================

-- ============================================================
-- EXTENSIONS
-- ============================================================
create extension if not exists "uuid-ossp";
create extension if not exists "pg_trgm"; -- for full-text search

-- ============================================================
-- PROFILES (extends auth.users)
-- ============================================================
create table if not exists profiles (
  id uuid references auth.users(id) on delete cascade primary key,
  username text unique not null,
  display_name text,
  bio text,
  avatar_url text,
  banner_url text,
  website text,
  is_creator boolean default false,
  is_verified boolean default false,
  verification_level text check (verification_level in ('verified', 'premium', 'top_seller')) default null,
  follower_count int default 0,
  following_count int default 0,
  total_sales_cents bigint default 0,
  rating numeric(3,2) default 5.00,
  review_count int default 0,
  account_balance_cents bigint default 0,
  preferences jsonb default '{}'::jsonb,
  onboarded boolean default false,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Auto-create a profile on sign-up
create or replace function handle_new_user()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.profiles (id, username, display_name)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'username', split_part(new.email, '@', 1) || '_' || substring(new.id::text, 1, 6)),
    coalesce(new.raw_user_meta_data->>'display_name', split_part(new.email, '@', 1))
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- ============================================================
-- AUCTIONS
-- ============================================================
create table if not exists auctions (
  id uuid default uuid_generate_v4() primary key,
  creator_id uuid references profiles(id) on delete cascade not null,
  title text not null,
  description text,
  category text not null check (category in ('art', 'fashion', 'tech', 'music', 'collectibles', 'gaming', 'photography', 'other')),
  tags text[] default '{}',
  images text[] default '{}', -- array of storage URLs
  starting_price_cents bigint not null,
  reserve_price_cents bigint,
  current_bid_cents bigint,
  current_bidder_id uuid references profiles(id),
  bid_count int default 0,
  viewer_count int default 0,
  watch_count int default 0,
  starts_at timestamptz default now(),
  ends_at timestamptz not null,
  status text check (status in ('draft', 'scheduled', 'active', 'ended', 'sold', 'cancelled')) default 'active',
  winner_id uuid references profiles(id),
  final_price_cents bigint,
  featured boolean default false,
  hot boolean default false,
  physically_backed boolean default false,
  authentication_info jsonb,
  shipping_info jsonb,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_auctions_status on auctions(status);
create index if not exists idx_auctions_category on auctions(category);
create index if not exists idx_auctions_creator on auctions(creator_id);
create index if not exists idx_auctions_ends_at on auctions(ends_at);
create index if not exists idx_auctions_featured on auctions(featured) where featured = true;
create index if not exists idx_auctions_title_trgm on auctions using gin (title gin_trgm_ops);

-- ============================================================
-- BIDS
-- ============================================================
create table if not exists bids (
  id uuid default uuid_generate_v4() primary key,
  auction_id uuid references auctions(id) on delete cascade not null,
  bidder_id uuid references profiles(id) on delete cascade not null,
  amount_cents bigint not null,
  is_auto_bid boolean default false,
  max_auto_bid_cents bigint,
  status text check (status in ('active', 'outbid', 'winning', 'won', 'cancelled')) default 'active',
  created_at timestamptz default now()
);

create index if not exists idx_bids_auction on bids(auction_id);
create index if not exists idx_bids_bidder on bids(bidder_id);
create index if not exists idx_bids_created on bids(created_at desc);

-- When a new bid is placed, update the auction's current_bid and bid_count
create or replace function handle_new_bid()
returns trigger
language plpgsql
security definer
as $$
begin
  update auctions set
    current_bid_cents = new.amount_cents,
    current_bidder_id = new.bidder_id,
    bid_count = bid_count + 1,
    updated_at = now()
  where id = new.auction_id
    and (current_bid_cents is null or new.amount_cents > current_bid_cents);

  -- Mark previous bids as outbid
  update bids set status = 'outbid'
  where auction_id = new.auction_id
    and id != new.id
    and status = 'active';

  -- Create outbid notification for previous high bidder
  insert into notifications (user_id, type, title, message, data)
  select
    current_bidder_id,
    'outbid',
    'You''ve been outbid',
    'Someone placed a higher bid on an item you were winning',
    jsonb_build_object('auction_id', new.auction_id, 'new_bid_cents', new.amount_cents)
  from auctions
  where id = new.auction_id
    and current_bidder_id is not null
    and current_bidder_id != new.bidder_id;

  return new;
end;
$$;

drop trigger if exists on_new_bid on bids;
create trigger on_new_bid
  after insert on bids
  for each row execute function handle_new_bid();

-- ============================================================
-- WATCHLIST
-- ============================================================
create table if not exists watchlist (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references profiles(id) on delete cascade not null,
  auction_id uuid references auctions(id) on delete cascade not null,
  created_at timestamptz default now(),
  unique(user_id, auction_id)
);

create index if not exists idx_watchlist_user on watchlist(user_id);
create index if not exists idx_watchlist_auction on watchlist(auction_id);

-- ============================================================
-- MESSAGES (DMs between users)
-- ============================================================
create table if not exists conversations (
  id uuid default uuid_generate_v4() primary key,
  participant_1 uuid references profiles(id) on delete cascade not null,
  participant_2 uuid references profiles(id) on delete cascade not null,
  last_message_at timestamptz default now(),
  created_at timestamptz default now(),
  unique(participant_1, participant_2)
);

create table if not exists messages (
  id uuid default uuid_generate_v4() primary key,
  conversation_id uuid references conversations(id) on delete cascade not null,
  sender_id uuid references profiles(id) on delete cascade not null,
  content text not null,
  read_at timestamptz,
  created_at timestamptz default now()
);

create index if not exists idx_messages_conversation on messages(conversation_id, created_at desc);
create index if not exists idx_conversations_p1 on conversations(participant_1);
create index if not exists idx_conversations_p2 on conversations(participant_2);

-- ============================================================
-- NOTIFICATIONS
-- ============================================================
create table if not exists notifications (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references profiles(id) on delete cascade not null,
  type text check (type in ('outbid', 'ending_soon', 'won', 'new_drop', 'message', 'payment', 'system')) not null,
  title text not null,
  message text,
  data jsonb default '{}'::jsonb,
  read_at timestamptz,
  created_at timestamptz default now()
);

create index if not exists idx_notifications_user_unread on notifications(user_id) where read_at is null;
create index if not exists idx_notifications_user_created on notifications(user_id, created_at desc);

-- ============================================================
-- TRANSACTIONS
-- ============================================================
create table if not exists transactions (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references profiles(id) on delete cascade not null,
  auction_id uuid references auctions(id) on delete set null,
  type text check (type in ('deposit', 'withdrawal', 'purchase', 'sale', 'refund', 'bid_hold', 'bid_release')) not null,
  amount_cents bigint not null,
  currency text default 'USD',
  status text check (status in ('pending', 'processing', 'completed', 'failed', 'cancelled')) default 'pending',
  payment_method_id uuid,
  stripe_payment_intent text,
  stripe_charge_id text,
  description text,
  metadata jsonb default '{}'::jsonb,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_transactions_user on transactions(user_id, created_at desc);
create index if not exists idx_transactions_auction on transactions(auction_id);
create index if not exists idx_transactions_status on transactions(status);

-- ============================================================
-- REVIEWS
-- ============================================================
create table if not exists reviews (
  id uuid default uuid_generate_v4() primary key,
  auction_id uuid references auctions(id) on delete cascade not null,
  reviewer_id uuid references profiles(id) on delete cascade not null,
  creator_id uuid references profiles(id) on delete cascade not null,
  rating int check (rating between 1 and 5) not null,
  comment text,
  created_at timestamptz default now(),
  unique(auction_id, reviewer_id)
);

create index if not exists idx_reviews_creator on reviews(creator_id);

-- Update creator rating on new review
create or replace function update_creator_rating()
returns trigger
language plpgsql
security definer
as $$
begin
  update profiles set
    rating = (select avg(rating)::numeric(3,2) from reviews where creator_id = new.creator_id),
    review_count = (select count(*) from reviews where creator_id = new.creator_id)
  where id = new.creator_id;
  return new;
end;
$$;

drop trigger if exists on_new_review on reviews;
create trigger on_new_review
  after insert on reviews
  for each row execute function update_creator_rating();

-- ============================================================
-- PAYMENT METHODS (tokenized — never store raw card numbers)
-- ============================================================
create table if not exists payment_methods (
  id uuid default uuid_generate_v4() primary key,
  user_id uuid references profiles(id) on delete cascade not null,
  stripe_payment_method_id text not null,
  card_brand text,
  card_last4 text,
  card_exp_month int,
  card_exp_year int,
  is_default boolean default false,
  created_at timestamptz default now()
);

create index if not exists idx_payment_methods_user on payment_methods(user_id);

-- ============================================================
-- ORDERS (for items won/sold)
-- ============================================================
create table if not exists orders (
  id uuid default uuid_generate_v4() primary key,
  auction_id uuid references auctions(id) on delete set null not null,
  buyer_id uuid references profiles(id) on delete cascade not null,
  seller_id uuid references profiles(id) on delete cascade not null,
  amount_cents bigint not null,
  shipping_cents bigint default 0,
  tax_cents bigint default 0,
  total_cents bigint not null,
  shipping_address jsonb not null,
  tracking_number text,
  tracking_carrier text,
  status text check (status in ('pending_payment', 'paid', 'processing', 'shipped', 'delivered', 'cancelled', 'refunded')) default 'pending_payment',
  paid_at timestamptz,
  shipped_at timestamptz,
  delivered_at timestamptz,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create index if not exists idx_orders_buyer on orders(buyer_id);
create index if not exists idx_orders_seller on orders(seller_id);
create index if not exists idx_orders_status on orders(status);

-- ============================================================
-- FOLLOWS (social graph)
-- ============================================================
create table if not exists follows (
  id uuid default uuid_generate_v4() primary key,
  follower_id uuid references profiles(id) on delete cascade not null,
  following_id uuid references profiles(id) on delete cascade not null,
  created_at timestamptz default now(),
  unique(follower_id, following_id),
  check (follower_id != following_id)
);

create index if not exists idx_follows_follower on follows(follower_id);
create index if not exists idx_follows_following on follows(following_id);

-- Update follower counts
create or replace function handle_follow_change()
returns trigger
language plpgsql
security definer
as $$
begin
  if (tg_op = 'INSERT') then
    update profiles set following_count = following_count + 1 where id = new.follower_id;
    update profiles set follower_count = follower_count + 1 where id = new.following_id;
  elsif (tg_op = 'DELETE') then
    update profiles set following_count = greatest(following_count - 1, 0) where id = old.follower_id;
    update profiles set follower_count = greatest(follower_count - 1, 0) where id = old.following_id;
  end if;
  return coalesce(new, old);
end;
$$;

drop trigger if exists on_follow_change on follows;
create trigger on_follow_change
  after insert or delete on follows
  for each row execute function handle_follow_change();

-- ============================================================
-- CHAT MESSAGES (auction-specific community chat, not DMs)
-- ============================================================
create table if not exists auction_chat (
  id uuid default uuid_generate_v4() primary key,
  auction_id uuid references auctions(id) on delete cascade not null,
  user_id uuid references profiles(id) on delete cascade not null,
  content text not null,
  reactions jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);

create index if not exists idx_auction_chat_auction on auction_chat(auction_id, created_at desc);

-- ============================================================
-- REFERRALS
-- ============================================================
create table if not exists referrals (
  id uuid default uuid_generate_v4() primary key,
  referrer_id uuid references profiles(id) on delete cascade not null,
  referred_id uuid references profiles(id) on delete cascade,
  code text unique not null,
  reward_cents bigint default 5000, -- $50 bonus
  status text check (status in ('pending', 'completed', 'expired')) default 'pending',
  completed_at timestamptz,
  created_at timestamptz default now()
);

-- ============================================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================================

-- Enable RLS on every table
alter table profiles enable row level security;
alter table auctions enable row level security;
alter table bids enable row level security;
alter table watchlist enable row level security;
alter table conversations enable row level security;
alter table messages enable row level security;
alter table notifications enable row level security;
alter table transactions enable row level security;
alter table reviews enable row level security;
alter table payment_methods enable row level security;
alter table orders enable row level security;
alter table follows enable row level security;
alter table auction_chat enable row level security;
alter table referrals enable row level security;

-- PROFILES: anyone can view; users can update their own
create policy "Profiles are viewable by everyone" on profiles for select using (true);
create policy "Users can update own profile" on profiles for update using (auth.uid() = id);
create policy "Users can insert own profile" on profiles for insert with check (auth.uid() = id);

-- AUCTIONS: anyone can view active/ended; creators manage their own
create policy "Active auctions viewable by everyone" on auctions for select using (status in ('active', 'ended', 'sold', 'scheduled'));
create policy "Creators view own auctions" on auctions for select using (auth.uid() = creator_id);
create policy "Authenticated users can create auctions" on auctions for insert to authenticated with check (auth.uid() = creator_id);
create policy "Creators update own auctions" on auctions for update using (auth.uid() = creator_id);
create policy "Creators delete own draft auctions" on auctions for delete using (auth.uid() = creator_id and status = 'draft');

-- BIDS: anyone can view bids on visible auctions; authenticated users can create bids
create policy "Bids viewable by everyone" on bids for select using (true);
create policy "Authenticated users place bids" on bids for insert to authenticated with check (auth.uid() = bidder_id);

-- WATCHLIST: users only see/manage their own
create policy "Users view own watchlist" on watchlist for select using (auth.uid() = user_id);
create policy "Users add to own watchlist" on watchlist for insert to authenticated with check (auth.uid() = user_id);
create policy "Users remove from own watchlist" on watchlist for delete using (auth.uid() = user_id);

-- CONVERSATIONS & MESSAGES: only participants can view
create policy "Users view own conversations" on conversations for select
  using (auth.uid() = participant_1 or auth.uid() = participant_2);
create policy "Users create conversations" on conversations for insert to authenticated
  with check (auth.uid() = participant_1 or auth.uid() = participant_2);

create policy "Users view messages in own conversations" on messages for select using (
  exists (
    select 1 from conversations
    where id = messages.conversation_id
      and (participant_1 = auth.uid() or participant_2 = auth.uid())
  )
);
create policy "Users send messages in own conversations" on messages for insert to authenticated with check (
  auth.uid() = sender_id and exists (
    select 1 from conversations
    where id = messages.conversation_id
      and (participant_1 = auth.uid() or participant_2 = auth.uid())
  )
);

-- NOTIFICATIONS: only own
create policy "Users view own notifications" on notifications for select using (auth.uid() = user_id);
create policy "Users update own notifications" on notifications for update using (auth.uid() = user_id);

-- TRANSACTIONS: only own
create policy "Users view own transactions" on transactions for select using (auth.uid() = user_id);

-- REVIEWS: anyone can view; only buyers of an auction can review
create policy "Reviews viewable by everyone" on reviews for select using (true);
create policy "Buyers can review their purchases" on reviews for insert to authenticated with check (
  auth.uid() = reviewer_id and exists (
    select 1 from orders
    where auction_id = reviews.auction_id and buyer_id = auth.uid() and status in ('delivered', 'shipped')
  )
);

-- PAYMENT METHODS: only own
create policy "Users view own payment methods" on payment_methods for select using (auth.uid() = user_id);
create policy "Users manage own payment methods" on payment_methods for all using (auth.uid() = user_id);

-- ORDERS: only buyer or seller
create policy "Buyers and sellers view their orders" on orders for select
  using (auth.uid() = buyer_id or auth.uid() = seller_id);

-- FOLLOWS: everyone can view; users manage their own
create policy "Follows viewable by everyone" on follows for select using (true);
create policy "Users follow others" on follows for insert to authenticated with check (auth.uid() = follower_id);
create policy "Users unfollow" on follows for delete using (auth.uid() = follower_id);

-- AUCTION CHAT: everyone can view; authenticated users can post
create policy "Auction chat viewable by everyone" on auction_chat for select using (true);
create policy "Auth users post to auction chat" on auction_chat for insert to authenticated with check (auth.uid() = user_id);

-- REFERRALS: users see their own
create policy "Users view own referrals" on referrals for select using (auth.uid() = referrer_id or auth.uid() = referred_id);

-- ============================================================
-- HELPFUL VIEWS
-- ============================================================

-- Auctions with creator info joined in
create or replace view auctions_with_creator as
select
  a.*,
  p.username as creator_username,
  p.display_name as creator_display_name,
  p.avatar_url as creator_avatar_url,
  p.is_verified as creator_verified,
  p.verification_level as creator_verification_level,
  p.rating as creator_rating
from auctions a
left join profiles p on a.creator_id = p.id;

-- Active auctions ending soon
create or replace view auctions_ending_soon as
select *
from auctions_with_creator
where status = 'active' and ends_at > now()
order by ends_at asc
limit 20;

-- Trending auctions (most bids in last 24h)
create or replace view auctions_trending as
select
  a.*,
  coalesce(recent.recent_bid_count, 0) as recent_bid_count
from auctions_with_creator a
left join (
  select auction_id, count(*) as recent_bid_count
  from bids
  where created_at > now() - interval '24 hours'
  group by auction_id
) recent on a.id = recent.auction_id
where a.status = 'active'
order by recent.recent_bid_count desc nulls last, a.bid_count desc
limit 20;

-- ============================================================
-- REALTIME PUBLICATIONS
-- (already done via dashboard, but can be toggled here too)
-- ============================================================
-- Uncomment if you want to configure via SQL instead of dashboard:
-- alter publication supabase_realtime add table bids, messages, notifications, auctions, auction_chat;

-- ============================================================
-- Done! Check the Table Editor to verify all tables exist.
-- ============================================================

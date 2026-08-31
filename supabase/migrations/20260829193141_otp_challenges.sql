-- SMS-03 — ephemeral OTP authentication-challenge state ONLY.
--
-- This is deliberately the ONLY table this project's Supabase Postgres
-- database holds. It is NOT the application's user database — Firebase
-- Auth/Firestore remain the sole source of truth for users, vehicles,
-- bookings, locations, and payments. A row here represents one
-- send-otp/verify-otp challenge and nothing more: it is created, consumed
-- (or expires/exhausts its attempts), and is meaningless after that.
--
-- Row Level Security is enabled with NO policies, so only the
-- service-role key (used exclusively server-side by the send-otp/
-- verify-otp Edge Functions) can read or write this table at all — no
-- anon/authenticated Supabase client role has any access, matching this
-- project's "Supabase Auth is never introduced" constraint.
create table if not exists public.otp_challenges (
  id uuid primary key default gen_random_uuid(),
  phone text not null,
  otp_hash text not null,
  salt text not null,
  attempts integer not null default 0,
  max_attempts integer not null default 5,
  expires_at timestamptz not null,
  created_at timestamptz not null default now(),
  consumed_at timestamptz
);

-- Every real query this backend makes is scoped by phone, filtered to
-- not-yet-consumed rows, and/or windowed by created_at (resend cooldown,
-- hourly rate limit) — this composite index serves all three.
create index if not exists otp_challenges_phone_created_idx
  on public.otp_challenges (phone, created_at desc);

alter table public.otp_challenges enable row level security;

-- Atomic attempt increment — avoids a read-modify-write race between two
-- concurrent verify-otp requests for the same challenge (e.g. a
-- double-tap) undercounting attempts. SECURITY DEFINER so it runs with the
-- table owner's privileges regardless of caller (only ever called via the
-- service-role key from verify-otp in practice, since no other role has
-- table access at all).
create or replace function public.increment_otp_attempts(challenge_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  update public.otp_challenges set attempts = attempts + 1 where id = challenge_id;
$$;

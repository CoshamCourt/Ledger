-- =============================================================================
-- Resident Personal Allowance Ledger — Supabase schema & security setup
-- =============================================================================
-- Run this once in Supabase Dashboard → SQL Editor → New query → Run.
-- Safe to re-run: it drops and recreates the objects it creates.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. TABLES
-- ---------------------------------------------------------------------------

create extension if not exists pgcrypto;

create table if not exists residents (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  room text not null,
  family_name text,
  family_email text,
  archived boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists transactions (
  id uuid primary key default gen_random_uuid(),
  resident_id uuid not null references residents(id) on delete cascade,
  date date not null,
  reason text not null,
  type text not null check (type in ('in', 'out')),
  amount numeric(10,2) not null check (amount > 0),
  receipt text,
  staff text not null,
  created_at timestamptz not null default now()
);

-- Maps a logged-in Supabase Auth user to a role.
--   'admin'   — full access to the ledger
--   'manager' — full access, identical to admin; kept as a separate role only
--               so the ledger can show which kind of user made each entry
--   'staff'   — balance summary only
-- Rows here are added manually by you (see instructions), never by the app.
create table if not exists user_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  role text not null check (role in ('admin', 'manager', 'staff'))
);

-- ---------------------------------------------------------------------------
-- 2. STAFF-FACING VIEW
--    Only Room, Name, and current Balance for active (non-archived) residents.
--    No transaction detail, no receipts, no family contact info.
-- ---------------------------------------------------------------------------

drop view if exists balance_summary;

create view balance_summary as
select
  r.id,
  r.room,
  r.name,
  coalesce(
    sum(case when t.type = 'in' then t.amount else -t.amount end),
    0
  ) as balance
from residents r
left join transactions t on t.resident_id = r.id
where r.archived = false
group by r.id, r.room, r.name;

-- ---------------------------------------------------------------------------
-- 3. HELPER FUNCTION: does the logged-in user have full ledger access?
--    True for both 'admin' and 'manager' — the two roles have identical
--    permissions. Every RLS policy below is built on this function, so the
--    manager role is granted access in exactly one place.
-- ---------------------------------------------------------------------------

create or replace function is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from user_roles
    where user_id = auth.uid() and role in ('admin', 'manager')
  );
$$;

-- ---------------------------------------------------------------------------
-- 4. ROW LEVEL SECURITY
-- ---------------------------------------------------------------------------

alter table residents enable row level security;
alter table transactions enable row level security;
alter table user_roles enable row level security;

-- Base table grants (RLS policies below do the real gatekeeping per-row).
grant select, insert, update, delete on residents to authenticated;
grant select, insert, update, delete on transactions to authenticated;
grant select on user_roles to authenticated;
grant select on balance_summary to authenticated;

-- No access at all for anonymous (logged-out) requests.
revoke all on residents from anon;
revoke all on transactions from anon;
revoke all on user_roles from anon;
revoke all on balance_summary from anon;

drop policy if exists "Admin full access residents" on residents;
create policy "Admin full access residents"
  on residents for all
  using (is_admin())
  with check (is_admin());

drop policy if exists "Admin full access transactions" on transactions;
create policy "Admin full access transactions"
  on transactions for all
  using (is_admin())
  with check (is_admin());

drop policy if exists "Users can read own role" on user_roles;
create policy "Users can read own role"
  on user_roles for select
  using (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 5. ORG-WIDE SETTINGS
--    Single row (id = 1) holding details such as the BACS bank details used
--    in the top-up email template. Admin-only — Staff and logged-out users
--    get nothing, so these never need to live in the client-side code.
-- ---------------------------------------------------------------------------

create table if not exists org_settings (
  id integer primary key default 1,
  bacs_account_name text,
  bacs_bank_name text,
  bacs_sort_code text,
  bacs_account_number text
);

alter table org_settings enable row level security;

grant select, update on org_settings to authenticated;
revoke all on org_settings from anon;

drop policy if exists "Admin can read org_settings" on org_settings;
create policy "Admin can read org_settings"
  on org_settings for select
  using (is_admin());

drop policy if exists "Admin can update org_settings" on org_settings;
create policy "Admin can update org_settings"
  on org_settings for update
  using (is_admin())
  with check (is_admin());

-- ---------------------------------------------------------------------------
-- 6. AUDIT LOG
--    Append-only history of every change made through the app, so a mistaken
--    entry can be traced back to who made it and when.
--
--    Deliberately NOT linked to residents with a foreign key: if a resident is
--    ever removed, their audit history must survive. The resident's name is
--    stored as a plain text snapshot taken at the time of the action.
--
--    There is no update or delete grant on this table for anyone, so entries
--    cannot be altered or erased from inside the app once written.
-- ---------------------------------------------------------------------------

create table if not exists audit_log (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  user_email text not null,
  action text not null,
  resident_name text,
  details text
);

create index if not exists audit_log_created_at_idx on audit_log (created_at desc);

alter table audit_log enable row level security;

-- Insert and read only. No update/delete grant, on purpose.
grant select, insert on audit_log to authenticated;
revoke all on audit_log from anon;

drop policy if exists "Admin can read audit_log" on audit_log;
create policy "Admin can read audit_log"
  on audit_log for select
  using (is_admin());

drop policy if exists "Admin can append audit_log" on audit_log;
create policy "Admin can append audit_log"
  on audit_log for insert
  with check (is_admin());

-- =============================================================================
-- Done. Next step: create the two login accounts (Admin + Staff) in
-- Supabase Dashboard → Authentication → Users, then come back and run:
--
--   select id, email from auth.users;
--
-- to get their user IDs, and insert their roles, e.g.:
--
--   insert into user_roles (user_id, role) values
--     ('paste-admin-uuid-here', 'admin'),
--     ('paste-staff-uuid-here', 'staff');
-- =============================================================================

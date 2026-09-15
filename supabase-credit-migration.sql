-- ============================================================================
--  Bookstore Manager — credit, dues and returns
--  Run this ONCE in the Supabase SQL editor, AFTER supabase-schema.sql.
--
--  This one is additive. It does not drop anything and it does not touch a
--  single existing row, so it is safe to run on a database that already has
--  your books, sales and customers in it.
--
--  How the money is tracked
--  ------------------------
--  There is no "amount paid" column on a sale that gets edited over and over.
--  Instead every event is its own row:
--
--      a sale        = the customer owes you that much
--      a payment     = money came in
--      a return      = goods came back, so he owes that much less
--
--  What a customer owes today is the sum of his sales minus the sum of his
--  payments and returns. Nothing is ever overwritten, so two rows can never
--  fight over the same number — which matters when the till has been offline
--  and replays a queue of changes later.
-- ============================================================================

-- ------------------------------------------------------- sales.due_date ----
-- The date the bill was promised by. Null means it was settled at the till.
alter table sales add column if not exists due_date date;

-- -------------------------------------------------- customers.credit_days --
-- A regular you always give 30 days to. Null falls back to the store default.
alter table customers add column if not exists credit_days integer;

-- ------------------------------------------------------ store defaults -----
alter table settings add column if not exists default_credit_days integer default 14;
alter table settings add column if not exists reminder_lead_days  integer default 3;
alter table settings add column if not exists return_window_days  integer default 30;

-- ------------------------------------------------------------ payments -----
-- One row per payment received. Append-only: correcting a payment means
-- deleting that row and adding the right one, never editing a running total.
create table if not exists payments (
  id          uuid primary key default gen_random_uuid(),
  user_id     uuid not null default auth.uid(),
  customer_id uuid references customers(id) on delete cascade,
  sale_id     uuid references sales(id) on delete set null,   -- the bill it was taken against, for the history only
  amount      numeric not null default 0,
  paid_on     timestamptz not null default now(),
  method      text,
  note        text,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

-- ------------------------------------------------------------- returns -----
-- Goods coming back. items holds the lines, each with the condition it came
-- back in, so a damaged copy reduces the bill without going back on the shelf.
create table if not exists returns (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid(),
  sale_id      uuid references sales(id) on delete cascade,
  customer_id  uuid references customers(id) on delete set null,
  return_date  timestamptz not null default now(),
  items        jsonb not null default '[]'::jsonb,
  amount       numeric not null default 0,
  refund_mode  text not null default 'ledger',   -- 'ledger' = taken off what he owes / left as credit, 'cash' = money handed back
  note         text,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

-- --------------------------------------------------------------- index -----
create index if not exists payments_user_idx     on payments (user_id, paid_on desc);
create index if not exists payments_customer_idx on payments (customer_id);
create index if not exists returns_user_idx      on returns (user_id, return_date desc);
create index if not exists returns_sale_idx      on returns (sale_id);
create index if not exists sales_due_idx         on sales (user_id, due_date);

-- ----------------------------------------------------------- updated_at ----
drop trigger if exists payments_touch on payments;
create trigger payments_touch before update on payments for each row execute function touch_updated_at();

drop trigger if exists returns_touch on returns;
create trigger returns_touch before update on returns for each row execute function touch_updated_at();

-- ------------------------------------------------------------------ RLS ----
alter table payments enable row level security;
alter table returns  enable row level security;

drop policy if exists "own payments" on payments;
create policy "own payments" on payments for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists "own returns" on returns;
create policy "own returns" on returns for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============================================================================
--  Sanity check — run these two on their own and read the answers.
--
--    select count(*) from settings;
--      must be 1. More than 1 means the old schema is still live and saves
--      have been creating duplicate rows; stop and tell me before going on.
--
--    select column_name from information_schema.columns
--     where table_name = 'sales' and column_name = 'due_date';
--      must return one row. Nothing back means this file did not run.
-- ============================================================================

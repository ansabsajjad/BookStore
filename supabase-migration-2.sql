-- Reorder level per book
alter table books add column if not exists reorder_level integer default 3;

-- Suppliers
create table if not exists suppliers (
  id bigserial primary key,
  user_id uuid not null default auth.uid(),
  name text not null,
  contact text,
  phone text,
  notes text,
  created_at timestamptz default now()
);

-- Purchases / restocks
create table if not exists purchases (
  id bigserial primary key,
  user_id uuid not null default auth.uid(),
  supplier_id bigint references suppliers(id) on delete set null,
  book_id bigint references books(id) on delete set null,
  book_title text,
  qty integer not null,
  cost_each numeric not null,
  purchase_date timestamptz default now(),
  notes text
);

-- Customers
create table if not exists customers (
  id bigserial primary key,
  user_id uuid not null default auth.uid(),
  name text not null,
  phone text,
  email text,
  created_at timestamptz default now()
);

-- Link sales to a customer record
alter table sales add column if not exists customer_id bigint references customers(id) on delete set null;

-- Receipt logo (base64 data URL) stored per user
alter table settings add column if not exists logo text;

-- RLS for new tables
alter table suppliers enable row level security;
alter table purchases enable row level security;
alter table customers enable row level security;

create policy "own suppliers" on suppliers for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "own purchases" on purchases for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy "own customers" on customers for all
  using (user_id = auth.uid()) with check (user_id = auth.uid());

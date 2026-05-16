-- ============================================================
-- FABY — Migration Supabase complète
-- Exécuter dans : Supabase > SQL Editor
-- ============================================================

-- Extensions
create extension if not exists "uuid-ossp";

-- ── TABLE: users ──────────────────────────────────────────
create table public.users (
  id          uuid primary key default uuid_generate_v4(),
  auth_id     uuid unique references auth.users(id) on delete cascade,
  full_name   text not null,
  email       text unique not null,
  phone       text,
  role        text not null default 'client' check (role in ('client','pro','admin')),
  avatar_url  text,
  city        text,
  created_at  timestamptz default now()
);

-- ── TABLE: pros ───────────────────────────────────────────
create table public.pros (
  id            uuid primary key default uuid_generate_v4(),
  user_id       uuid not null references public.users(id) on delete cascade,
  bio           text,
  categories    text[] not null default '{}',
  cities        text[] not null default '{}',
  at_home       boolean default true,
  in_salon      boolean default false,
  address       text,
  rating        numeric(3,2) default 0,
  review_count  integer default 0,
  is_verified   boolean default false,
  is_active     boolean default true,
  created_at    timestamptz default now()
);

-- ── TABLE: services ───────────────────────────────────────
create table public.services (
  id            uuid primary key default uuid_generate_v4(),
  pro_id        uuid not null references public.pros(id) on delete cascade,
  name          text not null,
  category      text not null check (category in ('coiffure','esthetique','manucure','massage','maquillage')),
  description   text,
  duration_min  integer not null default 60,
  price         numeric(10,2) not null,
  is_active     boolean default true
);

-- ── TABLE: availability ────────────────────────────────────
create table public.availability (
  id          uuid primary key default uuid_generate_v4(),
  pro_id      uuid not null references public.pros(id) on delete cascade,
  day_of_week integer not null check (day_of_week between 0 and 6),
  start_time  time not null,
  end_time    time not null,
  unique(pro_id, day_of_week)
);

-- ── TABLE: bookings ───────────────────────────────────────
create table public.bookings (
  id                 uuid primary key default uuid_generate_v4(),
  client_id          uuid not null references public.users(id),
  pro_id             uuid not null references public.pros(id),
  service_id         uuid not null references public.services(id),
  booked_at          timestamptz not null,
  location_type      text not null check (location_type in ('home','salon')),
  address            text,
  total_price        numeric(10,2) not null,
  commission         numeric(10,2) not null,
  status             text default 'pending' check (status in ('pending','confirmed','in_progress','completed','cancelled','disputed')),
  payment_status     text default 'pending' check (payment_status in ('pending','paid','refunded')),
  stripe_payment_id  text,
  created_at         timestamptz default now()
);

-- ── TABLE: reviews ────────────────────────────────────────
create table public.reviews (
  id          uuid primary key default uuid_generate_v4(),
  booking_id  uuid unique not null references public.bookings(id),
  client_id   uuid not null references public.users(id),
  pro_id      uuid not null references public.pros(id),
  rating      integer not null check (rating between 1 and 5),
  comment     text,
  created_at  timestamptz default now()
);

-- ── TABLE: portfolios ─────────────────────────────────────
create table public.portfolios (
  id          uuid primary key default uuid_generate_v4(),
  pro_id      uuid not null references public.pros(id) on delete cascade,
  image_url   text not null,
  caption     text,
  category    text,
  created_at  timestamptz default now()
);

-- ── TABLE: notifications ──────────────────────────────────
create table public.notifications (
  id          uuid primary key default uuid_generate_v4(),
  user_id     uuid not null references public.users(id) on delete cascade,
  type        text not null,
  message     text not null,
  is_read     boolean default false,
  created_at  timestamptz default now()
);

-- ============================================================
-- TRIGGERS
-- ============================================================

-- Créer automatiquement un user dans public.users après signup
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer as $$
begin
  insert into public.users (auth_id, full_name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1)),
    new.email,
    coalesce(new.raw_user_meta_data->>'role', 'client')
  );
  return new;
end;
$$;

create or replace trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Recalculer la note moyenne d'une pro après un avis
create or replace function public.update_pro_rating()
returns trigger language plpgsql as $$
begin
  update public.pros
  set
    rating       = (select round(avg(rating)::numeric, 2) from public.reviews where pro_id = new.pro_id),
    review_count = (select count(*) from public.reviews where pro_id = new.pro_id)
  where id = new.pro_id;
  return new;
end;
$$;

create or replace trigger after_review_insert
  after insert on public.reviews
  for each row execute function public.update_pro_rating();

-- ============================================================
-- RLS (Row Level Security)
-- ============================================================

alter table public.users        enable row level security;
alter table public.pros         enable row level security;
alter table public.services     enable row level security;
alter table public.availability enable row level security;
alter table public.bookings     enable row level security;
alter table public.reviews      enable row level security;
alter table public.portfolios   enable row level security;
alter table public.notifications enable row level security;

-- Helper function
create or replace function auth_user_id()
returns uuid language sql stable as $$
  select id from public.users where auth_id = auth.uid()
$$;

-- users: lecture publique, modification perso uniquement
create policy "users_select_all"   on public.users for select using (true);
create policy "users_update_own"   on public.users for update using (id = auth_user_id());

-- pros: lecture publique, modification par le propriétaire
create policy "pros_select_all"    on public.pros for select using (true);
create policy "pros_insert_own"    on public.pros for insert with check (user_id = auth_user_id());
create policy "pros_update_own"    on public.pros for update using (user_id = auth_user_id());

-- services: lecture publique, CRUD par le pro
create policy "services_select_all"   on public.services for select using (true);
create policy "services_insert_own"   on public.services for insert
  with check (pro_id in (select id from public.pros where user_id = auth_user_id()));
create policy "services_update_own"   on public.services for update
  using (pro_id in (select id from public.pros where user_id = auth_user_id()));
create policy "services_delete_own"   on public.services for delete
  using (pro_id in (select id from public.pros where user_id = auth_user_id()));

-- availability: même logique que services
create policy "avail_select_all"  on public.availability for select using (true);
create policy "avail_insert_own"  on public.availability for insert
  with check (pro_id in (select id from public.pros where user_id = auth_user_id()));
create policy "avail_update_own"  on public.availability for update
  using (pro_id in (select id from public.pros where user_id = auth_user_id()));
create policy "avail_delete_own"  on public.availability for delete
  using (pro_id in (select id from public.pros where user_id = auth_user_id()));

-- bookings: client ou pro concerné uniquement
create policy "bookings_select"   on public.bookings for select
  using (client_id = auth_user_id() or
         pro_id in (select id from public.pros where user_id = auth_user_id()));
create policy "bookings_insert"   on public.bookings for insert
  with check (client_id = auth_user_id());
create policy "bookings_update"   on public.bookings for update
  using (client_id = auth_user_id() or
         pro_id in (select id from public.pros where user_id = auth_user_id()));

-- reviews: lecture publique, écriture par le client ayant booké
create policy "reviews_select_all" on public.reviews for select using (true);
create policy "reviews_insert_own" on public.reviews for insert
  with check (client_id = auth_user_id());

-- portfolios: lecture publique, CRUD par le pro
create policy "portfolio_select_all" on public.portfolios for select using (true);
create policy "portfolio_insert_own" on public.portfolios for insert
  with check (pro_id in (select id from public.pros where user_id = auth_user_id()));
create policy "portfolio_delete_own" on public.portfolios for delete
  using (pro_id in (select id from public.pros where user_id = auth_user_id()));

-- notifications: perso uniquement
create policy "notif_select_own"  on public.notifications for select using (user_id = auth_user_id());
create policy "notif_update_own"  on public.notifications for update using (user_id = auth_user_id());

-- ============================================================
-- STORAGE BUCKETS
-- ============================================================

insert into storage.buckets (id, name, public) values
  ('avatars',    'avatars',    true),
  ('portfolios', 'portfolios', true);

create policy "avatars_upload" on storage.objects for insert
  with check (bucket_id = 'avatars' and auth.uid() is not null);
create policy "avatars_public" on storage.objects for select
  using (bucket_id = 'avatars');

create policy "portfolios_upload" on storage.objects for insert
  with check (bucket_id = 'portfolios' and auth.uid() is not null);
create policy "portfolios_public" on storage.objects for select
  using (bucket_id = 'portfolios');

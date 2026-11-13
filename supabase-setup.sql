create table if not exists public.road_reports (
  id uuid primary key default gen_random_uuid(),
  name text not null check (char_length(btrim(name)) between 2 and 80),
  phone text not null check (phone ~ '^[6-9][0-9]{9}$'),
  place text not null check (char_length(btrim(place)) between 3 and 160),
  solution text check (solution is null or char_length(solution) <= 600),
  lat double precision not null check (lat between 7.9 and 12.95),
  lng double precision not null check (lng between 74.6 and 77.5),
  photo_url text not null check (photo_url ~ '^https://[^/]+/storage/v1/object/public/report-photos/.+\.jpg$'),
  created_at timestamptz not null default now()
);

alter table public.road_reports enable row level security;
revoke all on table public.road_reports from anon, authenticated;
grant insert on table public.road_reports to anon;

drop policy if exists "anonymous can submit road reports" on public.road_reports;
create policy "anonymous can submit road reports"
  on public.road_reports for insert to anon
  with check (true);

create or replace view public.road_reports_public
  with (security_barrier = true)
as
  select id, name, place, solution, lat, lng, photo_url, created_at
  from public.road_reports;

grant select on public.road_reports_public to anon, authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('report-photos', 'report-photos', true, 10485760, array['image/jpeg'])
on conflict (id) do update set public = true, file_size_limit = 10485760, allowed_mime_types = array['image/jpeg'];

drop policy if exists "public can read report photos" on storage.objects;
create policy "public can read report photos"
  on storage.objects for select to anon, authenticated
  using (bucket_id = 'report-photos');

drop policy if exists "anonymous can upload report photos" on storage.objects;
create policy "anonymous can upload report photos"
  on storage.objects for insert to anon
  with check (bucket_id = 'report-photos' and (storage.extension(name) = 'jpg' or storage.extension(name) = 'jpeg'));

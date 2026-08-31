-- Row-Level Security for the product catalogue.
--
-- Public reading: the catalogue is what the submission form and every price
-- label are rendered from, read with the anon key from an unauthenticated
-- client. There is nothing sensitive in a brand's own advertised product names.
--
-- Writing is closed twice, the same way the price tables are. Supabase's default
-- privileges hand anon and authenticated ALL privileges on every new table in
-- public, so a new table is anonymously writable until something says otherwise;
-- the grants come down to select. Then RLS is enabled with a select policy and
-- no insert, update, or delete policy at all - a policy that does not exist
-- cannot be mis-scoped later.
--
-- The catalogue is curated, never learned. It is written by migration, which
-- runs as the owner and bypasses RLS by design.

revoke all on table public.brand_fuel_products from anon, authenticated;
grant select on table public.brand_fuel_products to anon, authenticated;

alter table public.brand_fuel_products enable row level security;

create policy brand_fuel_products_public_read
  on public.brand_fuel_products
  for select
  to anon, authenticated
  using (true);

-- No INSERT, UPDATE, or DELETE policy. Adding one would be a deliberate act.

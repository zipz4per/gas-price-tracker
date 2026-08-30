-- Row-Level Security for the station registry.
--
-- Which stations exist is public information — it is the first screen of the
-- app, read with the anon key from an unauthenticated client, and it is data
-- OpenStreetMap already publishes to the world.
--
-- Writes have no policy AT ALL, matching localities and doe_regions. This is not
-- the same as writing a restrictive policy: with RLS enabled and no
-- INSERT/UPDATE/DELETE policy there is no rule that could be mis-written,
-- mis-scoped, or widened later by accident. The registry is written by the
-- import, which runs server-side holding the service-role key that bypasses RLS
-- by design.
--
-- That the import is server-side is not incidental. Overpass is a free,
-- volunteer-run service whose usage policy rules out per-page-view querying, so
-- there must be no path from a client request to a provider query. The client
-- reads this table and never contacts the provider.

alter table public.stations enable row level security;

create policy stations_public_read
  on public.stations
  for select
  to anon, authenticated
  using (true);

-- No INSERT, UPDATE, or DELETE policy is defined. Adding one later would be a
-- deliberate act, not an oversight.

-- The review view inherits the base table's RLS, so it needs no policy of its
-- own. It is declared security_invoker so it evaluates as the caller rather than
-- as its owner — without this a view would silently hand anon whatever its owner
-- can see, which is the classic way a table protected by RLS leaks through a
-- view sitting on top of it.
alter view public.stations_needing_brand_review set (security_invoker = true);

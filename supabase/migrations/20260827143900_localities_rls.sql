-- Row-Level Security for the locality registry.
--
-- Coverage configuration is public information — an app showing fuel prices has
-- no reason to hide which towns it covers, and reads happen with the anon key
-- from an unauthenticated client.
--
-- Writes have no policy AT ALL, deliberately. This is not the same as writing a
-- restrictive policy: with RLS enabled and no INSERT/UPDATE/DELETE policy, there
-- is no rule that could be mis-written, mis-scoped, or accidentally widened
-- later. The registry is maintained by migrations and by an operator holding the
-- service-role key, which bypasses RLS by design and never leaves their machine.

alter table public.doe_regions enable row level security;
alter table public.localities  enable row level security;

-- Reads: open to both anonymous and authenticated clients.
create policy doe_regions_public_read
  on public.doe_regions
  for select
  to anon, authenticated
  using (true);

create policy localities_public_read
  on public.localities
  for select
  to anon, authenticated
  using (true);

-- No INSERT, UPDATE, or DELETE policy is defined for either table.
-- Adding one later would be a deliberate act, not an oversight.

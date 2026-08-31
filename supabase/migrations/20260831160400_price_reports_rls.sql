-- Row-Level Security for the price report path.
--
-- Both tables are public reading. What a station charges and what the industry
-- announced are the app's whole point, read with the anon key from an
-- unauthenticated client.
--
-- Writing is another matter, and it is closed twice.
--
-- First the grants. Supabase's default privileges hand anon and authenticated
-- ALL privileges on every new table in public - insert, update, delete, and
-- truncate included - so a new table is writable by an anonymous client until
-- something says otherwise. RLS is usually what says otherwise, but relying on
-- it alone means one missing `enable row level security` is the difference
-- between a report path and an open table. The grants are revoked down to
-- select.
--
-- Then the policies. Select is allowed; there is no insert, update, or delete
-- policy at all. That is not the same as a restrictive policy: a policy that
-- does not exist cannot be mis-written, mis-scoped, or widened by accident
-- later. Adding one would be a deliberate act.
--
-- Reports still get written, because submit_price_report is SECURITY DEFINER
-- and runs as its owner. That is the only way in, which is what makes the
-- proximity check, the plausibility bounds, and the rate cap unavoidable rather
-- than advisory - a client cannot route around a check by inserting directly.

-- price_reports ---------------------------------------------------------------

revoke all on table public.price_reports from anon, authenticated;
grant select on table public.price_reports to anon, authenticated;

alter table public.price_reports enable row level security;

create policy price_reports_public_read
  on public.price_reports
  for select
  to anon, authenticated
  using (true);

-- No INSERT, UPDATE, or DELETE policy. Submission goes through
-- submit_price_report.

-- price_adjustments -----------------------------------------------------------

revoke all on table public.price_adjustments from anon, authenticated;
grant select on table public.price_adjustments to anon, authenticated;

alter table public.price_adjustments enable row level security;

create policy price_adjustments_public_read
  on public.price_adjustments
  for select
  to anon, authenticated
  using (true);

-- No write policy. Adjustments are written by add-price-adjustment-feed, which
-- runs server-side holding the service-role key that bypasses RLS by design -
-- the same arrangement as the DOE loader and the station import.

-- Row-Level Security for the DOE reference price tables.
--
-- Same shape as the locality registry: reads are public, and writes have NO
-- POLICY AT ALL rather than a restrictive one. With RLS enabled and no
-- INSERT/UPDATE/DELETE policy there is no rule that could later be mis-scoped
-- or widened by accident. Loading runs through load_doe_reference_prices() as
-- the service role, which bypasses RLS by design.
--
-- A note for whoever writes a client or a test against this: an anonymous
-- UPDATE or DELETE here returns HTTP 204, not an error. With no policy the rows
-- are simply invisible to those commands, so they affect zero rows rather than
-- raising. Judge write protection by rows-affected, never by status code.

alter table public.fuel_types           enable row level security;
alter table public.brands               enable row level security;
alter table public.doe_load_runs        enable row level security;
alter table public.doe_locality_reports enable row level security;
alter table public.doe_reference_prices enable row level security;

create policy fuel_types_public_read
  on public.fuel_types for select to anon, authenticated using (true);

create policy brands_public_read
  on public.brands for select to anon, authenticated using (true);

-- Only succeeded runs are readable. This is the atomicity boundary made real at
-- the row level: an in-progress run accumulating rows, or a failed one retained
-- for operator review, is not merely filtered out by convention — a consumer
-- cannot reach it even by querying the tables directly.
create policy doe_load_runs_public_read_succeeded
  on public.doe_load_runs for select to anon, authenticated
  using (status = 'succeeded');

create policy doe_locality_reports_public_read_succeeded
  on public.doe_locality_reports for select to anon, authenticated
  using (exists (
    select 1 from public.doe_load_runs r
    where r.id = doe_locality_reports.run_id and r.status = 'succeeded'
  ));

create policy doe_reference_prices_public_read_succeeded
  on public.doe_reference_prices for select to anon, authenticated
  using (exists (
    select 1
    from public.doe_locality_reports lr
    join public.doe_load_runs r on r.id = lr.run_id
    where lr.id = doe_reference_prices.locality_report_id
      and r.status = 'succeeded'
  ));

-- No INSERT, UPDATE, or DELETE policy on any of these tables.

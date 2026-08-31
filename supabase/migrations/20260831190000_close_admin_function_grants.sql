-- Close three functions that were meant for service_role and were open to anon.
--
-- `revoke all on function ... from public` does nothing on this project.
-- Supabase installs default privileges granting EXECUTE on new functions in
-- public to anon, authenticated and service_role EXPLICITLY:
--
--   pg_default_acl, objtype 'f', owner postgres
--     postgres=X/postgres anon=X/postgres authenticated=X/postgres service_role=X/postgres
--
-- so revoking from PUBLIC removes a grant that was never carrying the access,
-- and the explicit anon grant survives. The revoke reads as though it closed the
-- door and closes nothing.
--
-- The project's first function migration had this right -
-- 20260827150300_create_loader.sql revokes `from public, anon, authenticated`,
-- and load_doe_reference_prices is the only function in the schema anon cannot
-- execute. Later migrations narrowed the list to `public` alone, and nothing
-- caught it because until correct_price_adjustment every function's intended
-- audience included anon anyway.
--
-- correct_price_adjustment is SECURITY DEFINER and rewrites a recorded
-- adjustment. Derived prices are computed on read from the adjustments effective
-- since an observation, so one altered amount moves every station price
-- descending from it on the next query. Anyone holding the anon key - which ships
-- in the client - could do it.
--
-- THE PATTERN TO COPY, for any function not meant for the public:
--
--   revoke all on function public.f(...) from public, anon, authenticated;
--   grant execute on function public.f(...) to service_role;
--
-- Naming PUBLIC alone is not enough here, and looks like it is.

revoke all on function public.correct_price_adjustment(uuid, text, numeric, timestamptz)
  from public, anon, authenticated;
grant execute on function public.correct_price_adjustment(uuid, text, numeric, timestamptz)
  to service_role;

revoke all on function public.compare_feed_to_reference()
  from public, anon, authenticated;
grant execute on function public.compare_feed_to_reference()
  to service_role;

revoke all on function public.check_brand_name_normalization()
  from public, anon, authenticated;
grant execute on function public.check_brand_name_normalization()
  to service_role;

-- The views over compare_feed_to_reference() are security_invoker, so they
-- evaluate as the caller and now fail for anon exactly as the function does.
-- That is intended: feed health is operational, not public.

# Functions granted only to service_role are callable by anon

## What's broken

`correct_price_adjustment()` rewrites a recorded price adjustment's amount and
effective instant. It is `SECURITY DEFINER`, so it runs as its owner and
bypasses RLS, and its migration grants EXECUTE to `service_role` only. An
unauthenticated client can call it anyway.

Two other functions intended for `service_role` are equally open:
`compare_feed_to_reference()` and `check_brand_name_normalization()`.

## Impact

**Live on the hosted project.** Anyone holding the public anon key — which is
embedded in any client the app ships — can rewrite any price adjustment.

Derived prices are computed on read as the last observation plus every
adjustment effective since, so a single altered amount moves every station price
descending from it on the next query, with no job to run and nothing to notice.
There is no audit trail of the caller: `price_adjustment_revisions` records the
old value and the reason string the caller supplied, and the caller chooses that
string.

`compare_feed_to_reference()` is read-only and leaks nothing sensitive, but it
is not what its migration says it grants.

The functions genuinely meant for the public — `get_station_prices`,
`submit_price_report`, `stations_within_radius`, `get_station_fuel_options` —
are unaffected. They were always intended for `anon` and their own checks still
apply.

## Reproduction

```
  input                                          actual              expected
  ─────────────────────────────────────────────────────────────────────────────
  set local role anon;                           adjustment          permission
  select correct_price_adjustment(               amount              denied
    '<id>', 'anonymous caller', 99.00);          1.00 -> 99.00

  set local role anon;                           returns rows        permission
  select * from compare_feed_to_reference();                         denied

  select has_function_privilege(                 true                false
    'anon',
    'public.correct_price_adjustment(uuid,text,numeric,timestamptz)',
    'EXECUTE');
```

## Root cause

Every migration in this project follows the same pattern, taken from the first
one that needed it:

```sql
revoke all on function public.f(...) from public;
grant execute on function public.f(...) to service_role;
```

The comment above the first such block explains it: *"Postgres grants EXECUTE to
PUBLIC on every new function by default, so a grant to anon and authenticated
adds nothing unless that default is revoked first."* That is true of stock
Postgres and false here.

Supabase installs default privileges that grant EXECUTE on new functions in
`public` to `anon`, `authenticated` and `service_role` **explicitly**, not
through PUBLIC:

```
  pg_default_acl, objtype 'f', owner postgres
    postgres=X/postgres  anon=X/postgres  authenticated=X/postgres  service_role=X/postgres
```

So `revoke ... from public` removes a grant that was never carrying the access,
and the explicit `anon` grant survives untouched. The revoke reads as though it
closed the door and closes nothing.

This is a defect that looks correct on review. The pattern is deliberate, it is
commented with a true general fact about Postgres, and it does exactly what the
comment says — the comment is simply about a different Postgres than the one
this project runs on.

**The project knew this once.** Its first function migration,
`20260827150300_create_loader.sql`, closes the loader correctly:

```sql
revoke all on function public.load_doe_reference_prices(...) from public, anon, authenticated;
```

`load_doe_reference_prices` is the only function in the schema that `anon`
cannot execute. Every later migration dropped `anon, authenticated` from the
revoke list and kept only `public`, and nothing caught the narrowing because on
every function until `correct_price_adjustment` the intended audience included
`anon` anyway.

## Caused by

`cd46a25  Implement add-price-adjustment-feed`  (never worked)
    — add-price-adjustment-feed #21

The same ineffective revoke appears in earlier changes, but they only ever used
it on functions that were then granted to `anon` anyway, where it made no
difference. `correct_price_adjustment` is the first function whose intended
audience excluded `anon`, so it is the first place the mistaken pattern had a
consequence.

## Fixed by

`5036072  Close three admin functions that anon could call`

## What the fix changed

`correct_price_adjustment`, `compare_feed_to_reference` and
`check_brand_name_normalization` now revoke from `public, anon, authenticated`
rather than from `public` alone. `has_function_privilege('anon', ...)` is false
for all three, locally and on hosted, and a call as `anon` raises *permission
denied* leaving the adjustment's amount unchanged. The four functions meant for
clients — `get_station_prices`, `submit_price_report`, `stations_within_radius`,
`get_station_fuel_options` — are untouched and still work for `anon`.

Sixteen functions exist in `public`; twelve are anon-executable and all twelve
are intended.

**No scenario would have caught this**, and that is worth saying plainly rather
than claiming otherwise. The specs describe behaviour a caller observes, and
this defect is invisible from inside the function: `correct_price_adjustment`
does exactly what its requirement says, for a caller who should never have
reached it. What guards it instead is a check, not a scenario —
`docs/database-conventions.md` carries the query that lists every function
against every role, and the instruction to read it whole rather than filtered,
because the mistake looks identical to the intended state until you know which
is which.

## Does this need a change?

**No.** `price-adjustments` already requires the correction path to exist and
says nothing that the fix contradicts; the spec promised the right thing and the
grant did not deliver it. Fix and verify.

## Fix tasks

- [x] 1.1 Revoke EXECUTE from `anon` and `authenticated` explicitly on `correct_price_adjustment`, `compare_feed_to_reference`, and `check_brand_name_normalization`; verify `has_function_privilege('anon', ...)` is false for each
- [x] 1.2 Verify a call as `anon` to `correct_price_adjustment` raises permission denied and leaves the adjustment's amount unchanged
- [x] 1.3 Audit every `SECURITY DEFINER` and service_role-only function in the schema for the same pattern, and report any others found
- [x] 1.4 Verify the public read and submission paths still work for `anon` — `get_station_prices`, `submit_price_report`, `stations_within_radius`, `get_station_fuel_options`
- [x] 1.5 Record the correct grant pattern where the next person will meet it, so `revoke ... from public` is not copied again
- [x] 1.6 Push to hosted and re-verify there

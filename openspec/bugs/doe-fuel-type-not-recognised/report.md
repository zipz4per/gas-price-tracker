# Reference price lookup answers "no data" for fuel types it does not recognise

## What's broken

`get_doe_reference_prices()` returns an explicit `has_data = false` row for a fuel type it does not recognise, which is indistinguishable from the answer it gives when a locality genuinely has no data for a real fuel type. A caller asking for `'RON 95'` is told there is no data for Malvar; asking for `'RON_95'` returns seven priced rows. Nothing in the response says the question was not understood.

## Impact

Every consumer of the reference-price read path, which is currently the only way to get a DOE figure out of the database. The first client screen will call it, and a client that guesses the fuel-type spelling wrong gets a confident, well-formed, wrong answer rather than an error it could report or retry.

The failure is silent by construction. `has_data = false` is a legitimate documented state, so a monitor watching for errors sees nothing, and a developer reading the response sees a shape the spec explicitly blesses.

## Reproduction

Against the local stack, with Malvar reference data loaded:

```
  input                      actual                    expected
  ─────────────────────────────────────────────────────────────────────────
  ('Malvar','RON_95')        7 rows, has_data = t      7 rows              ✓
  ('Malvar','RON 95')        1 row,  has_data = f      recognised, or told
  ('Malvar','ron_95')        1 row,  has_data = f      recognised, or told
  ('Malvar','BANANA')        1 row,  has_data = f      told it is not a fuel
  ('Atlantis','RON_95')      0 rows                    0 rows              ✓
```

```sql
select 'RON 95' as input, has_data, count(*)
  from public.get_doe_reference_prices('Malvar','RON 95') group by has_data
union all
select 'RON_95', has_data, count(*)
  from public.get_doe_reference_prices('Malvar','RON_95') group by has_data;
```

The last two rows are the shape of the defect. An unknown *locality* returns
nothing, which a caller can tell apart from an answer. An unknown *fuel type*
returns an answer.

## Root cause

The function normalizes locality labels and exact-matches fuel-type codes, in the same body — `supabase/migrations/20260828100000_create_reference_price_read.sql`:

```
  L62–63    normalize_locality_label(l.display_name) = normalize_locality_label(p_locality)
  L78–79    normalize_locality_label(lr.doe_source_label) = normalize_locality_label(...)
  L102      p.fuel_type_code = p_fuel_type
  L133      p.fuel_type_code = p_fuel_type
```

`public.fuel_types` is a closed table of seven codes — `DIESEL`, `DIESEL_PLUS`, `KEROSENE`, `RON_91`, `RON_95`, `RON_97`, `RON_100`. The function never consults it, so an argument matching none of them falls through to the no-data branch rather than being rejected.

What let this survive review is the comment at L96–98, which justifies exactly that branch:

```
  -- Data exists for the locality but not for this fuel type. Same explicit
  -- no-data row: figures are never borrowed across fuel types, so a locality
  -- with Diesel but no Kerosene reports no Kerosene rather than Diesel's price.
```

The reasoning is correct for a real fuel type with no rows, and the branch it defends also swallows every unrecognised string. A careful justification for the right half of a branch is what made the wrong half invisible.

## Caused by

`1a3f1e9  Add DOE reference price retrieval function`  (never worked)

## Fixed by

_Pending._

## What the fix changed

_Pending._

## Does this need a change?

**Yes, added requirement.** The spec never says what a fuel type is at the boundary. `doe-reference-prices` normalizes locality labels and takes a position on fuel-type codes only by implication — the scenario under *Retrieval by locality and fuel type* is written "for Lipa City and fuel type RON 95", with a space, which is prose naming a fuel rather than a stated encoding.

The requirement worth adding is not about spelling. It is that **not understanding a request is a different state from having no data for it**, which the read path currently cannot express. `Absence of reference data is an explicit state` is the requirement that makes the wrong answer well-formed, and it needs a sibling.

This also reaches `add-station-registry` task 5.4, whose station read path returns a no-reference-data marker and would inherit the same ambiguity.

## Fix tasks

_None — tracked in the change, once it is filed._

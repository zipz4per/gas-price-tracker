-- Correct the granularity of DOE's "No LFRO" marker.
--
-- It is published INSIDE BRAND COLUMNS, not against the locality. Tanauan
-- City's RON 91 row reads:
--
--   PETRON  SHELL  CALTEX  TOTAL   UNIOIL   SEAOIL   FLYING V  PTT
--   74.50   76.40  77.50   79.90   No LFRO  No LFRO  71.50     No LFRO
--
-- Three brands have no station in Tanauan; five report real prices in the same
-- row. Treating any "No LFRO" as a locality-level fact — as the first cut of
-- this schema did — would have discarded those five prices and reported Tanauan
-- as having no stations at all. Tanauan is Malvar's proxy source, so Malvar
-- would have shown nothing, with no error raised.
--
-- "Unioil does not operate here" is also a more useful fact than "Unioil's
-- price was unavailable", so the two are kept distinct rather than collapsed.

create type public.doe_brand_presence as enum ('reported', 'no_outlet');

comment on type public.doe_brand_presence is
  'reported: the brand operates in this locality and published figures. '
  'no_outlet: DOE marked the brand "No LFRO" — it has no station in this locality.';

alter table public.doe_reference_prices
  add column brand_presence public.doe_brand_presence not null default 'reported';

comment on column public.doe_reference_prices.brand_presence is
  'Whether the brand operates in this locality. A no_outlet row carries no '
  'prices and is distinct from a brand whose price was merely unavailable '
  '(which produces no row at all).';

-- A row must either carry at least one price, or be an explicit no-outlet
-- marker with no prices. An all-NULL 'reported' row is meaningless: a brand
-- whose price was simply unavailable produces no row.
alter table public.doe_reference_prices
  drop constraint doe_reference_prices_not_entirely_empty;

alter table public.doe_reference_prices
  add constraint doe_reference_prices_presence_matches_prices check (
    (brand_presence = 'reported'
       and (min_price is not null or max_price is not null or common_price is not null))
    or
    (brand_presence = 'no_outlet'
       and min_price is null and max_price is null and common_price is null)
  );

-- A locality is 'no_outlet' only when EVERY brand in it is, which the loader
-- derives; there is no longer any single cell that decides it.
comment on column public.doe_locality_reports.status is
  'no_outlet only when every brand in the locality is marked no_outlet. '
  'Derived by the loader, never set from a single cell.';

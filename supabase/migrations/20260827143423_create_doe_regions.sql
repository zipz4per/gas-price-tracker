-- DOE region source configuration.
--
-- Records, per region, where its pump-price report lives and how the address of
-- the *current* report is determined. The two regions this project covers do
-- not address their reports the same way:
--
--   NCR   ncr-price-monitoring-08182026-pdf   <- embeds the reporting date,
--                                                so the address is constructible
--   IV-A  region-iv-a-calabarzon-22-pdf       <- opaque incrementing counter,
--                                                so the address must be discovered
--
-- The PRD assumed a single incrementing-suffix scheme. That is true of
-- CALABARZON and false of NCR. Recording the distinction as data means a later
-- ingestion process implements two strategies deliberately rather than
-- discovering the mismatch after building one, and keeps this project's most
-- fragile external dependency behind configuration instead of code.

create type public.doe_resolution_strategy as enum (
  -- Report address is derivable from the reporting date: substitute the date
  -- into url_pattern and fetch. No discovery step required.
  'date_derived',
  -- Report address contains an opaque identifier that cannot be predicted.
  -- The current report must be discovered from the index page before fetching.
  'discovery'
);

comment on type public.doe_resolution_strategy is
  'How the address of a DOE region''s current report is determined.';

create table public.doe_regions (
  code                text primary key,
  name                text not null,
  -- Page listing the region's reports. Always the starting point for
  -- 'discovery'; informational for 'date_derived'.
  index_url           text not null,
  -- Address template for a report. Placeholder tokens are substituted by the
  -- ingestion process: {MMDDYYYY} for date_derived, {N} for discovery.
  url_pattern         text not null,
  resolution_strategy public.doe_resolution_strategy not null,
  -- Why this region resolves the way it does, for whoever maintains the
  -- ingestion process later.
  strategy_notes      text,
  created_at          timestamptz not null default now(),

  constraint doe_regions_code_not_blank        check (length(btrim(code)) > 0),
  constraint doe_regions_name_not_blank        check (length(btrim(name)) > 0),
  constraint doe_regions_index_url_not_blank   check (length(btrim(index_url)) > 0),
  constraint doe_regions_url_pattern_not_blank check (length(btrim(url_pattern)) > 0),
  -- A pattern must carry the token its strategy substitutes, or the strategy
  -- cannot actually be executed against it.
  constraint doe_regions_pattern_matches_strategy check (
    (resolution_strategy = 'date_derived' and url_pattern like '%{MMDDYYYY}%')
    or
    (resolution_strategy = 'discovery'    and url_pattern like '%{N}%')
  )
);

comment on table public.doe_regions is
  'DOE regions whose pump-price reports supply reference data, and how each '
  'region''s current report address is resolved.';
comment on column public.doe_regions.url_pattern is
  'Report address template. {MMDDYYYY} is substituted for date_derived '
  'regions; {N} for discovery regions.';
comment on column public.doe_regions.resolution_strategy is
  'date_derived: address computed from the reporting date. '
  'discovery: address contains an opaque identifier and must be looked up.';

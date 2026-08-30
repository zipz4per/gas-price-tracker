-- The station registry: which fuel stations exist, where they are, and what
-- brand they carry.
--
-- Sourced from OpenStreetMap via Overpass, not from DOE and not from a typed
-- list. DOE publishes what a brand charges across a municipality; it never
-- names, counts, or locates a station, so nothing here may be inferred from it.
-- A brand's absence from the DOE report says nothing about whether stations
-- carrying it exist.
--
-- ODbL: rows here are extracted from OpenStreetMap and are a Derivative
-- Database. Our own data alongside them is a Collective Database and carries no
-- share-alike obligation — but only while the two stay distinguishable at the
-- row level. Every column sourced from the provider is commented
-- 'PROVIDER-DERIVED', so the licence boundary is answerable from the catalogue
-- rather than from knowing how the import works:
--
--   select column_name from information_schema.columns c
--   join pg_catalog.pg_description d
--     on d.objoid = 'public.stations'::regclass and d.objsubid = c.ordinal_position
--   where c.table_name = 'stations' and d.description like 'PROVIDER-DERIVED%';

-- Lets stations reference only brands that are actual retailers. OVERALL is a
-- row in brands but it is the DOE report's all-brands aggregate, not a company
-- with forecourts, and a station carrying it would be a category error that
-- silently produces an "Overall" pin on a map.
alter table public.brands
  add constraint brands_code_is_retailer_unique unique (code, is_retailer);

create table public.stations (
  id uuid primary key default gen_random_uuid(),

  -- Which provider supplied this row. One value today; named rather than
  -- assumed so that provider_place_id is never ambiguous if a second is added.
  provider text not null default 'openstreetmap',

  -- The provider's own identifier, and this station's identity across imports.
  -- Matching on it is what makes a re-import idempotent: without it, matching on
  -- name and position would create a near-duplicate every time a contributor
  -- nudged a pin or a listed name changed from "Petron" to "Petron Km 62".
  --
  -- Stored as 'type/id' ('way/338076890'), never a bare integer. OSM ids are
  -- unique only WITHIN an element type, so node/123 and way/123 are different
  -- objects and both may exist. The registry holds all three types — Taguig
  -- alone returns 5 nodes, 26 ways and 3 relations — so a bare integer key would
  -- collide eventually rather than immediately, which is the worst schedule for
  -- a bug of this kind.
  provider_place_id text not null,

  name text not null,

  -- Nullable on purpose. A provider name that resolves to no registered brand
  -- must not be guessed at: a station filed under the wrong brand is shown the
  -- wrong brand's reference price — a wrong number attached to a real place. Nor
  -- may it be dropped, which leaves a hole in the map with nothing to indicate
  -- it. So the station is registered with no brand and appears in the review
  -- list. INDEPENDENT is a real brand DOE prices, reached only by an explicit
  -- rule; nothing falls through to it.
  brand_code text,

  -- Constant true, existing only to complete the composite foreign key below.
  -- With brand_code null the FK is not enforced (MATCH SIMPLE), which is what
  -- lets an unresolved station exist.
  brand_is_retailer boolean generated always as (true) stored,

  locality_id uuid not null references public.localities (id),

  address text,

  latitude  numeric(9,6) not null,
  longitude numeric(9,6) not null,

  -- When the provider-derived fields above were last fetched. Cached data has to
  -- be distinguishable from durable data: these fields are a snapshot of someone
  -- else's database and go stale on their schedule, not ours.
  provider_fetched_at timestamptz not null,

  created_at timestamptz not null default now(),

  constraint stations_brand_is_retailer_fkey
    foreign key (brand_code, brand_is_retailer)
    references public.brands (code, is_retailer),

  constraint stations_provider_place_id_unique
    unique (provider, provider_place_id),

  constraint stations_provider_place_id_typed
    check (provider_place_id ~ '^(node|way|relation)/[0-9]+$'),

  constraint stations_name_not_blank
    check (length(btrim(name)) > 0),

  -- Philippine bounds. This catches a class of error a NOT NULL cannot: a
  -- transposed pair — longitude written into latitude — is two valid numbers
  -- that place the station in the Pacific, and once stored it is
  -- indistinguishable from a correct one. Malvar's 14.05 N / 121.15 E transposes
  -- to a latitude of 121.15, which no check on nullability would notice.
  constraint stations_latitude_within_ph  check (latitude  between 4.5 and 21.5),
  constraint stations_longitude_within_ph check (longitude between 116.0 and 127.0)
);

create index stations_locality_id_idx on public.stations (locality_id);
create index stations_brand_code_idx  on public.stations (brand_code);

comment on table public.stations is
  'Fuel stations, sourced from OpenStreetMap via Overpass. Registered whether or '
  'not DOE prices their brand — the reference price is the value that may be '
  'absent, never the station. Contains ODbL-licensed data; see the migration '
  'header for the Derivative/Collective Database boundary.';

comment on column public.stations.provider is
  'PROVIDER-DERIVED. Which places provider supplied this row.';
comment on column public.stations.provider_place_id is
  'PROVIDER-DERIVED. The provider''s stable identifier, as ''type/id''. This '
  'station''s identity across imports, and the only durable handle on a station '
  'that has closed — name and position can both change while it stays open.';
comment on column public.stations.name is
  'PROVIDER-DERIVED. The provider''s free-text name, stored as given.';
comment on column public.stations.address is
  'PROVIDER-DERIVED. Assembled from the provider''s addr:* tags; sporadic — '
  'present on well under half of surveyed stations.';
comment on column public.stations.latitude is
  'PROVIDER-DERIVED. For ways and relations this is the centroid Overpass '
  'returns under "out center", not a surveyed entrance.';
comment on column public.stations.longitude is
  'PROVIDER-DERIVED. See latitude.';
comment on column public.stations.provider_fetched_at is
  'When the PROVIDER-DERIVED fields were last fetched. The registry reflects the '
  'day it was imported; stations open, close and rebrand without signalling it.';

comment on column public.stations.brand_code is
  'Resolved by our own rules from the provider''s name, so NOT provider-derived. '
  'Null means unresolved and awaiting review — never a default, never a reason '
  'to drop the station.';

-- The review surface for task 4.2: a name the rules could not resolve, together
-- with the place it came from, so it can be settled by adding a rule or by
-- recording why the station carries no known brand.
create view public.stations_needing_brand_review as
  select s.id, s.provider, s.provider_place_id, s.name, s.address,
         l.display_name as locality, s.latitude, s.longitude, s.provider_fetched_at
    from public.stations s
    join public.localities l on l.id = s.locality_id
   where s.brand_code is null;

comment on view public.stations_needing_brand_review is
  'Stations whose provider name resolved to no registered brand. Expected to be '
  'non-empty: this is a maintenance surface, not a failure state.';

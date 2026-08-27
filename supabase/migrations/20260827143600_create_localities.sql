-- The locality registry: which localities the app covers, and how each one
-- resolves to official DOE pump-price data.
--
-- Two sourcing modes, not a general case plus a Malvar exception:
--
--   direct   the locality appears in its DOE region's report under its own name
--   proxy    the locality is absent from the report, so a neighbour's rows
--            stand in and MUST be attributed to that neighbour
--
-- Malvar is currently the only proxy, but modelling both modes as values of one
-- field is what makes "coverage is extended by configuration alone" true rather
-- than aspirational: adding a second proxy, or promoting Malvar to direct when
-- DOE starts publishing it, is a data change.

create type public.locality_sourcing_mode as enum ('direct', 'proxy');

comment on type public.locality_sourcing_mode is
  'direct: locality appears in its DOE report under its own name. '
  'proxy: locality is absent and borrows a neighbour''s rows, which must be attributed.';

create table public.localities (
  id                       uuid primary key default gen_random_uuid(),

  -- Name shown to users. Never taken from the source document, which contains
  -- errors (see doe_source_label).
  display_name             text not null,
  province_or_region       text not null,
  doe_region_code          text not null references public.doe_regions (code),

  sourcing_mode            public.locality_sourcing_mode not null,

  -- The locality label EXACTLY as it appears in the DOE document, including any
  -- misspelling. The NCR report prints "Taguig Cty". Storing the error here
  -- keeps it out of the product and makes it a one-row fix if DOE corrects it,
  -- rather than a workaround buried in a parser.
  -- For a proxy locality this is the SUBSTITUTE's label, since that is what the
  -- document actually contains.
  doe_source_label         text not null,

  -- Display name of the substitute locality, for attribution shown to users.
  -- Kept separate from doe_source_label because the substitute's document label
  -- may itself be misspelled: proxying off Taguig would mean matching
  -- "Taguig Cty" while attributing to "Taguig City".
  -- NULL for direct localities.
  proxy_source_display_name text,

  created_at               timestamptz not null default now(),

  constraint localities_display_name_not_blank
    check (length(btrim(display_name)) > 0),
  constraint localities_province_not_blank
    check (length(btrim(province_or_region)) > 0),
  constraint localities_doe_source_label_not_blank
    check (length(btrim(doe_source_label)) > 0),

  -- A proxy without a substitute cannot be attributed, and a direct locality
  -- carrying an attribution would misrepresent official data as borrowed.
  -- Both are rejected here rather than left to application discipline.
  constraint localities_proxy_requires_source check (
    (sourcing_mode = 'proxy'  and proxy_source_display_name is not null
                              and length(btrim(proxy_source_display_name)) > 0)
    or
    (sourcing_mode = 'direct' and proxy_source_display_name is null)
  ),

  constraint localities_display_name_unique unique (display_name)
);

comment on table public.localities is
  'Localities the app covers and how each resolves to DOE reference data. '
  'A locality absent from this table is not covered.';
comment on column public.localities.doe_source_label is
  'Verbatim label expected in the DOE document, misspellings included. For a '
  'proxy locality this is the substitute locality''s label.';
comment on column public.localities.proxy_source_display_name is
  'Substitute locality name shown to users as attribution. NULL for direct.';

create index localities_doe_region_code_idx on public.localities (doe_region_code);

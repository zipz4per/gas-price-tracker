-- Normalizing DOE's four spellings of "no data".
--
-- The source documents express absence in ways that are not interchangeable and
-- must not become prices:
--
--   #N/A      NCR's unavailable marker
--   None      CALABARZON's unavailable marker
--   0.00      a published range of "0.00 - 0.00", meaning nothing was reported
--   No LFRO   no Liquid Fuel Retail Outlet — the locality has no station at all
--
-- The first three mean "we don't have a figure". The fourth means something
-- categorically different: there is nothing to have a figure about. Collapsing
-- them all to NULL would lose that, so 'No LFRO' is detected separately and
-- drives the locality report's status instead of a price.
--
-- Accepting raw TEXT rather than pre-parsed numbers is deliberate: it keeps
-- normalization in one place, so the operator transcribing a PDF and the future
-- automated parser both hand over exactly what the document said.

create or replace function public.is_no_outlet_marker(raw text)
returns boolean
language sql
immutable
parallel safe
set search_path = ''
as $$
  select raw is not null
     and upper(regexp_replace(btrim(raw), '\s+', ' ', 'g')) in ('NO LFRO', 'NOLFRO');
$$;

comment on function public.is_no_outlet_marker(text) is
  'True when a source cell carries DOE''s "No LFRO" marker, meaning the '
  'locality has no liquid fuel retail outlet at all.';

create or replace function public.normalize_doe_price(raw text)
returns numeric
language plpgsql
immutable
parallel safe
set search_path = ''
as $$
declare
  v text;
begin
  if raw is null then
    return null;
  end if;

  v := upper(btrim(raw));

  -- Empty, or any of DOE's absence markers.
  if v = '' or v in ('#N/A', 'N/A', 'NA', 'NONE', 'NULL', '-', '--', '—') then
    return null;
  end if;

  -- "No LFRO" is absence of an outlet, not absence of a figure. It is handled
  -- by the caller via is_no_outlet_marker(); never a price.
  if public.is_no_outlet_marker(raw) then
    return null;
  end if;

  -- Strip currency symbols, thousands separators, and stray spaces.
  v := regexp_replace(v, '[₱P,\s]', '', 'g');

  if v = '' or v !~ '^[0-9]+(\.[0-9]+)?$' then
    -- Unrecognized content. Refuse rather than guess: a silently mis-parsed
    -- price is indistinguishable from a correct one downstream.
    raise exception 'unrecognized price value: %', raw
      using errcode = 'invalid_text_representation';
  end if;

  -- A published 0.00 means nothing was reported, not that fuel costs nothing.
  if v::numeric = 0 then
    return null;
  end if;

  return v::numeric;
end;
$$;

comment on function public.normalize_doe_price(text) is
  'Parses a raw DOE price cell. Absence markers and 0.00 become NULL; '
  'unrecognized content raises rather than guessing.';

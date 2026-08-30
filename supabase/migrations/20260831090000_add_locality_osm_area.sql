-- Which OpenStreetMap boundary each locality is, so the station import can ask
-- the provider about it.
--
-- The import queries Overpass for fuel stations inside an administrative area.
-- Selecting that area by name is wrong in two ways, and both fail quietly:
--
--   1. Our name is not always OSM's name. There is no boundary called
--      "Lipa City" — OSM calls it "Lipa" — so a name query returns an EMPTY
--      result for a locality with 52 stations. That reads as "none mapped here"
--      rather than as a lookup failure, which is the worst possible way for a
--      lookup to fail.
--
--   2. Names are not unique on a planet. A boundary search for "Lipa" returns
--      roughly twenty administrative relations — in Poland, Slovenia, Estonia
--      and the Philippines among others. An area-by-name query would union them
--      and import Polish fuel stations into a Batangas locality, with
--      plausible-looking rows that only the coordinate bounds check would catch.
--
-- So the boundary is identified by its OSM relation id, which is stable and
-- unambiguous, and the OSM name is stored beside it precisely BECAUSE it differs
-- from ours. This is the same shape as doe_source_label: the source's own label
-- kept verbatim next to the one we show, so the difference is data rather than a
-- special case in code.

alter table public.localities
  add column osm_relation_id bigint,
  add column osm_name        text;

alter table public.localities
  add constraint localities_osm_relation_id_unique unique (osm_relation_id);

-- Both or neither. A relation id with no name records nothing about why the
-- names differ; a name with no id is not queryable.
alter table public.localities
  add constraint localities_osm_area_complete
  check ((osm_relation_id is null) = (osm_name is null));

alter table public.localities
  add constraint localities_osm_relation_id_positive
  check (osm_relation_id is null or osm_relation_id > 0);

comment on column public.localities.osm_relation_id is
  'OSM relation id of this locality''s administrative boundary. The import '
  'derives an Overpass area id as 3600000000 + this value. Identified by id '
  'rather than name because names are neither unique nor shared with us.';

comment on column public.localities.osm_name is
  'The name OSM uses for this boundary, stored verbatim. Differs from '
  'display_name for Lipa City ("Lipa") and Taguig City ("Taguig").';

-- Surveyed 2026-08-31. Each confirmed as the single admin_level=6 boundary of
-- that name in the Philippines; "Lipa" and "Taguig" each collide with foreign
-- boundaries of the same name, which is why the id is what we store.
update public.localities set osm_relation_id = 5947753, osm_name = 'Malvar'  where display_name = 'Malvar';
update public.localities set osm_relation_id = 6209763, osm_name = 'Lipa'    where display_name = 'Lipa City';
update public.localities set osm_relation_id =  184776, osm_name = 'Taguig'  where display_name = 'Taguig City';

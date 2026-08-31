-- Six chains leave the INDEPENDENT bucket.
--
-- INDEPENDENT is a residual, not a company. It currently holds 36 of 96
-- stations, and at least six of those are multi-station operators with their own
-- forecourts, their own signage, and - once the catalogue lands - their own
-- product names. Uno Fuel with four stations is a chain, not an independent.
--
-- brands becomes a record of who operates stations rather than a projection of
-- who appears in the DOE report. None of these six is DOE-monitored, so none
-- carries a brand-level reference price, and that is now irrelevant: since
-- add-price-reports a station's reference figure is the locality-wide range
-- across all brands and does not consult its brand at all.
--
-- WHICH IS WHAT MAKES THIS SAFE. Rewriting brand_code on sixteen live stations
-- would have changed the price each of them displays before that change; now it
-- changes only their label. One change removed brand from the pricing path,
-- which is what lets this one correct brands in bulk.

insert into public.brands (code, display_name, is_retailer, sort_order) values
  ('UNO_FUEL',     'Uno Fuel',     true, 91),
  ('PETRO_GAZZ',   'Petro Gazz',   true, 92),
  ('NITRO',        'Nitro',        true, 93),
  ('REPHIL',       'RePhil',       true, 94),
  ('FUEL_EXPRESS', 'Fuel Express', true, 95),
  ('MAXFILL',      'Maxfill',      true, 96);

-- Sort orders sit between PTT (90) and INDEPENDENT (100): after every
-- DOE-reported retailer, before the residual bucket. No existing order moves.

-- The rules are UPDATED, not added.
--
-- Adding a second rule for the same trade name would leave the INDEPENDENT rule
-- in place, two distinct brands would match one name, and resolve_station_brand
-- would return null for every one of these stations - the unique-match-or-
-- nothing rule turning a promotion into a demotion.
update public.brand_name_rules set brand_code = 'UNO_FUEL',
  note = 'Regional chain, four stations. Not DOE-monitored.'
 where pattern = '\yuno\s+fuel\y';

update public.brand_name_rules set brand_code = 'PETRO_GAZZ',
  note = 'Regional chain. The optional prefix folds "Petro Gazz" onto "Gazz"; normalization now does the same, and both are kept.'
 where pattern = '\y(petro\s+)?gazz\y';

update public.brand_name_rules set brand_code = 'NITRO',
  note = 'Regional chain, two stations. Not DOE-monitored.'
 where pattern = '\ynitro\y';

update public.brand_name_rules set brand_code = 'REPHIL',
  note = 'Regional chain, two stations. Not DOE-monitored.'
 where pattern = '\yrephil\y';

-- "Rojan Fuel Express" travels with "Fuel Express" because the rule already
-- says they are one operator - a judgement add-station-registry made when it
-- wrote the optional prefix. Preserved rather than revisited here: three
-- stations, not two.
update public.brand_name_rules set brand_code = 'FUEL_EXPRESS',
  note = 'Regional chain, three stations including the Rojan-prefixed one.'
 where pattern = '\y(rojan\s+)?fuel\s+express\y';

update public.brand_name_rules set brand_code = 'MAXFILL',
  note = 'Regional chain, two stations. Spelled both Maxfill and MaxFill.'
 where pattern = '\ymax\s?fill\y';

-- Promote the stations these rules now name.
--
-- Deliberately NOT a blanket re-resolution. The import consulted the provider's
-- brand and operator tags as well as the name, and those tags are not stored, so
-- re-resolving every station from its name alone would discard what they
-- established: "Foxx" carries PHOENIX and matches no rule by name at all.
-- Only stations whose name now resolves to one of the six new brands move.
update public.stations s
   set brand_code = public.resolve_station_brand(null, null, s.name)
 where public.resolve_station_brand(null, null, s.name)
         in ('UNO_FUEL','PETRO_GAZZ','NITRO','REPHIL','FUEL_EXPRESS','MAXFILL')
   and s.brand_code is distinct from public.resolve_station_brand(null, null, s.name);

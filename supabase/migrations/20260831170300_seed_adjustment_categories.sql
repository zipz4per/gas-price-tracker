-- The three categories Philippine oil companies announce prices in, and what
-- each covers.
--
-- Gasoline is announced as one figure and moves every octane grade together. It
-- therefore expands to all four RON grades; a company that ever announces a
-- different figure per grade would need those split into separate categories,
-- which is a data edit rather than a code change.
--
-- Diesel covers both the standard and premium grades for the same reason.
--
-- Every registered fuel type is covered by exactly one category. That is checked
-- rather than assumed - see the verification in this change's tasks - because a
-- grade covered by nothing would silently never receive an adjustment, and a
-- grade covered twice would receive one twice.

insert into public.adjustment_category_fuel_types (category, fuel_type_code, note) values
  ('gasoline', 'RON_100',     'Announced as a single gasoline figure covering every octane grade.'),
  ('gasoline', 'RON_97',      null),
  ('gasoline', 'RON_95',      null),
  ('gasoline', 'RON_91',      null),
  ('diesel',   'DIESEL',      'Standard and premium diesel move on the same announced figure.'),
  ('diesel',   'DIESEL_PLUS', null),
  ('kerosene', 'KEROSENE',    null);

-- Spellings seen in announcement text, matched after lower-casing.
--
-- Deliberately narrow. "gas" is not an alias: it is used for LPG as often as for
-- gasoline in Philippine coverage, and a category matched wrongly applies a real
-- adjustment to the wrong grades. An unmatched phrasing is surfaced for review,
-- which is the cheaper failure.
insert into public.adjustment_category_aliases (alias, category, note) values
  ('gasoline',       'gasoline', null),
  ('gasolines',      'gasoline', null),
  ('unleaded',       'gasoline', 'Older phrasing, still seen.'),
  ('diesel',         'diesel',   null),
  ('kerosene',       'kerosene', null),
  ('kerosine',       'kerosene', 'Variant spelling.');

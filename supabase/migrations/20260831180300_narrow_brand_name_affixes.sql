-- Narrow the affix list, and make the regression check able to fail.
--
-- Two things were wrong with the first version, and the registry said so.
--
-- FIRST: 'gas', 'station' and 'stations' are part of real trade names here, not
-- descriptors around them. Three rules depend on the word: \ybb\s+gas\y,
-- \yfab\s+gas\y, \ybm\s+gas\y. Stripping "gas" left "bb", "fab" and "bm", which
-- match nothing, and three stations that had resolved to a brand stopped
-- resolving at all. An affix is only safe when no rule needs the word it
-- removes, and that is a property of THIS registry rather than of English.
--
-- What survives is 'petro' - the case the design names, and safe because
-- \y(petro\s+)?gazz\y already treats the prefix as optional - plus corporate
-- suffixes, which no rule uses.
--
-- Worth recording for whoever extends this: the existing patterns already
-- absorb most spelling variance themselves. \y(petro\s+)?gazz\y folds Petro
-- Gazz onto Gazz, \y(rojan\s+)?fuel\s+express\y folds that pair, \ymax\s?fill\y
-- folds Maxfill onto MaxFill, and ~* folds case. Normalization is not what
-- rescues those; it spares FUTURE rules from having to spell out every optional
-- prefix, and it handles corporate suffixes and punctuation, which no pattern
-- does today. That is a narrower benefit than the proposal assumed, and the cost
-- of a careless affix is a rule that silently stops matching.
--
-- SECOND: the regression check could not fail the way it was meant to. Every
-- case compared two names for sameness, and substring folding preserves
-- difference while destroying identity: "Petron" becomes "n", which is still
-- different from "gazz", so every case passed while the name was ruined. The
-- check now also asserts what a name normalizes TO, and those cases do fail -
-- "petron" is not "n".

delete from public.brand_name_affixes where affix in ('gas', 'station', 'stations');

insert into public.brand_name_affixes (affix, note) values
  ('incorporated', 'Corporate suffix. No rule matches on it.');

drop function public.check_brand_name_normalization();

create function public.check_brand_name_normalization()
returns table (case_name text, expected text, actual text, passed boolean)
language sql
stable
set search_path = ''
as $$
  -- What a name must normalize TO. These are the cases that catch substring
  -- folding: strip 'petro' as a substring and "petron" becomes "n".
  with identity(case_name, name, expect) as (values
    ('Petron survives intact',      'Petron',          'petron'),
    ('Gasso survives intact',       'Gasso',           'gasso'),
    ('Seaoil survives intact',      'Seaoil',          'seaoil'),
    ('BB Gas keeps its trade name', 'BB Gas',          'bb gas'),
    ('FAB Gas Station keeps "gas"', 'FAB Gas Station', 'fab gas station'),
    ('Petro Gazz loses the prefix', 'Petro Gazz',      'gazz')
  ),
  -- Which names must fold together, and which must not.
  pairs(case_name, a, b, must_match) as (values
    ('Petron is not Petro Gazz',       'Petron',     'Petro Gazz',    false),
    ('Petron is not Gazz',             'Petron',     'Gazz',          false),
    ('Gasso is not Gas',               'Gasso',      'Gas',           false),
    ('Seaoil is not Sea',              'Seaoil',     'Sea',           false),
    ('Total is not Totally',           'Total',      'Totally',       false),
    ('Petro Gazz folds onto Gazz',     'Petro Gazz', 'Gazz',          true),
    ('Case does not split Maxfill',    'Maxfill',    'MaxFill',       true),
    ('Corporate suffix folds away',    'Uno Fuel',   'Uno Fuel Inc.', true),
    ('Punctuation does not split',     'Uni-Oil',    'Uni Oil',       true)
  )
  select i.case_name, i.expect,
         coalesce(public.normalize_brand_name(i.name), '(null)'),
         public.normalize_brand_name(i.name) is not distinct from i.expect
    from identity i
  union all
  select p.case_name,
         case when p.must_match then 'same' else 'different' end,
         case when public.normalize_brand_name(p.a) is not distinct from public.normalize_brand_name(p.b)
              then 'same' else 'different' end,
         (public.normalize_brand_name(p.a) is not distinct from public.normalize_brand_name(p.b))
           = p.must_match
    from pairs p;
$$;

comment on function public.check_brand_name_normalization() is
  'Regression check on brand name folding. Every row must have passed = true. '
  'The identity cases are the ones that catch an affix folded as a substring '
  'rather than as a whole word.';

revoke all on function public.check_brand_name_normalization() from public;
grant execute on function public.check_brand_name_normalization() to service_role;

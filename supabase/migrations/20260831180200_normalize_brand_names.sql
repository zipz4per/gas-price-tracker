-- Folding the spellings a provider returns for one operator.
--
-- The registry holds "Gazz" twice and "Petro Gazz" once; it holds "Maxfill" and
-- "MaxFill". These are one operator each, split by how a contributor happened to
-- type them, and rules applied to the raw name split them again.
--
-- THE SAFETY PROPERTY, and it is the whole of this migration: affixes fold only
-- on WORD BOUNDARIES, never as substrings. "Petro Gazz" and "Gazz" are one
-- operator and must merge; "Petron" is a different operator and must not be
-- touched. A substring rule stripping "petro" merges all three and leaves
-- "Petron" as "n" - and the result looks like successful resolution rather than
-- an error, which is what makes it dangerous. check_brand_name_normalization()
-- at the bottom of this file exists to fail loudly if anyone ever makes that
-- change.

create table public.brand_name_affixes (
  affix text primary key
    constraint brand_name_affixes_lowercase check (affix = lower(affix))
    constraint brand_name_affixes_not_blank check (length(btrim(affix)) > 0),
  note  text not null
);

comment on table public.brand_name_affixes is
  'Words removed from a provider name before it is matched to a brand. Removed '
  'as whole words only: a substring rule here silently merges distinct '
  'operators.';

insert into public.brand_name_affixes (affix, note) values
  ('petro',        'Folds "Petro Gazz" onto "Gazz". Safe only as a whole word: "Petron" contains it and is a different company.'),
  ('gas',          'Folds "BB Gas" onto "BB" and "X Gas Station" onto "X".'),
  ('station',      'Generic descriptor, never part of a trade name.'),
  ('stations',     'Plural of the same.'),
  ('inc',          'Corporate suffix.'),
  ('corp',         'Corporate suffix.'),
  ('corporation',  'Corporate suffix.');

-- Lower-case, punctuation to space, listed affixes removed as whole words,
-- whitespace collapsed. Null when nothing is left.
create function public.normalize_brand_name(p_name text)
returns text
language plpgsql
stable
set search_path = ''
as $$
declare
  v text;
  a record;
begin
  if p_name is null then
    return null;
  end if;

  v := lower(btrim(p_name));
  v := regexp_replace(v, '[^a-z0-9]+', ' ', 'g');

  -- Longest first, so a multi-word affix is removed before its parts would be.
  for a in select af.affix from public.brand_name_affixes af
            order by length(af.affix) desc, af.affix loop
    v := regexp_replace(v, '\y' || a.affix || '\y', ' ', 'g');
  end loop;

  return nullif(btrim(regexp_replace(v, '\s+', ' ', 'g')), '');
end;
$$;

comment on function public.normalize_brand_name(text) is
  'A provider name reduced to the part that identifies an operator. Affixes are '
  'removed on word boundaries only.';

-- Resolution is unchanged in how it CHOOSES: the provider's brand tag, then
-- operator, then name; within the first field that matches anything, a unique
-- brand resolves and ambiguity resolves to null. Only what it matches against
-- changed.
--
-- A brand may now be registered because it sells fuel, whether or not the
-- reference source reports it. brands is a record of who operates stations, not
-- a projection of who appears in the DOE report.
create or replace function public.resolve_station_brand(
  p_brand    text,
  p_operator text,
  p_name     text
) returns text
language sql
stable
as $$
  with candidates as (
    select v.pri, public.normalize_brand_name(v.txt) as txt
      from (values (1, p_brand), (2, p_operator), (3, p_name)) as v(pri, txt)
     where coalesce(btrim(v.txt), '') <> ''
  ),
  matched as (
    select c.pri, r.brand_code
      from candidates c
      join public.brand_name_rules r on c.txt ~* r.pattern
     where c.txt is not null
  ),
  winning_field as (
    select min(pri) as pri from matched
  )
  select case
           when count(distinct m.brand_code) = 1 then min(m.brand_code)
           else null
         end
    from matched m
    join winning_field w on m.pri = w.pri;
$$;

-- The regression test, as a function rather than a file, so it cannot rot apart
-- from the schema it guards and runs wherever the database runs.
--
-- It fails the moment someone adds an affix that folds as a substring. Adding
-- 'petro' as a substring rule collapses "Petron" to "n" and makes the first two
-- cases below fail rather than quietly re-filing twenty Petron stations.
create function public.check_brand_name_normalization()
returns table (case_name text, expected text, actual text, passed boolean)
language sql
stable
set search_path = ''
as $$
  with cases(case_name, a, b, must_match) as (values
    -- Must stay DISTINCT. Petron against Petro Gazz first among them.
    ('Petron is not Petro Gazz',        'Petron',        'Petro Gazz',      false),
    ('Petron is not Gazz',              'Petron',        'Gazz',            false),
    ('Gasso is not Gas',                'Gasso',         'Gas',             false),
    ('Seaoil is not Sea',               'Seaoil',        'Sea',             false),
    ('Total is not Totally',            'Total',         'Totally',         false),
    -- Must MERGE.
    ('Petro Gazz folds onto Gazz',      'Petro Gazz',    'Gazz',            true),
    ('Case does not split Maxfill',     'Maxfill',       'MaxFill',         true),
    ('Trailing descriptor folds away',  'Felimon Magpantay', 'Felimon Magpantay Gas Station', true),
    ('Corporate suffix folds away',     'Uno Fuel',      'Uno Fuel Inc.',   true)
  )
  select
    c.case_name,
    case when c.must_match then 'same' else 'different' end,
    case when public.normalize_brand_name(c.a) is not distinct from public.normalize_brand_name(c.b)
         then 'same' else 'different' end,
    (public.normalize_brand_name(c.a) is not distinct from public.normalize_brand_name(c.b))
      = c.must_match
  from cases c;
$$;

comment on function public.check_brand_name_normalization() is
  'Regression check on brand name folding. Every row must have passed = true. '
  'Fails if an affix is ever added that folds as a substring rather than as a '
  'whole word.';

revoke all on function public.normalize_brand_name(text) from public;
revoke all on function public.check_brand_name_normalization() from public;
grant execute on function public.normalize_brand_name(text) to anon, authenticated, service_role;
grant execute on function public.check_brand_name_normalization() to service_role;

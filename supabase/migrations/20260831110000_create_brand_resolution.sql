-- Resolving a provider's free-text station name to a registered brand.
--
-- The provider returns "Petron Gas Station", "Shell Select", "Caltex - Star
-- Mart", or a name with no brand in it at all. Nothing here guesses. A station
-- filed under the wrong brand is shown the WRONG BRAND'S reference price — a
-- wrong number attached to a real place, which is the failure this project keeps
-- designing against. A station dropped for being unrecognised is a hole in the
-- map with nothing to indicate it. So an unmatched name resolves to null, the
-- station is registered anyway, and the name goes to
-- stations_needing_brand_review.
--
-- Rules are data, not code, for the same reason the DOE proxy mapping is:
-- adding a retailer must be an insert, not a deployment.

create table public.brand_name_rules (
  id          uuid primary key default gen_random_uuid(),
  brand_code  text not null,
  brand_is_retailer boolean generated always as (true) stored,

  -- Case-insensitive POSIX regex matched against provider text. Patterns use \y
  -- word boundaries so "Petro Gazz" does not match a rule for Petron and
  -- "Total" does not match inside "Totally".
  pattern     text not null,

  -- Why this rule exists. Not decoration: a bare pattern list becomes
  -- unmaintainable the first time someone wonders whether a rule is a real
  -- retailer or a typo workaround.
  note        text not null,

  created_at  timestamptz not null default now(),

  constraint brand_name_rules_pattern_unique unique (pattern),
  constraint brand_name_rules_pattern_not_blank check (length(btrim(pattern)) > 0),
  constraint brand_name_rules_brand_fkey
    foreign key (brand_code, brand_is_retailer)
    references public.brands (code, is_retailer)
);

comment on table public.brand_name_rules is
  'Maintained rules mapping provider station names to registered brands. '
  'Expected to be incomplete: an unmatched name is reviewed, never guessed.';

-- Resolution order: the provider's own brand tag, then operator, then the
-- free-text name. A brand tag is an assertion about the brand; a name merely
-- often contains one. "Petro Gazz" named next to an operator of "Petron" should
-- resolve as Petron, and consulting the more authoritative field first is what
-- makes that true without a special case.
--
-- Within the first field that matches anything, a unique brand resolves and
-- everything else resolves to null. Two different brands matching one string is
-- exactly the ambiguity that must reach a human — the same unique-match-or-
-- nothing rule the sha resolution and the label derivation already follow.
create function public.resolve_station_brand(
  p_brand    text,
  p_operator text,
  p_name     text
) returns text
language sql
stable
as $$
  with candidates as (
    select v.pri, v.txt
      from (values (1, p_brand), (2, p_operator), (3, p_name)) as v(pri, txt)
     where coalesce(btrim(v.txt), '') <> ''
  ),
  matched as (
    select c.pri, r.brand_code
      from candidates c
      join public.brand_name_rules r on c.txt ~* r.pattern
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

comment on function public.resolve_station_brand(text, text, text) is
  'Brand for a provider place, or null when the rules do not uniquely determine '
  'one. Null means review, never a default. Consults brand, then operator, then '
  'name, and stops at the first field that matches any rule.';

insert into public.brand_name_rules (brand_code, pattern, note) values
  -- The ten brands DOE reports. These carry reference prices.
  ('PETRON',   '\ypetron\y',                    'DOE-reported retailer.'),
  ('SHELL',    '\yshell\y',                     'DOE-reported retailer.'),
  ('CALTEX',   '\ycaltex\y',                    'DOE-reported retailer.'),
  ('PHOENIX',  '\yphoenix\y',                   'DOE-reported retailer.'),
  ('TOTAL',    '\ytotal(energies)?\y',          'DOE-reported retailer; rebranded TotalEnergies.'),
  ('UNIOIL',   '\yuni[ -]?oil\y',               'DOE-reported retailer; spaced and hyphenated forms seen.'),
  ('SEAOIL',   '\ysea[ -]?oil\y',               'DOE-reported retailer; "SEAOIL" and "Sea Oil" both seen.'),
  ('FLYING_V', '\yflying[ -]?v\y',              'DOE-reported retailer.'),
  ('PTT',      '\yptt\y',                       'DOE-reported retailer.'),

  -- Regional retailers outside DOE's brand list. Each is a real company with
  -- forecourts; DOE simply does not monitor it, so it carries no reference
  -- price and its stations show the no-reference state.
  --
  -- These are the answer to the design's open question. They are mapped to
  -- INDEPENDENT by EXPLICIT RULE, one per trade name, never by falling through:
  -- a station reaches INDEPENDENT because someone recognised the name, not
  -- because nothing else matched.
  ('INDEPENDENT', '\yuno\s+fuel\y',             'Regional retailer, not DOE-monitored.'),
  ('INDEPENDENT', '\yflex\s?fuel\y',            'Regional retailer, not DOE-monitored.'),
  ('INDEPENDENT', '\yrephil\y',                 'Regional retailer, not DOE-monitored.'),
  ('INDEPENDENT', '\yastral\y',                 'Regional retailer, not DOE-monitored.'),
  ('INDEPENDENT', '\ygasso\y',                  'Regional retailer, not DOE-monitored.'),
  ('INDEPENDENT', '\ybm\s+gas\y',               'Regional retailer, not DOE-monitored.'),
  ('INDEPENDENT', '\yeco\s?oil\y',              'Regional retailer; "EcoOil" and "Eco Oil" both seen.'),
  ('INDEPENDENT', '\ybb\s+gas\y',               'Regional retailer, not DOE-monitored.'),
  ('INDEPENDENT', '\y(petro\s+)?gazz\y',        'Regional retailer; "Petro Gazz" and "Gazz" both seen.'),
  ('INDEPENDENT', '\ymax\s?fill\y',             'Regional retailer; casing varies.'),
  ('INDEPENDENT', '\ysmart\s?fuels?\y',         'Regional retailer, not DOE-monitored.'),
  ('INDEPENDENT', '\yequator\y',                'Regional retailer, not DOE-monitored.'),
  ('INDEPENDENT', '\ynitro\y',                  'Regional retailer, not DOE-monitored.'),
  ('INDEPENDENT', '\yglobal\s+oil\y',           'Regional retailer, not DOE-monitored.'),
  ('INDEPENDENT', '\yn\s+energy\y',             'Regional retailer, not DOE-monitored.'),
  ('INDEPENDENT', '\yhanz\s+fuels?\y',          'Regional retailer, not DOE-monitored.'),
  ('INDEPENDENT', '\yargon\s+fuel\y',           'Regional retailer, not DOE-monitored.'),
  ('INDEPENDENT', '\y(rojan\s+)?fuel\s+express\y', 'Regional retailer; "Rojan Fuel Express" and "Fuel Express" both seen.'),
  ('INDEPENDENT', '\yfab\s+gas\y',              'Regional retailer, not DOE-monitored.'),
  ('INDEPENDENT', '\yfelimon\s+magpantay\y',    'Single-site operator trading under a personal name.');

alter table public.brand_name_rules enable row level security;

create policy brand_name_rules_public_read
  on public.brand_name_rules
  for select
  to anon, authenticated
  using (true);

-- No write policy, matching every other reference table here.

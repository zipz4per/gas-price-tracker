-- What was tried on 2026-08-31, and why the catalogue is empty.
--
-- The rule for seeding is that a product name and its grade come from the
-- brand's own published page, never from memory or a third-party summary,
-- because a wrong entry is indistinguishable from a right one to anyone reading
-- the table later. Applied honestly, that rule produced almost nothing.
--
-- Only Petron publishes a lineup a machine can read: its sitemap lists the fuel
-- products and each page states a grade -
--
--   PETRON BLAZE 100 EURO 6     "Premium Plus Grade (RON 100)"
--   PETRON XCS EURO 4           "Premium Plus Grade Ethanol-blended (RON 95+)"
--   PETRON XTRA ADVANCE EURO 4  "can run on 91 RON fuel", "Regular Grade"
--
-- - and even there the two diesels stop it. PETRON TURBO DIESEL and PETRON
-- DIESEL MAX EURO 4 are both "Distillate fuel with additive" and both describe
-- themselves as premium; nothing on either page distinguishes the standard grade
-- from the premium one. The catalogue is keyed on (brand, fuel type), so they
-- cannot both be DIESEL, and choosing between them is the guess the rule exists
-- to prevent.
--
-- Seeding Petron's three gasoline grades alone was considered and rejected. The
-- catalogue is AUTHORITATIVE - a fuel type with no entry is one the brand does
-- not sell - so a Petron list without diesel would stop twenty stations from
-- accepting a diesel report, on one of the two fuels DOE actually covers. An
-- empty catalogue is better than a confidently incomplete one: with no entries,
-- every station falls back to canonical grade names, which is the path the spec
-- already makes first-class for the 36 unbranded stations.
--
-- So nothing is seeded. What is recorded is the attempt, so the next person
-- starts from what failed rather than repeating it.

alter table public.brands add column products_review_note text;

comment on column public.brands.products_review_note is
  'What was tried when sourcing this brand''s lineup, and what stopped it. Kept '
  'so an unsourced brand is a recorded state rather than an untouched one.';

update public.brands set products_source_url = v.url, products_review_note = v.note
  from (values
    ('PETRON',   'https://www.petron.com/sitemap_index.xml',
     'Sitemap lists fuel products and each page states a grade; gasoline is fully readable. Blocked on the two diesels: PETRON TURBO DIESEL and PETRON DIESEL MAX EURO 4 are both "Distillate fuel with additive" and both premium, with nothing distinguishing DIESEL from DIESEL_PLUS.'),
    ('SHELL',    'https://www.shell.com.ph/motorists/shell-fuels.html',
     'JavaScript-rendered. Static HTML yields 70 characters of chrome and no product content. Needs a rendering browser or another source.'),
    ('CALTEX',   'https://www.caltex.com.ph/en_ph/personal/products/fuel.html',
     'JavaScript-rendered. Static HTML yields navigation only; no product names and no octane statements.'),
    ('SEAOIL',   'https://www.seaoil.com.ph/',
     '/products/ returns 404. Home page reachable but carries no octane statements.'),
    ('PHOENIX',  'https://www.phoenixfuels.ph/',
     '/products/ returns 404. Home page reachable but carries no octane statements.'),
    ('FLYING_V', 'https://flyingv.com.ph/',
     '/products/ returns 404. Home page reachable but carries no octane statements.'),
    ('PTT',      'https://www.pttphilippines.com/',
     'Home page returns 120 characters of text; no product content.'),
    ('UNIOIL',   'https://www.unioil.com/',
     'Redirects (307) without resolving to readable product content.'),
    ('TOTAL',    'https://www.totalenergies.ph/',
     'Host did not resolve.'),
    ('PETRO_GAZZ','https://petrogazz.com/',
     'Reachable but effectively empty to a static fetch.'),
    ('UNO_FUEL', 'https://unofuel.com/',
     'Host did not resolve.'),
    ('NITRO',    'https://nitrofuels.com.ph/',
     'Host did not resolve.')
  ) as v(code, url, note)
 where public.brands.code = v.code;

-- products_verified_at stays null everywhere. Nothing was verified, so every
-- brand remains in brands_needing_product_review - which is the correct queue
-- state, not an oversight.

drop view public.brands_needing_product_review;

create view public.brands_needing_product_review as
select
  b.code,
  b.display_name,
  b.sort_order,
  count(p.fuel_type_code)::integer as products,
  b.products_verified_at,
  b.products_source_url,
  b.products_review_note,
  case
    when b.products_verified_at is null then 'never reviewed'
    else format('last reviewed %s days ago',
                (current_date - b.products_verified_at::date)::text)
  end as why,
  (select count(*) from public.stations s where s.brand_code = b.code)::integer
    as stations
from public.brands b
left join public.brand_fuel_products p on p.brand_code = b.code
where b.is_retailer
  and (b.products_verified_at is null
       or b.products_verified_at < now() - interval '180 days')
group by b.code, b.display_name, b.sort_order, b.products_verified_at,
         b.products_source_url, b.products_review_note
order by (select count(*) from public.stations s where s.brand_code = b.code) desc,
         b.sort_order;

comment on view public.brands_needing_product_review is
  'Retailer brands whose product list has never been checked, or was checked '
  'more than 180 days ago. Ordered by how many stations a stale or missing '
  'lineup would affect. products_review_note records what was already tried.';

alter view public.brands_needing_product_review set (security_invoker = true);

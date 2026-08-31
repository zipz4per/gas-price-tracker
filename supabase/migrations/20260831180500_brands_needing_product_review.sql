-- Brands whose product list needs looking at.
--
-- Product lineups change when a brand rebrands, retires a product, or launches
-- one, and a mapping that goes stale shows a driver a product name their station
-- no longer carries. Nothing in the catalogue detects that on its own: a wrong
-- product name reads exactly like a right one.
--
-- So staleness is found by review rather than by a user, and this is the surface
-- that drives it - the same arrangement as stations_needing_brand_review, which
-- it sits beside in docs/station-brand-review.md.
--
-- 180 days. Rebrands and product renames run on a scale of years, so a shorter
-- interval produces review work with nothing to find, and reviews that reliably
-- find nothing stop being done.
--
-- Retailers only. OVERALL is DOE's all-brands aggregate rather than a company
-- and cannot hold products at all - the composite foreign key on
-- brand_fuel_products sees to that - so listing it would be asking someone to
-- research a lineup that does not exist.

create view public.brands_needing_product_review as
select
  b.code,
  b.display_name,
  b.sort_order,
  count(p.fuel_type_code)::integer as products,
  b.products_verified_at,
  b.products_source_url,
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
group by b.code, b.display_name, b.sort_order, b.products_verified_at, b.products_source_url
order by b.sort_order;

comment on view public.brands_needing_product_review is
  'Retailer brands whose product list has never been checked against the '
  'brand''s own published lineup, or was last checked more than 180 days ago. '
  'A non-empty list is the normal state; an empty one means every lineup was '
  'confirmed recently.';

alter view public.brands_needing_product_review set (security_invoker = true);

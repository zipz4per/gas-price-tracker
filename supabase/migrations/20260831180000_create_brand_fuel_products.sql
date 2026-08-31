-- What each brand calls the fuels it sells, and which fuels it sells at all.
--
-- A driver at a Petron forecourt reads "Blaze" and "XCS" off the canopy. A
-- driver at a Shell reads "V-Power" and "FuelSave". Nobody reads "RON 95". A
-- form that asks in grades asks in a vocabulary the person is not standing in
-- front of, and the likely outcomes are a wrong grade or an abandoned report.
--
-- The grade stays what is STORED. Prices are only comparable across brands in
-- grade terms and the reference data is published by grade, so a product name is
-- a presentation of a fuel type and never a substitute for one.
--
-- The table is also authoritative about what a brand does NOT sell. A fuel type
-- with no entry for a brand is one that brand does not offer, and offering it
-- invites a price recorded against a product that does not exist at that
-- station - indistinguishable afterwards from a real observation.

create table public.brand_fuel_products (
  brand_code        text not null,

  -- Fixed true, joined to brands through a composite key, exactly as stations
  -- does. It makes "a product cannot name a non-retailer brand" a constraint
  -- rather than a check somebody has to remember: the OVERALL row, which is
  -- DOE's all-brands aggregate and not a company, cannot acquire a product list.
  brand_is_retailer boolean generated always as (true) stored,

  fuel_type_code    text not null
    references public.fuel_types (code),

  -- The name on the canopy.
  product_name      text not null
    constraint brand_fuel_products_name_not_blank
      check (length(btrim(product_name)) > 0),

  -- Presentation order, as the brand presents it. A canopy is not ordered by
  -- octane, and a list that disagrees with the signage costs the reader a
  -- translation step at the moment they are matching a number to a product.
  sort_order        integer not null,

  note              text,
  created_at        timestamptz not null default now(),

  primary key (brand_code, fuel_type_code),

  -- Two products sharing a position is an ordering nobody can predict.
  constraint brand_fuel_products_order_unique unique (brand_code, sort_order),

  constraint brand_fuel_products_brand_fkey
    foreign key (brand_code, brand_is_retailer)
    references public.brands (code, is_retailer)
);

comment on table public.brand_fuel_products is
  'Per-brand product names for canonical fuel types, and the list of fuels each '
  'brand sells. A fuel type absent for a brand is one that brand does not offer.';

comment on column public.brand_fuel_products.product_name is
  'PRESENTATION ONLY. What is stored, compared, and matched against reference '
  'data is fuel_type_code.';

-- When a brand's product list was last checked against the brand's own
-- published lineup, and where that was read.
--
-- On the brand rather than on each product, because the review action is "open
-- this brand's site and compare its lineup" - one act covering every row at
-- once. A per-product timestamp would record the same date many times and go
-- stale in fragments, which is harder to review than a single date per brand.
alter table public.brands
  add column products_verified_at timestamptz,
  add column products_source_url  text;

comment on column public.brands.products_verified_at is
  'When this brand''s product list was last compared against its own published '
  'lineup. Null means never.';

comment on column public.brands.products_source_url is
  'The published page the product list was read from. A lineup with no source '
  'is a lineup nobody can re-check.';

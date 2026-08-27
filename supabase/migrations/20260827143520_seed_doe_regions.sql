-- Seed the two DOE regions this project covers.
--
-- Both report addresses below were verified live against prod-cms.doe.gov.ph
-- while planning this change. The observed real addresses were:
--
--   NCR   .../ncr-price-monitoring-08182026-pdf     (period: Aug 18-24, 2026, 7 days)
--   IV-A  .../region-iv-a-calabarzon-22-pdf         (period: Aug 18-20, 2026, 3 days)
--
-- Note the NCR slug is the reporting date as MMDDYYYY, which makes the address
-- computable. The CALABARZON slug is a bare counter with no relationship to any
-- date, so the current report can only be found by looking at the index page.

insert into public.doe_regions
  (code, name, index_url, url_pattern, resolution_strategy, strategy_notes)
values
  (
    'NCR',
    'National Capital Region',
    'https://doe.gov.ph/data-and-prices/liquid-fuels/retail-pump-prices/ncr-pump-prices',
    'https://prod-cms.doe.gov.ph/documents/d/guest/ncr-price-monitoring-{MMDDYYYY}-pdf',
    'date_derived',
    'Slug embeds the reporting period start date as MMDDYYYY (verified: '
    '08182026 for the week of August 18-24, 2026). The address can be '
    'constructed from a date without consulting the index page. Report covers '
    'a 7-day week and labels it "For the week of ...". Only a subset of NCR '
    'cities appear; Taguig is present, spelled "Taguig Cty".'
  ),
  (
    'IV-A',
    'Region IV-A (CALABARZON)',
    'https://doe.gov.ph/data-and-prices/liquid-fuels/retail-pump-prices/south-luzon-pump-prices',
    'https://prod-cms.doe.gov.ph/documents/d/guest/region-iv-a-calabarzon-{N}-pdf',
    'discovery',
    'Slug ends in an opaque incrementing counter (verified: 22) with no '
    'relationship to the reporting date, so the current report cannot be '
    'predicted and must be resolved from the index page. Report covers a '
    '3-day monitoring window and labels it "DATE MONITORING: ...", not a week. '
    'Malvar is absent from this report, which is why it is proxied.'
  );

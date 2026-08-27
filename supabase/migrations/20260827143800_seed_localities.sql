-- The three launch localities, chosen as a commute corridor rather than as a
-- contiguous coverage area: home is Malvar/Batangas, work is BGC/Taguig, so the
-- question being answered is "where along my route is fuel cheapest".
--
-- Each resolves to DOE data differently, which is the point — all three paths
-- exist from day one rather than being retrofitted around a Malvar special case:
--
--   Malvar       proxy   absent from the CALABARZON report entirely; borrows
--                        Tanauan City's rows, which MUST be attributed
--   Lipa City    direct  present under its own name in the same report
--   Taguig City  direct  present in the NCR report, but spelled "Taguig Cty"
--
-- All three source labels were verified against the live documents while
-- planning this change.

insert into public.localities
  (display_name, province_or_region, doe_region_code, sourcing_mode,
   doe_source_label, proxy_source_display_name)
values
  -- Malvar is not listed in the DOE CALABARZON report at any point. Tanauan
  -- City is its neighbouring municipality and the nearest listed locality, so
  -- its rows stand in. The UI must label this as a proxy: these are genuinely
  -- Tanauan's prices, not official figures for Malvar.
  ('Malvar', 'Batangas', 'IV-A', 'proxy', 'Tanauan City', 'Tanauan City'),

  -- Lipa City appears under its own name. No approximation involved.
  ('Lipa City', 'Batangas', 'IV-A', 'direct', 'Lipa City', null),

  -- The NCR report prints "Taguig Cty" — a typo in the source document.
  -- Matching on the intended spelling finds nothing, so the document's spelling
  -- is stored verbatim while users still see "Taguig City".
  ('Taguig City', 'NCR', 'NCR', 'direct', 'Taguig Cty', null);

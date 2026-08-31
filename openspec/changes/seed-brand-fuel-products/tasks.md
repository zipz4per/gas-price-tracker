## 1. Source the lineups

- [ ] 1.1 For each brand with stations, try the sourcing order in `design.md` — data sheet, safety data sheet, product page, sitemap — and record for each the deepest step reached and what stopped it; verify every brand has an outcome recorded, including the ones that yield nothing
- [ ] 1.2 Retry Shell and Caltex at the data-sheet and safety-data-sheet steps, which this change has not yet attempted; verify whether either states a grade for its products and record the answer either way
- [ ] 1.3 Retry Seaoil, Phoenix and Flying V, whose `/products/` paths returned 404, for a working path via each brand's sitemap; verify the result and record it
- [ ] 1.4 Resolve Petron's two diesels from a published statement, or record that no published source distinguishes `DIESEL` from `DIESEL_PLUS` for them; verify the conclusion is attributable to a page rather than to a product name

## 2. Seed what can be sourced

- [ ] 2.1 For each brand whose lineup is complete and sourced, write a migration inserting its `brand_fuel_products` rows in the brand's own presentation order, setting `products_verified_at` and `products_source_url`; verify each product name and each grade is attributable to a page named in the migration
- [ ] 2.2 Apply the whole-or-nothing rule: verify no brand is seeded with a fuel it sells missing, and record for any brand held back which grade could not be sourced
- [ ] 2.3 Update `brands.products_review_note` for every brand that stays unsourced with what was tried this time and where it stopped; verify no unsourced brand is left with a note from the previous attempt

## 3. Verify against the reference data

- [ ] 3.1 Run the DOE cross-check from `design.md` — every brand and grade DOE prices must appear in that brand's catalogue; verify the result is empty and investigate every row if it is not
- [ ] 3.2 Verify each seeded brand's stations now offer exactly its catalogued fuels through `get_station_fuel_options`, and that unseeded brands still return all seven canonical grades
- [ ] 3.3 Verify `submit_price_report` now rejects an uncatalogued fuel at a seeded brand's station, naming the brand, and still accepts every registered fuel at an unseeded or unbranded station
- [ ] 3.4 Verify no displayed price changed, by comparing a fingerprint of `get_station_prices` across all three localities before and after; the catalogue governs what may be reported, never what is shown

## 4. Close the loop

- [ ] 4.1 Verify `brands_needing_product_review` lists exactly the brands that remain unsourced, each with a current note; verify a seeded brand has left the list
- [ ] 4.2 Record in `docs/station-brand-review.md` which brands are sourceable and which are not, so the next review starts from the answer rather than repeating the search; verify a reader can tell why a brand has no catalogue without re-running the search

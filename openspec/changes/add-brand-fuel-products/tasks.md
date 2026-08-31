## 1. Catalogue schema

- [ ] 1.1 Create `brand_fuel_products` keyed on `(brand_code, fuel_type_code)` with `product_name`, `sort_order`, a `brand_is_retailer` generated column fixed at true, and a composite foreign key to `brands(code, is_retailer)`; verify an insert naming `OVERALL` is rejected by the constraint rather than by application logic
- [ ] 1.2 Constrain `fuel_type_code` to `fuel_types(code)`; verify an entry naming an unregistered grade is rejected
- [ ] 1.3 Add `brands.products_verified_at`; verify it is null for every existing brand, since none has been reviewed yet
- [ ] 1.4 Enable RLS with a select-only policy for `anon`, revoking the default `PUBLIC` grant first; verify `anon` can read the catalogue and cannot write it

## 2. Brand normalization

- [ ] 2.1 Add a maintained affix list and a normalization step that lower-cases a provider name and removes listed affixes **only on `\y` word boundaries**; verify `Petro Gazz` and `Gazz` normalize identically and `Petron` is left unchanged
- [ ] 2.2 Apply normalization to the incoming name inside `resolve_station_brand` without changing how it chooses between candidate matches; verify the existing brand resolution tests still pass unchanged
- [ ] 2.3 Add a regression test asserting known-distinct operator pairs stay distinct after normalization, `Petron` against `Petro Gazz` first among them; verify the test fails if `petro` is added to the affix list as a substring rule
- [ ] 2.4 Verify case folding merges `Maxfill` and `MaxFill` to one brand and that no currently-resolved station changes brand as a side effect

## 3. Promote the pooled operators

- [ ] 3.1 Add brand rows for Uno Fuel, Petro Gazz, Nitro, RePhil, Fuel Express, and Maxfill with `is_retailer = true` and sort orders after the existing retailers; verify each appears in `brands` and none displaces an existing brand's order
- [ ] 3.2 Add `brand_name_rules` patterns for the new brands; verify each pattern matches its own station names and matches no station currently resolved to another brand
- [ ] 3.3 Re-resolve brand for every existing station in place and report how many moved out of `INDEPENDENT`; verify the count matches the 15 stations identified in the proposal and that no station previously resolved to a national brand changed
- [ ] 3.4 Verify no station's displayed price changed as a result, since `add-price-reports` makes the reference figure locality-wide — or, if that change has not landed yet, record which stations' displayed prices moved and why

## 4. Review surface

- [ ] 4.1 Create a `brands_needing_product_review` view listing brands whose `products_verified_at` is null or older than 180 days, alongside their product count; verify every brand appears before any seeding is done
- [ ] 4.2 Extend `docs/station-brand-review.md` with the product-list review question and the 180-day cadence; verify the document states both review actions and which view surfaces each

## 5. Seed the catalogue

- [ ] 5.1 Compile each national brand's current product lineup from that brand's own published pages, recording the source URL and the date consulted; verify every product name is attributable to a published page and none is recalled from memory or taken from a third-party summary
- [ ] 5.2 Insert the catalogue rows with the brand's own presentation order, and set `products_verified_at` to the date of consultation; verify `brands_needing_product_review` is empty for the seeded brands afterwards
- [ ] 5.3 Verify the seeded lineups against the registry by checking that every fuel type DOE reports for a brand appears in that brand's product list, and investigate any that do not

## 6. Read path and submission

- [ ] 6.1 Implement `get_station_fuel_options(p_station_id)` returning the brand's products in the brand's order, falling back to canonical fuel type display names when the brand has no entries or the station has no brand; verify all three cases from one call — a seeded brand, a registered brand with no entries, and a station with a null brand
- [ ] 6.2 Verify the fallback covers the unbranded stations by calling it for each of the 36 unbranded or independent stations and confirming every one returns a non-empty list
- [ ] 6.3 Revoke the default `PUBLIC` execute grant and grant to `anon` and `authenticated`; verify `has_function_privilege('public', ...)` is false
- [ ] 6.4 Reject a price submission for a fuel type not in the station's brand catalogue, with a message naming the brand rather than the grade; verify the rejection at a seeded branded station and verify an unbranded station still accepts every registered fuel type. If `add-price-reports` has not landed, record this task as carried into that change's submission function

## 7. Documentation

- [ ] 7.1 Document the catalogue as the third maintained naming surface alongside `brand_name_rules` and the station brand review, stating what goes stale in each and the shared review cadence; verify a reader can determine which surface to edit for a rebrand, a new operator, and a renamed product

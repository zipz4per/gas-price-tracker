## 1. Settings and schema

- [ ] 1.1 Add a single-row `price_report_settings` table holding the proximity radius (150 m), the carry-forward limits (4 adjustments, 35 days), and the per-station hourly rate cap (start at 6), with a check constraint pinning it to one row; verify a second insert is rejected and the defaults read back as stated in design.md
- [ ] 1.2 Create `price_adjustments` — fuel type, signed delta, effective timestamp, announced timestamp, source — unique on `(fuel_type_code, effective_at)`; verify inserting the same fuel type and effective time twice raises a unique violation, since a duplicate would double every derived price
- [ ] 1.3 Create `price_reports` — station, fuel type, price, observed time, proximity verdict — with a foreign key to `stations` and `fuel_types`, and **no column able to hold a coordinate**; verify the column list contains no latitude, longitude, or geometry field
- [ ] 1.4 Create the `price_kind` enum (`observed`, `derived`, `reference`) and the `station_price_result` composite type with the basis sentence non-nullable; verify a select from the type lists the basis column as `not null`
- [ ] 1.5 Enable RLS on both new tables with select-only policies for `anon`, and revoke the default `PUBLIC` grant before granting to `anon` and `authenticated`; verify `anon` can read and cannot insert directly, so submission is only possible through the function in group 2

## 2. Submission path

- [ ] 2.1 Implement `submit_price_report(p_station_id, p_fuel_type, p_price, p_latitude, p_longitude)` as `security definer` with an empty `search_path`, computing distance with the equirectangular approximation already used in this project; verify a submission from within 150 m is accepted and one from 500 m away is rejected
- [ ] 2.2 Reject a submission whose price falls outside the registered `min_plausible`/`max_plausible` for its fuel type, with a message naming implausibility rather than a generic failure; verify ₱785.00 for a RON grade is rejected and ₱78.50 is accepted
- [ ] 2.3 Reject a submission with no usable coordinates rather than recording it as unverified; verify a null latitude or longitude raises rather than inserting a row with the verdict false
- [ ] 2.4 Enforce the per-station, per-fuel-type hourly rate cap from settings; verify the cap-plus-first submission in one hour is rejected and the message says the station has been reported too often
- [ ] 2.5 Confirm the coordinates do not survive the call by selecting the inserted row and every column of it; verify the row holds the station, price, time, and verdict only
- [ ] 2.6 Add a candidate-station lookup `stations_within_radius(p_latitude, p_longitude)` returning stations inside the configured radius ordered by distance; verify a point between the two Lipa stations 4 m apart returns both, since the submitter — not the system — chooses between them

## 3. Read path

- [ ] 3.1 Implement `get_station_prices(p_locality, p_fuel_type default null)` returning one row per station and fuel type, raising `22023` for an unregistered locality or unrecognised fuel type as the existing read paths do; verify a null fuel type returns seven rows per station and a named one returns one
- [ ] 3.2 Compute the observed rung — most recent report per station and fuel type, with the supporting report count and the newest report's age; verify two reports at different times yield the later price and a count of two
- [ ] 3.3 Compute the derived rung on read as the last observation plus every adjustment effective since it was observed, carrying the observation date and the number of adjustments applied; verify inserting an adjustment after an observation shifts the displayed price and marks it derived without any scheduled job running
- [ ] 3.4 Apply the carry-forward limit as adjustments **or** days, whichever binds first, falling back to the reference rung past it; verify an observation five adjustments old reverts to reference, and separately that an observation 40 days old with no adjustments ingested also reverts — the case that catches a dead feed
- [ ] 3.5 Shift the locality reference range by the same adjustments so an unreported station does not fall further behind each cycle; verify the reference range moves by the adjustment and declares that it did
- [ ] 3.6 Compose the non-nullable basis sentence in SQL for all three rungs, naming for a derived price the observation, its date, and the adjustments applied; verify no rung returns a figure with a null or empty basis
- [ ] 3.7 Return an explicit absence reason where no rung yields a figure, reusing `reference_absence_reason` rather than a second vocabulary; verify a RON 97 request returns every station with `fuel_type_not_reported` and no figure
- [ ] 3.8 Revoke the default `PUBLIC` execute grant on every new function and grant to `anon` and `authenticated` explicitly; verify `has_function_privilege('public', ...)` is false for each

## 4. Reference source change

- [ ] 4.1 Change `get_stations_with_reference_prices` to read the `OVERALL` row for the locality instead of the station's brand row, keeping its signature; verify all 52 Lipa City stations return the same RON 95 range rather than three brand-specific values
- [ ] 4.2 Update its basis sentence to describe a locality-wide range across all brands, and stop emitting `brand_not_reported` and `brand_not_identified` on this path; verify a Phoenix station and a station with a null brand both now carry the locality range
- [ ] 4.3 Verify the 17 stations whose brands DOE never prices now receive a reference figure wherever the locality has one, by comparing the count of stations with `has_reference_data` before and after for RON 95

## 5. Privacy verification

- [ ] 5.1 Check `log_statement` and `log_min_duration_statement` on the hosted project and confirm the submission call's arguments are not written to the server log; verify by submitting a report and inspecting the log for the coordinates
- [ ] 5.2 Confirm the client calls the submission function with bound parameters rather than an interpolated statement, so coordinates cannot reach a log through statement text; record the finding in the change

## 6. Documentation

- [ ] 6.1 Update `PRD.md` FR-1 through FR-3 to describe one price slot with a declared kind rather than parallel crowdsourced and DOE values; verify the three-state ladder is described once and matches `specs/price-reports/spec.md`
- [ ] 6.2 Document the submission and read paths in the existing docs set, including the settings table and what each value controls; verify a reader can determine the radius, the carry-forward limits, and the rate cap without reading a migration

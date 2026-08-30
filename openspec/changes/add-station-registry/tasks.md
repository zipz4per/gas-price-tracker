## 1. PRD correction

- [x] 1.1 Correct FR-19 and §4 (the task said §5; the seeded-stations text is in §4, and §5 is Target Users) so station data comes from a places provider rather than a hand-typed seed list; verify the revised text keeps the true premise — DOE publishes municipality-level brand prices and no per-station data — while replacing the conclusion that stations must therefore be entered by hand
- [x] 1.2 State in the PRD that DOE is a price source only, and that station existence, count, and location are never inferred from it; verify no remaining text reads a brand's presence or absence in the report as evidence about stations
- [x] 1.3 Widen the station registry from Malvar alone to every covered locality, and verify no remaining text scopes stations to the launch municipality
- [x] 1.4 State that a station's brand is an attribute of the station and that several stations in one locality may share a brand; verify no remaining text treats a brand as a station
- [x] 1.5 Record OpenStreetMap as an external dependency in the PRD's risks, covering its ODbL attribution and share-alike obligations, its usage policy, and its contributor-driven and therefore unguaranteed coverage; verify it names both the failure mode of the registry going stale when the provider is not re-consulted and the fact that the registry is not exhaustive
- [x] 1.6 Correct FR-2 and FR-3 so a DOE reference range is a value that may be absent rather than one assumed always present, and state that a station stays on the map when DOE prices no brand of its kind in that locality; verify the revised text gives the missing-reference case its own explicit state rather than folding it into "no recent reports"

## 2. Provider terms and access

- [x] 2.1 Record the ODbL attribution and share-alike obligations that follow from sourcing stations from OpenStreetMap, with the licence version and the date read; verify the schema in group 3 keeps provider-derived fields distinguishable from our own data at the row level
- [x] 2.2 Record the required attribution string and where it must appear, and verify it is carried as an obligation on any surface that displays station data rather than left to the client to remember
- [x] 2.3 Record the Overpass usage policy that applies to the import, and verify the import is a deliberate server-side operation with no path from a client request to a provider query
- [x] 2.4 Verify an Overpass query for one locality returns fuel stations with a stable element identifier, name, address, and coordinates, and record the response shape the import will depend on
- [x] 2.5 Verify the query uses `nwr` rather than `node` and resolves ways and relations to a point, confirming against a locality where a node-only query returns a materially smaller count

## 3. Station registry schema

- [x] 3.1 Create the stations table with a surrogate key, the provider place identifier, name, brand, locality, and address, and verify a station cannot be recorded against an unregistered locality or an unregistered brand
- [x] 3.2 Enforce uniqueness on the provider place identifier, and verify importing the same place twice matches the existing station instead of creating a second one
- [x] 3.3 Record when provider-supplied fields were last fetched, so cached data is distinguishable from durable data; verify every station carries a fetch timestamp
- [x] 3.4 Require coordinates and reject any outside Philippine bounds; verify a transposed latitude and longitude pair is rejected rather than stored
- [x] 3.5 Verify a station recorded with coordinates and an address is returned with both, so a client can place it on a map
- [x] 3.6 Mark which station fields are provider-derived, and verify the distinction is determinable from the record rather than from knowledge of the import

## 4. Brand resolution

- [x] 4.1 Resolve a provider's free-text station name to a registered brand through maintained rules, and verify names such as "Petron Gas Station" and "Shell Select" resolve to their brands
- [x] 4.2 Surface an unresolvable name for review together with the place it came from, and verify it is neither assigned a default brand nor dropped
- [x] 4.3 Verify an unbranded station is classified as `INDEPENDENT` only by an explicit rule, and that nothing falls through to it by default

## 5. Station read path

- [x] 5.1 Return the stations in a locality together with the DOE reference range for each station's brand and fuel type, and verify the reporting period accompanies every result
- [x] 5.2 Label the figure as a locality-wide brand range in the result itself, and verify a consumer cannot obtain the range without the label that says what it is
- [x] 5.3 Carry proxy attribution through to stations, and verify a Malvar station names Tanauan City as the source while Lipa City and Taguig City stations carry no attribution
- [x] 5.4 Return a station with an explicit no-reference-data marker when its brand has no DOE figures for the requested fuel type, and verify the station is still returned rather than omitted
- [x] 5.5 Verify a registered locality with no stations returns an empty result, distinguishable from an unregistered locality
- [x] 5.6 Verify the read path is callable by the anon role and that no insert, update, or delete path is reachable through it. Note: with RLS and no write policy an anon UPDATE/DELETE reports 0 rows rather than raising — no rows are visible to modify. Safe, but a no-op rather than a refusal. Also revoked the default PUBLIC EXECUTE that both read functions carried
- [x] 5.7 Return the source attribution alongside the stations, and verify a consumer cannot obtain station data without it

## 6. Import

- [x] 6.1 Import stations for Malvar, Lipa City, and Taguig City from the provider, and verify each imported station resolves to a brand or the review list, a locality, and valid coordinates
- [x] 6.2 Verify the import is idempotent by running it twice and confirming no duplicate stations and no changed station count
- [x] 6.3 Verify a station whose brand DOE does not report is imported normally, confirming DOE plays no part in whether a station exists
- [x] 6.4 Record the review list of unresolved names produced by the import, and resolve each either by adding a rule or by recording why the station is excluded
- [x] 6.5 Verify the imported count is of the order measured on 2026-08-31 — 10 in Malvar, 52 in Lipa City, 34 in Taguig City, 96 total — and investigate any locality that comes back materially short rather than accepting a plausible number. These replace the 2026-08-28 survey's 14/52/87, which did not reproduce; see the annotation in `design.md`

## 7. End-to-end verification

- [x] 7.1 Verify every scenario in `specs/station-registry/spec.md` against the local stack and record any that cannot be exercised. All 18 exercised. The reference-price scenarios needed DOE data restored from hosted first — `supabase db reset` destroys the hand-loaded DOE rows, which is filed as a bug
- [x] 7.2 Verify two stations of the same brand in one locality are returned as separate, distinguishable entries
- [ ] 7.3 Push the migrations to hosted, verify no schema drift, and verify anonymous reads of the station list succeed there

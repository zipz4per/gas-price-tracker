## 1. DOE region source configuration

- [x] 1.1 Create the `doe_regions` table recording each region's report address pattern and resolution strategy; verify a row cannot be created without a strategy
- [x] 1.2 Seed NCR (date-derived, slug embedding the reporting date) and Region IV-A CALABARZON (discovery-based, opaque incrementing identifier); verify both rows are present and their strategies differ

## 2. Locality registry

- [x] 2.1 Create the `localities` table with display name, province/region label, DOE region reference, sourcing mode (`direct`/`proxy`), verbatim DOE source label, and proxy source locality; verify a `proxy` row without a proxy source is rejected by a constraint
- [x] 2.2 Implement the locality label normalization function (case, surrounding whitespace, and punctuation only — no fuzzy matching) and verify `Taguig Cty`, `  TAGUIG CTY `, and `taguig cty` all normalize identically, while `Taguig City` does not collide with `Taguig Cty` unless explicitly registered
- [x] 2.3 Verify the normalization function does not conflate `Batangas City` with the province label `Batangas`, confirming no edit-distance behaviour crept in
- [x] 2.4 Seed the three launch localities — Malvar (proxy via `Tanauan City`), Lipa City (direct), Taguig City (direct, source label `Taguig Cty`) — and verify each resolves to its expected DOE source label

## 3. Access control

- [x] 3.1 Enable RLS on `doe_regions` and `localities` and verify that with RLS on and no policies, the anon role can read nothing
- [x] 3.2 Add `SELECT` policies for the anon and authenticated roles on both tables and verify anonymous reads succeed
- [x] 3.3 Verify no insert, update, or delete policy exists on either table by attempting each as the anon role and confirming all are rejected

## 4. Verification

- [x] 4.1 Verify direct sourcing: confirm Lipa City and Taguig City resolve to their own source labels and carry no proxy attribution
- [x] 4.2 Verify proxy sourcing: confirm Malvar resolves to Tanauan City and that the proxy source name accompanies the result
- [x] 4.3 Verify coverage extension by adding and then removing a scratch locality row, confirming no code change is needed for it to resolve
- [x] 4.4 Verify a sourcing-mode flip by temporarily switching Malvar to `direct` and confirming proxy attribution disappears, then reverting
- [x] 4.5 Verify every scenario in `specs/locality-registry/spec.md` against the deployed schema and record any that cannot be exercised

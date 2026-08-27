## 1. Retrieval function

- [ ] 1.1 Implement the reference-price read function taking a locality and fuel type, selecting only rows from the latest `succeeded` run; verify rows from `in_progress` and `failed` runs are never returned
- [ ] 1.2 Resolve proxy sourcing inside the function so a request for Malvar returns Tanauan City figures with Tanauan City named as the proxy source; verify Lipa City and Taguig City return an empty attribution rather than a missing field
- [ ] 1.3 Return per-brand rows, the `OVERALL` range, and the common price where published; verify a brand with no published data is absent from the result rather than returned as zero or null-priced
- [ ] 1.4 Include the reporting period, verbatim period label, and recording timestamp in every result; verify a consumer can compute data age from the result alone
- [ ] 1.5 Return an explicit no-data result for a registered locality with no ingested data, and verify the call succeeds rather than erroring
- [ ] 1.6 Verify data is never borrowed across fuel types or localities: request a fuel type with no data for a locality that has data for others, and confirm the result reports no data rather than returning the other fuel type's figures
- [ ] 1.7 Verify stale data is served rather than withheld by querying a locality whose latest succeeded run is several periods old, and confirm the figures return with their period

## 2. Access control

- [ ] 2.1 Verify the retrieval function is callable by the anon role and returns the same results as the service role, confirming the read path works without authentication
- [ ] 2.2 Verify the function does not expose rows from failed or in-progress runs to the anon role by any argument combination
- [ ] 2.3 Verify no insert, update, or delete path is reachable through the function or its underlying tables as the anon role

## 3. Local end-to-end verification

- [ ] 3.1 Verify every scenario in `specs/doe-reference-prices/spec.md` for this change against the local stack and record any that cannot be exercised
- [ ] 3.2 Verify all three localities resolve correctly end to end — Malvar with proxy attribution, Lipa City and Taguig City without — for at least RON 95 and Diesel
- [ ] 3.3 Verify the no-destroy guarantee end to end: load a valid period, attempt a failing load for the same locality, and confirm the read function still returns the original period

## 4. Hosted deployment

- [ ] 4.1 Push migrations to the hosted project with `npx supabase db push` and verify the applied hosted schema matches local, with no drift introduced by dashboard edits
- [ ] 4.2 Re-run both DOE loads against hosted using the service-role key from `.env.local`, and verify all three localities resolve with the same results observed locally
- [ ] 4.3 Verify anonymous reads succeed against hosted using the project's publishable/anon key, confirming the read path is reachable as it will be from a client

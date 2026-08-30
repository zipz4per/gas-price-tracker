# Product Requirements Document: Gas Price Tracker (PH)

- **Status:** Draft v1
- **Date:** 2026-08-27
- **Repo:** https://github.com/zipz4per/gas-price-tracker
- **Intended use:** Source input for OpenSpec change proposals (`/opsx:propose`)

## 1. Overview & Problem Statement

Fuel prices in the Philippines vary station-to-station and change frequently, but there is no lightweight, no-signup way for a driver in a specific locality to see current pump prices nearby and compare them against the official DOE-monitored range. The Department of Energy (DOE) publishes weekly regional pump price monitoring reports (PDF/CMS documents), but these are not station-specific, not real-time, and not mobile-friendly.

This app lets anyone open it, see recently reported prices for gas stations near them, and submit a price update in a few taps — no account required. Official DOE data is ingested in the background to give each station a sanity-check range ("common/prevailing price") alongside live, crowdsourced numbers.

## 2. Goals

1. Let users view current fuel prices (by station, by fuel type) for their area with zero friction (no login, no signup).
2. Let users submit a price observation in under 15 seconds.
3. Keep the crowdsourced data reasonably trustworthy without requiring accounts, using device-based rate limiting.
4. Automatically ingest official DOE reference prices on a recurring schedule so every station has an authoritative baseline even before any user submits data.
5. Ship a V1 scoped tightly enough (single locality) to validate the concept before expanding coverage.

## 3. Non-Goals (V1)

- No user accounts, login, or profiles of any kind.
- No payment, ads, or monetization (open question for later — see §14).
- No route planning / navigation.
- No historical price *charts* beyond a simple recent-history list per station (nice-to-have, not required).
- No coverage outside the V1 covered area (see §4) — architecture should make expansion easy, but building out every region is out of scope for V1.
- No community moderation roles, admin dashboard, or manual review queue in V1 (may be revisited post-launch).

## 4. V1 Scope: Coverage Area

**Coverage area: Malvar and Lipa City (Batangas), and Taguig City (NCR).**

Malvar is the launch municipality and the one the proxy constraint below applies
to. Lipa City and Taguig City are covered from the start because the app follows
one person's actual route — home in Malvar, work in BGC — and a price app that
covers only one end of a commute answers half the question.

Constraint: DOE's Region IV-A (CALABARZON) pump price reports do not list Malvar as its own municipality. For V1, the app treats **Tanauan City, Batangas** (Malvar's neighboring municipality, present in the DOE report) as the DOE reference proxy for Malvar — i.e., DOE min/max/common prices shown for Malvar stations are sourced from the Tanauan City rows of the DOE report, clearly labeled as a proxy in the UI so users aren't misled about the source.

This proxy mapping must be a configuration value (not hardcoded logic scattered through the app), so that when DOE adds Malvar directly, or the app expands to new municipalities, remapping is a data change, not a code change.

**DOE is a price source only.** It publishes what a brand charges across a
municipality. It never names a station, never counts them, and never places one
on a map, so the system must not infer from the report that a station exists,
how many there are, or where one is. A brand's absence from the report says
nothing about the presence of stations carrying it — only that DOE did not
monitor it that week.

Station data (name, brand, address, coordinates) comes from an external places provider — OpenStreetMap, queried through Overpass — for every covered locality, not from a hand-typed list. DOE does not provide per-station data, which is true and does not lead where it first appears to: the answer is a source whose purpose is knowing what is on the ground, and which can be re-consulted as stations open, close, and rebrand. A list typed out once is stale the first time one of those happens.

## 5. Target Users

- **Local drivers/riders across the covered area** — Malvar and Lipa City in Batangas, and Taguig City in NCR — who want to know which nearby station currently has the best price before they go fill up.
- **Casual contributors** — anyone who just filled up and wants to log what they paid, without creating an account.

## 6. User Stories

1. As a driver, I open the app and immediately see a list/map of gas stations in the locality I am in — Malvar, Lipa City, or Taguig City — with their most recent known price per fuel type, without logging in.
2. As a driver, I tap a station and see: current crowdsourced price(s) by fuel type, when each was last reported, and the DOE reference range (via the Tanauan City proxy) for context.
3. As a driver who just bought fuel, I tap "Report a price," pick the station, fuel type, and price, and submit — no account, in a few taps.
4. As a driver, I don't want to see obviously fake/spam prices cluttering the list — the app should quietly limit how often the same device can spam submissions.
5. As the app maintainer, I want DOE reference prices refreshed automatically on DOE's publication cadence (weekly) without manual work.

## 7. Functional Requirements

### 7.1 Price Viewing
- FR-1: Show a list (and, if feasible, a map) of gas stations in any covered locality with the latest crowdsourced price per fuel type (RON 91/95/97/100, Diesel, Diesel Plus where applicable).
- FR-2: Each station detail view shows: brand, address/barangay, per-fuel-type latest price with timestamp and relative age ("reported 3 hours ago"), and — **where one exists** — the DOE reference min/max/common price for that fuel type, labeled as a locality-wide range for that brand rather than as a price observed at this station, and carrying the proxy attribution where one applies (Malvar's figures are sourced from Tanauan City).
- FR-3: A station has three possible states for a fuel type, and all three must be shown explicitly rather than collapsed into two — never a blank or broken screen:

  | State | What is shown |
  |---|---|
  | A crowdsourced report exists | the reported price, with timestamp and relative age |
  | No report, but DOE prices this brand here | the DOE brand range, labelled, with a "no recent reports" state |
  | No report and DOE does not price this brand here | an explicit no-reference-data state — not a zero, a blank, or a hidden station |

  The third is not an edge case. DOE prices only the brands it happened to monitor, so on the survey behind the station registry at least 37 of 153 stations fall into it. A station stays on the map when DOE prices no brand of its kind in its locality; the reference price is the value that may be absent, never the station.
- FR-4: Support pull-to-refresh and basic sort (e.g., cheapest first per fuel type).

### 7.2 Price Submission
- FR-5: Any user can submit a price report: select station (from the registry; "station not listed" flow optional for V1.1) → select fuel type → enter price → submit. No account/login step anywhere in this flow.
- FR-6: Client-side validation: price must be numeric, positive, and within a sane bound (e.g., ₱30–₱120/liter, configurable) before submission is allowed.
- FR-7: On submit, the app attaches the device's anonymous identifier (see §7.3) and a timestamp; the submission is written directly to Supabase (no server-side account needed, protected by RLS policies — see §10).
- FR-8: Submitted prices appear immediately in the app (optimistic UI) pending any rate-limit checks.

### 7.3 Spam & Abuse Protection (no accounts)
- FR-9: On first launch, the app generates a persistent anonymous device identifier (e.g., a UUID stored via secure local storage) that is not tied to any personal info and is sent with every submission.
- FR-10: Rate limiting is enforced per device per station per fuel type: a device may submit at most one price report for a given station+fuel type within a configurable cooldown window (default: 6 hours).
- FR-11: A device-level daily cap limits total submissions across all stations (default: 10/day) to blunt bulk spam from a single device.
- FR-12: Rate-limit checks are enforced server-side (Postgres function / RLS policy / Edge Function), not just in the client, since the client can be bypassed.
- FR-13: Submissions that fail validation or rate limits are rejected with a clear in-app message (e.g., "You already reported this station recently").
- FR-14: (Future/open, not required for V1 — see §13) Community flagging and outlier detection against the DOE reference range are logged as candidate V2 protections if spam becomes an issue.

### 7.4 DOE Reference Data Ingestion
- FR-15: A scheduled background job (Supabase Edge Function on a cron schedule, matching DOE's weekly publication cadence) fetches the latest Region IV-A (CALABARZON) pump price report and extracts the Tanauan City, Batangas rows for all listed fuel types and brands (min, max, and common/prevailing price).
- FR-16: Because the DOE South Luzon pump-prices page (https://doe.gov.ph/data-and-prices/liquid-fuels/retail-pump-prices/south-luzon-pump-prices) is an index page rather than the report itself, the ingestion job must first resolve the current week's report document (from the DOE CMS listing, e.g. `prod-cms.doe.gov.ph/documents/d/guest/region-iv-a-calabarzon-##-pdf`, where the numeric suffix increments) before parsing the PDF. This resolution step is a known fragile point — see Risks (§13).
- FR-17: Parsed DOE data is stored with its source URL, the report's effective date range, and a `scraped_at` timestamp, so the app can show "DOE data as of [week of ...]" and so a bad scrape doesn't silently overwrite good data.
- FR-18: If a scheduled ingestion run fails (site structure changed, PDF unavailable, parse error), the job logs the failure and the app continues serving the last successfully ingested DOE data rather than showing nothing.

### 7.5 Stations Directory
- FR-19: The station registry is sourced from an external places provider — OpenStreetMap, queried through Overpass — across every covered locality, and stored as data (a Supabase table), not hardcoded in the app. Each station carries the provider's stable place identifier, so a re-import matches an existing station rather than creating a near-duplicate when a pin moves or a listed name changes.
- FR-19a: A station's brand is an **attribute of the station**, not a substitute for it. One locality holds many stations and several of them may carry the same brand — a locality's "Shell" is not one row. The provider's free-text name is resolved to a registered brand through maintained rules; a name that resolves to nothing goes to a review list, and is neither assigned a default brand nor dropped, because a station filed under the wrong brand is shown the wrong brand's reference price and a dropped station is a hole in the map with nothing to indicate it.
- FR-19b: Every station the provider returns is registered, whether or not DOE prices its brand in that locality. Filtering the registry to brands DOE prices would cut the survey from 153 stations to 62 and would remove stations that plainly exist — Lipa City would lose seven Shell and five Phoenix, and Malvar would show two pins.
- FR-20: (V1.1/open) Allow users to suggest a new station or a correction to an existing station's details, subject to the same anonymous device rate limiting as price submissions.

## 8. Non-Functional Requirements

- NFR-1: **No accounts anywhere** — this is a hard product constraint, not just a V1 simplification; all designs must work with only an anonymous device identifier.
- NFR-2: App must remain usable with a cached/last-known state when offline or when Supabase is briefly unreachable (show stale data with an "offline / last updated at ..." indicator rather than an error screen).
- NFR-3: DOE ingestion cadence should track DOE's actual publication schedule (weekly); the schedule should be configurable, not hardcoded to a specific day, since DOE's publishing day can shift.
- NFR-4: Submission flow (open app → report price) should be completable in well under 15 seconds for a returning user.
- NFR-5: No personally identifiable information is collected or stored — the device identifier must not be derivable to a real identity, and no location is stored more precisely than needed to place a pin on a station.
- NFR-6: The system should be inexpensive to run at V1 scale (single municipality) — favor Supabase's free/low tiers (Postgres, scheduled Edge Functions, Storage) over any paid third-party scraping/parsing service.

## 9. Data Model (Supabase / Postgres — indicative)

- **stations**: `id`, `provider_place_id` (unique — the provider's stable identifier, and the station's identity across imports), `name`, `brand` (FK to `brands`; an attribute of the station, and not unique within a locality), `locality_id` (FK), `address`, `latitude`, `longitude`, `provider_fetched_at` (so provider-derived fields are distinguishable from data the system originates), `created_at`.
- **price_reports**: `id`, `station_id` (FK), `fuel_type`, `price`, `device_id`, `submitted_at`, `status` (`active` / `rejected` — for future moderation).
- **doe_reference_prices**: `id`, `region`, `province`, `city_municipality` (e.g. "Tanauan City"), `proxy_for_municipality` (e.g. "Malvar"), `fuel_type`, `brand`, `min_price`, `max_price`, `common_price`, `report_week_start`, `report_week_end`, `source_url`, `scraped_at`.
- **submission_rate_limits**: `device_id`, `station_id`, `fuel_type`, `last_submitted_at` — used by the server-side rate-limit check (or implemented as a query against `price_reports` directly, TBD at implementation time).

Row-Level Security notes: since there is no auth, RLS policies key off the client-supplied `device_id` plus server-side rate-limit logic in a Postgres function/Edge Function — inserts should go through a controlled function rather than raw table inserts, so rate limits can't be bypassed by calling the table API directly.

## 10. System Architecture

- **Client:** React Native (Expo recommended for faster iteration and OTA updates), talking directly to Supabase via its client SDK for reads, and via a Postgres RPC function (or Edge Function) for writes so rate-limiting/validation is enforced server-side.
- **Backend:** Supabase — Postgres database, a scheduled Edge Function (`pg_cron` + Edge Function, or Supabase's native Cron) for DOE ingestion, Postgres RPC function(s) for validated price submission, and optionally Supabase Storage if photo-proof is added later.
- **DOE ingestion job:** Runs on a schedule (weekly, aligned to DOE's publication cadence): resolves the current report document → downloads PDF → parses relevant rows (Tanauan City / Region IV-A) → upserts into `doe_reference_prices`.
- **No authentication layer** anywhere in the stack — anonymous Supabase access (anon key) for reads, and the RPC/Edge Function path (still keyless) for writes.

## 11. Tech Stack

- **Mobile app:** React Native (Expo), targeting iOS + Android.
- **Backend/DB:** Supabase (Postgres, Row-Level Security, Edge Functions, Cron).
- **PDF parsing:** A PDF-text-extraction library inside the Edge Function/ingestion job (implementation detail to confirm at build time — e.g. a Deno-compatible PDF parser, or a small separate ingestion service if Edge Function limits are a problem).
- **Maps (optional for V1):** React Native Maps or a lightweight static-map view for the station list, given the small geographic footprint of a single municipality.

## 12. Success Metrics (V1)

- At least N active stations across the covered localities with at least one crowdsourced price report within the last 7 days. The registry holds 96 stations as of the 2026-08-31 survey — 10 in Malvar, 52 in Lipa City, 34 in Taguig City — so N is now expressible as a fraction of a known denominator rather than left TBD.
- DOE ingestion job succeeds (no manual intervention) on ≥ 90% of scheduled runs over a month.
- Median time from app open to successful price submission < 15 seconds.
- Spam/rejected submission rate stays low enough that manual moderation is not required in V1 (no hard target yet — monitor and revisit).

## 13. Risks & Open Questions

- **DOE report URL/format is not stable.** The South Luzon page is an index, and the CALABARZON PDF URL includes an incrementing numeric suffix — the resolution logic (FR-16) is the single most fragile part of this system and should be built defensively (log-and-continue-on-failure, never crash the app's data on a bad scrape).
- **Malvar-via-Tanauan-proxy is an approximation**, not official DOE data for Malvar specifically. This must stay clearly labeled in the UI so users understand it's a stand-in, not an error.
- **DOE PDF parsing is brittle** — table layout, brand columns, or file format could change without notice; ingestion failures need to degrade gracefully (§7.4/FR-18) and ideally alert the maintainer (e.g., a simple log/webhook), not fail silently forever.
- **Rate-limit thresholds (6h/station, 10/day) are starting guesses** — should be configurable and tuned after observing real usage/spam patterns.
- **Monetization is undecided** (per your answer) — flagged here as an explicit open question rather than assumed; revisit post-V1 once there's real usage data.
- **OpenStreetMap is an external dependency with licence obligations.** Station data comes from OSM via the Overpass API, under the **Open Data Commons Open Database License (ODbL) v1.0**, published by the OpenStreetMap Foundation (read 2026-08-31). Two obligations follow. *Attribution:* any surface displaying this data must credit **© OpenStreetMap contributors** — this is a client obligation but it originates in the data layer, so it is carried with the station data rather than left to the client to remember. *Share-alike:* a table built by extracting OSM records is a Derivative Database, and publicly using one obliges us to offer it under ODbL; our own data alongside it (observed prices, DOE figures, localities) is a Collective Database and carries no such obligation — but only while the two stay distinguishable at the row level, which is why provider-derived fields are marked and carry a fetch timestamp.
- **Overpass is a free, volunteer-run service with a usage policy**, not an SLA. Imports must be deliberate server-side operations, never triggered per page view; there must be no path from a client request to a provider query. During verification the public endpoint returned *"the server is probably too busy to handle your request"* on several attempts and one mirror was unreachable entirely, so the import must retry with backoff and must not treat a failed run as an empty registry.
- **OSM coverage is contributor-driven and therefore unguaranteed.** The registry is explicitly **not exhaustive**: a station that exists may simply not be mapped, and 36 of the 96 stations found across the covered localities carry no name that resolves to a registered brand. The station-suggestion flow (FR-20) is the eventual answer to gaps, not a defect in the import.
- **The registry goes stale if the provider is not re-consulted.** Stations open, close, and rebrand on their own schedule, and nothing in the data signals that. This change establishes the registry and how stations enter it; scheduling a refresh is a separate concern, and until one exists the registry reflects the day it was imported. The provider's place identifier is what makes a later reconciliation possible — a closed station is identifiable by id, whereas one identified by name and position is not, since both can change while the station stays open.

## 14. Future Considerations (Post-V1, not required now)

- Expand beyond Malvar to neighboring municipalities/provinces (Tanauan directly, then broader CALABARZON, then other DOE regions) — architecture in §9/§10 is designed so this is a config/data change, not a rewrite.
- Community flagging or outlier-detection-based spam protection (mentioned as declined-for-now in §7.3/FR-14).
- Optional photo-proof attachments to submissions for higher trust.
- Historical price trend charts per station.
- Monetization approach (ads vs. none vs. something else) once usage data exists.
- User-suggested new stations / station corrections (FR-20) moving from "open" to fully specified.

---

*This document is intended as input for generating OpenSpec change proposals (`openspec/changes/...`) rather than as a finished spec itself — functional requirements above are written to map reasonably cleanly onto OpenSpec capabilities/requirements/scenarios during that process.*

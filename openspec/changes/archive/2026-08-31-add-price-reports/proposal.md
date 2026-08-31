## Why

Every price the app can currently show is a DOE brand range for a whole municipality, and no amount of DOE data will ever make it a station price. The report is structurally brand × locality: on a Lipa City map of 52 stations, RON 95 resolves to **three distinct numbers** — ₱78.80 repeated across 12 Petrons, ₱83.60 across 4 Caltexes, ₱71.50–73.99 across 16 independents, and no figure at all on the remaining 20. A map that looks like it compares stations is comparing three brands.

It is also stale on arrival. The current load covers 18–24 August for NCR and 18–20 August for Region IV-A; today is 31 August, and Philippine oil companies adjust prices most Tuesdays. Every figure in the database is at least one adjustment cycle behind before a driver ever sees it.

Only a person standing at the pump can close either gap. This change makes crowdsourced reports the source of truth for what a station charges, and demotes the DOE range to what it honestly is: the area-wide figure shown when nobody has reported yet, and a sanity check on what people report.

## What Changes

- **Introduce a price report as a first-class observation** — one price, for one station, for one fuel type, at one time, submitted without an account. This is the value the app displays.
- **Establish the displayed price as a three-state ladder**, so a consumer can never obtain a number without knowing what kind of number it is:
  - **observed** — a report someone submitted at the station
  - **derived** — an earlier observation carried forward across an announced price adjustment
  - **reference** — the DOE locality-wide range, when no report exists
- **Gate submission on physical presence.** A report is accepted only from a device near a registered station. The provider's own coordinates put competing brands 27–40 m apart, and 22 of 96 stations have a neighbour within 100 m, so proximity **authorizes** a report but cannot **identify** the station — the submitter chooses which station from the candidates in range.
- **Store no reporter location.** Proximity produces a verdict; the verdict and the chosen station are recorded, the coordinates are not.
- **Validate against plausibility bounds, not against the brand range.** `fuel_types` already carries `min_plausible` and `max_plausible` per fuel; a report outside them is rejected. Where a DOE locality range exists it may tighten this, but it is never the primary gate.
- **Ship V1 without a quorum.** A single plausible report from a device at the station becomes the displayed price. **Confidence is expressed in the display — report count and age — not by suppressing data.**
- **Carry a report forward across a price adjustment rather than expiring it.** When an adjustment is announced, the station's last observation becomes the baseline and is shifted by the delta. Expiry would discard the one thing that distinguishes this station from its neighbours, every week.
- **Bound the carry-forward.** A derived price degrades with each adjustment applied to it; past a stated limit the station reverts to the DOE reference rather than showing a number many cycles removed from any observation.
- **Shift the DOE reference by the same adjustment**, so an unreported station's fallback does not drift further behind each week while reported stations stay current.
- **Change the station's reference figure from its brand's range to the locality-wide range across all brands.** The `OVERALL` row exists for every locality in the report, covering the 17 stations DOE never prices by brand, and it makes no false claim about an individual forecourt.
- **Require an explicit reason wherever no price can be shown**, reusing the vocabulary `distinguish-absent-doe-data` established rather than inventing a second one.

### Explicitly out of scope

- **Ingesting price adjustments.** This change defines what an adjustment does to a baseline and to a reference range; where the adjustment comes from — a news feed, a manual entry, a DOE reload — is `add-price-adjustment-feed`.
- **Quorum, voting, and moderation.** Named here as the thing V1 deliberately omits, with the reason, so its later addition reads as a decision rather than a correction.
- **Accounts, device identity, and rate limiting beyond the proximity gate.**
- **Brand-specific submission fuel names.** That is `add-brand-fuel-products`.
- **Map rendering, distance sorting, and any client application.**
- **Deriving which fuels a station sells.** A report may be submitted for any registered fuel type.

## Capabilities

### New Capabilities

- `price-reports`: What a price report is, who may submit one and from where, how it is validated, how it becomes the displayed price, how it survives a price adjustment, and when it stops being trustworthy.

### Modified Capabilities

- `station-registry`: "A station's reference price is its brand's range, attributed as such" becomes the locality-wide range across all brands, and the reference is no longer the only thing a station can show — it becomes the last rung of the display ladder.

## Impact

- **New:** a `price_reports` table keyed by station and fuel type, carrying the submitted price, the submission time, and the proximity verdict — and deliberately not the submitter's coordinates.
- **New:** a read path returning each station's current displayed price with its state (observed, derived, reference), its age, and the sentence that says what it is.
- **New:** an adjustment concept — a per-fuel delta with an effective time — that both the observed baseline and the DOE reference are shifted by. This change defines its effect; another supplies its source.
- **Modified:** `get_stations_with_reference_prices` — its reference figure changes from brand range to locality `OVERALL`, and its result gains the report-derived price and state.
- **Modified:** `PRD.md` — FR-1 through FR-3 describe the crowdsourced price and the DOE range as parallel values; they become one slot with a declared state.
- **Removed from the critical path:** brand resolution no longer determines whether a station can show a price. `INDEPENDENT` and unresolved stations get the same locality reference as everyone else.
- **Depends on:** `station-registry` for the station a report attaches to, and `doe-reference-prices` for the `OVERALL` range and the absence vocabulary.
- **Unblocks:** the first client screen, and every PRD user story past the first.

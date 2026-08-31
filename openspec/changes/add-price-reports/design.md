## Context

See `proposal.md` — Why, and `specs/price-reports/spec.md` for the behaviour this design has to produce.

Two properties of the existing system shape everything below:

- **Sentences travel with figures.** `get_doe_reference_prices` and `get_stations_with_reference_prices` both compose their own `reference_basis` in SQL rather than leaving it to callers, on the reasoning that a consumer who must remember to add a caveat will eventually forget. The three-state ladder is the same obligation, larger, so it is composed in the same place.
- **`fuel_types` already carries `min_plausible` and `max_plausible`** (RON grades ₱30–150, Kerosene ₱50–200). Plausibility is a lookup, not new data.

There is no client yet, so no consumer depends on the current shape of `get_stations_with_reference_prices`. This is the cheapest moment to change its reference source.

## Goals / Non-Goals

**Goals:**

- A read path that answers "what does this station charge" in one call, for one fuel type or all of them, with the kind of answer attached.
- A submission path that cannot be made to store a submitter's coordinates, even by a caller trying to.
- Derived prices computed rather than materialized, so a late or corrected adjustment repairs history instead of leaving it wrong.

**Non-Goals:**

- Where adjustments come from. This design consumes a `price_adjustments` row; `add-price-adjustment-feed` produces one.
- Any identity, device fingerprint, or session concept.
- Deciding how a client renders confidence. The read path supplies report count and age; presentation is the client's.

## Decisions

### Compute derived prices on read, not on a schedule

A derived price is the last observation plus every adjustment effective since it was observed:

```
observed  ₱85.00  Aug 30 14:00
  + adjustments where effective_at > Aug 30 14:00 and <= now()
  = derived   ₱86.50   (1 adjustment applied)
```

**Why not materialize.** A scheduled job that rewrites station prices each Tuesday needs to run exactly once per adjustment, needs to be re-runnable without double-applying, and leaves every row wrong until it does run. Computing on read has none of those failure modes: a late-published adjustment, a corrected delta, or a backfill all take effect immediately and retroactively, and the count of adjustments applied falls out of the same query rather than being tracked separately.

The cost is per-read work proportional to adjustments since the observation, which is bounded by the carry-forward limit below and is a handful of rows.

### Carry the baseline forward for at most 4 adjustments **or** 35 days, whichever comes first

The spec requires a limit; this picks one and says why it is two conditions rather than one.

Four adjustments is roughly a month of weekly cycles. Typical Philippine adjustments run ₱0.30–2.00 per litre, and the error in applying a national figure locally is a fraction of that, so accumulated error after four is well inside the ₱8–21 width of the locality range it would otherwise fall back to.

The wall-clock condition exists because **the adjustment count is only meaningful if adjustments are being ingested.** If the feed stops, no adjustments accrue, the count stays at zero, and a six-month-old observation would keep presenting itself as freshly observed. A feed outage must age observations out, not freeze them. 35 days is five cycles — long enough not to fire during a normal ingestion gap, short enough to catch a dead feed.

Both are configuration, not constants in a query.

### Proximity is verified server-side, and coordinates are an argument that never becomes a column

The client sends its coordinates, the chosen station, the fuel type, and the price to a single `SECURITY DEFINER` function. The function computes the distance, rejects if it exceeds the radius, and inserts a row holding the station, the price, the time, and a boolean verdict. The coordinates are never written.

**Why not check on the client.** A client that self-certifies "I am at station X" has performed no check. The verdict has to be produced by something the submitter does not control.

**Radius: 150 m.** A forecourt is roughly 100 m across and phone GPS is 5–20 m in the open and worse among tall buildings, so a tighter radius rejects people who are genuinely standing there. It does not need to be tight, because it is not identifying the station — the provider's own data puts competing brands 27–40 m apart, and 22 of 96 stations have a neighbour inside 100 m, so no workable radius could. The submitter chooses from the candidates in range.

Distance is computed with the equirectangular approximation already used elsewhere in this project rather than by adding PostGIS. At 150 m and 14°N the error is centimetres, and 96 rows do not need a spatial index.

### One read path, one row per station and fuel type, fuel type optional

```
get_station_prices(p_locality text, p_fuel_type text default null)
```

Passing a fuel type returns one row per station. Passing none returns one row per station per fuel type, which is what a station card showing four grades needs — otherwise it is four round trips, one per grade.

**A new function and a new composite type rather than extending the existing pair.** `ALTER TYPE ... ADD ATTRIBUTE` appends, so the existing `station_reference_result` cannot gain fields in a sensible order, and making `p_fuel_type` nullable on `get_stations_with_reference_prices` would remove the unrecognised-fuel-type error that function is specified to raise. The existing functions stay as they are, minus the reference-source change below.

### The kind of price, and the sentence that says so, are composed in SQL

`price_kind` becomes an enum (`observed`, `derived`, `reference`) and travels with a non-nullable basis sentence, exactly as `reference_basis` does today. A derived row's sentence names the observation it descends from, when that was, and how many adjustments were applied.

This follows the precedent set for absence reasons: the system states what a figure is, and a consumer cannot obtain the figure without the statement.

### The reference source moves from the brand row to the `OVERALL` row

`get_stations_with_reference_prices` keeps its signature and its contract; only the row it reads changes, along with its basis sentence. Two absence reasons — `brand_not_reported` and `brand_not_identified` — stop arising on the reference path, because the locality range does not consult a station's brand. They remain in the enum and remain correct wherever a brand is genuinely the subject.

### Adjustments are keyed to be idempotent

`price_adjustments` is unique on `(fuel_type_code, effective_at)`. An ingester that re-reads the same announcement, or two outlets reporting one adjustment, cannot apply it twice. Since derived prices are computed on read, a duplicate row would otherwise double every price in the app silently.

### Abuse control is proximity, plausibility, and a per-station rate cap

Without identity there is no per-person limit, so the cap is per station and fuel type — a small number of accepted reports per hour. It does not stop a determined spammer standing at a station; it bounds the rate at which one can churn the displayed value, and because reports are retained and newest-wins, the next honest report corrects it.

This is stated as V1's accepted position rather than a solution. Quorum is the answer when traffic supports it (see `proposal.md` — Explicitly out of scope).

## Intended trajectory

This is not V1 scope. It is recorded because it explains why the ladder has three rungs rather than two, and because the last paragraph is a standing instruction to a future maintainer.

**The reference rung is expected to go quiet, per cell, on its own.** As reports accumulate, a station and fuel type with a live observation never reaches the bottom of the ladder. That requires no migration and no switch — it is what the ladder already does. What it requires is volume:

```
96 stations x ~4 fuels each (once brand-fuel-products lands)   ~380 cells
each refreshed inside the carry-forward window                 ~28 days
--------------------------------------------------------------------
~14 reports/day, at a distribution reports will never have
```

Reports concentrate on busy stations and on RON 95 and Diesel, so covering the tail needs several times that. The practical consequence is that DOE recedes **unevenly and incompletely**: Taguig RON 95 may be crowd-covered within weeks while Malvar Kerosene never is. The fallback is permanent because the tail never fills.

**DOE's role does not end at full coverage; it moves to the frontier.** The day coverage extends to a fourth locality, that locality has no reports at all. The reference rung is what makes the app non-empty there on day one, so it is the expansion mechanism rather than only the bootstrap.

**What DOE is for changes shape, and the new shape is the important one.** As a gate on an individual report it is close to decorative — the locality ranges run ₱8–21 wide and `fuel_types.min_plausible`/`max_plausible` already reject what needs rejecting. Its real value appears precisely when it stops being displayed, because at that point the system is a closed loop:

```
observation --> + announced delta --> + announced delta --> displayed
     |________________ no external anchor _________________|
```

Every displayed figure is then downstream of the adjustment feed. A parser that reads a ₱1.20 adjustment as ₱0.12, or misses a rollback entirely, moves every price together, and no internal check can notice — they are all derived from the same wrong number. DOE is the only independent measurement of the same quantity.

So the useful comparison is aggregate rather than per-report: the median of crowd observations for a locality and fuel type against the midpoint of the DOE `OVERALL` range for that locality and fuel type, with divergence beyond a threshold treated as a signal that the feed, the parser, or the data is wrong.

**Therefore DOE ingestion is retained permanently, including after it stops being displayed.** A future maintainer who observes that no user-facing surface reads the DOE tables and concludes the ingestion is dead weight would be removing the only thing that can detect a systematic error in everything the app shows.

## Risks / Trade-offs

- **Coordinates could survive in Postgres logs even though no column holds them.** With `log_statement = 'all'` or `log_min_duration_statement` low, the submission call's arguments are written to the server log, which defeats the design's privacy property. → Verify logging settings on the hosted project, keep the submission call parameterized rather than string-interpolated, and treat this as part of the change rather than an operational afterthought.

- **A dead adjustment feed makes stale observations look current.** → The 35-day wall-clock condition on carry-forward. Also worth surfacing feed silence explicitly, per the discipline `distinguish-absent-doe-data` established.

- **A national delta is applied to every locality equally.** Regional differences exist and are usually small. → Bounded by the carry-forward limit; a fresh report resets the error to zero.

- **Mock location on a rooted device defeats the proximity gate.** → Accepted for V1 and stated in the proposal. The gate raises the cost of casual abuse, not determined abuse.

- **Reference coverage is thin.** The `OVERALL` row exists for only 8 of 21 locality and fuel-type combinations; three fuel types have none anywhere. → Not introduced by this change, and the absence vocabulary already reports it correctly. Worth knowing that many stations will show an explicit absence rather than a range until reports arrive — which is the honest state and the reason the app asks for reports.

- **Computing derived prices on read costs a scan of adjustments per row.** → Bounded by the carry-forward limit; at three localities and 96 stations this is negligible, and a materialized path can be added later without changing the contract.

## Migration Plan

1. `price_adjustments` and `price_reports` tables, RLS, and grants.
2. `price_kind` enum and the `station_price_result` composite type.
3. `submit_price_report(...)` — proximity check, plausibility check, rate cap, insert without coordinates.
4. `get_station_prices(...)` — the ladder, computed on read.
5. Change the reference source in `get_stations_with_reference_prices` from the brand row to `OVERALL`, and update its basis sentence.

Steps 1–4 are additive and carry no rollback risk. Step 5 changes an existing function's output; it has no consumers today, and reverting it is a single migration restoring the previous body.

## Open Questions

- **The per-station rate cap's actual number.** Any small value works for V1 and it can be tuned from observed traffic without touching the specs or the read path.
- **Whether report history is exposed to clients.** The spec requires reports be retained, not that they be readable. A price history view is a later, additive read path.

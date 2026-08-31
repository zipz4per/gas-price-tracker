# Price reports

What a station charges, where the number came from, and how a price gets in.

## One slot, four states

A station has one price slot per fuel type, filled from the highest rung
available. Every figure carries its kind and a sentence saying what it is; there
is no way to obtain the number without them.

| Kind | Meaning |
|---|---|
| `observed` | someone reported this price at this station |
| `derived` | an earlier report here, carried across announced price adjustments |
| `reference` | nobody has reported here — the DOE locality-wide range across all brands |
| *(null)* | no figure at all; `absence_reason` says why |

The sentence is composed in SQL, not by the caller. A consumer that has to
remember to add a caveat is a consumer that will eventually forget, which is the
same reasoning that put `reference_basis` inside the read path rather than in its
callers.

## Reading

```sql
-- every station in a locality, every fuel type
select * from get_station_prices('Lipa City');

-- one fuel type
select * from get_station_prices('Lipa City', 'RON_95');
```

Omitting the fuel type returns one row per station **per fuel type**, which is
what a station card showing several grades needs — otherwise it is one round trip
per grade. An unregistered locality or an unrecognised fuel type raises `22023`
(PostgREST answers 400); a registered locality with no stations returns an empty
set. Those are different answers on purpose.

`get_stations_with_reference_prices` still exists and still returns the DOE
figure alone, without the report rungs. Since 2026-08-31 its figure is the
**locality-wide range across all brands**, not the station's brand range.

### Derived prices are computed, never stored

A derived price is the last observation plus every adjustment effective since it
was observed, evaluated at read time. Nothing writes it down. A late-published
adjustment, a corrected amount, or a backfill therefore repairs every price
descending from it immediately, with no job to run and nothing to re-run safely.

## Submitting

Two calls. The first finds the stations you could be standing at; the second
takes the one you picked.

```sql
select * from stations_within_radius(13.9476, 121.1541);

select submit_price_report(
  p_station_id => '…',
  p_fuel_type  => 'RON_95',
  p_price      => 78.50,
  p_latitude   => 13.9476,
  p_longitude  => 121.1541
);
```

**Proximity authorizes a report; it cannot identify the station.** The provider's
own data puts competing brands 27–40 m apart — a Petron and a Shell 31 m apart, a
Petro Gazz and a Foxx 27 m apart — and gives 22 of 96 stations a neighbour inside
100 m, while phone GPS is 5–20 m in the open and worse among tall buildings. No
radius both admits an ordinary positioning error and resolves which forecourt
someone is on, so `stations_within_radius` returns every candidate and the
submitter chooses. It returns them even when there is only one: a caller that
sometimes auto-selects is a caller that will auto-select the wrong one.

A submission is rejected, with `22023` and a message naming the cause, when the
fuel type is unrecognised, the station is unregistered, the location is missing,
the device is outside the radius, the price is outside the fuel type's plausible
bounds, or the station has already taken its hourly allowance for that fuel.

`submit_price_report` is the **only** way a row reaches `price_reports`. Both
tables grant `anon` nothing but `select` and carry no write policy, so a client
cannot route around a check by inserting directly.

### The submitter's location is never stored

Coordinates are arguments. They are compared against a station's position, they
decide a boolean, and they are discarded. `price_reports` has no column that
could hold them — see the note at the top of its migration.

**One caveat, verified rather than assumed.** Successful calls are never logged
(`log_statement = ddl`, `log_min_duration_statement = -1` on both local and the
hosted project). Failing calls *are* logged, and what reaches the log depends on
how the call was written:

- **Bound parameters** — a PostgREST `rpc` call, which is what any client does —
  log no values. `log_parameter_max_length_on_error = 0` suppresses them.
- **Interpolated SQL** — building the statement as a string — writes the
  coordinates into the log verbatim.

So `log_parameter_max_length_on_error = 0` is load-bearing and should not be
raised, and nothing should ever build this call by string interpolation.

## The knobs

All four live in `price_report_settings`, one row:

```sql
select * from price_report_settings;
```

| Column | Default | What it controls |
|---|---|---|
| `proximity_radius_metres` | `150` | How near a device must be to report. Sized for a ~100 m forecourt plus a 5–20 m GPS error, not to identify the station. |
| `carry_forward_max_adjustments` | `4` | How many announced adjustments an observation may be carried across before it reverts to the reference range. About a month of weekly cycles. |
| `carry_forward_max_days` | `35` | The same limit measured on the clock. **Not redundant:** the adjustment count only advances while adjustments are being ingested, so if the feed stops it stays at zero and a months-old observation would keep presenting itself as freshly observed. |
| `station_fuel_reports_per_hour` | `6` | How many reports one station and fuel type accepts per hour. Without accounts there is no per-person limit; this bounds how fast anyone can churn one station's value. |

Change one with an `update`; nothing needs a migration and nothing caches them.

## What is not built yet

`price_adjustments` has no writer. `add-price-adjustment-feed` is the change that
ingests announcements and fills it. Until it lands the table stays empty, no
price is ever `derived`, and every observation ages out on
`carry_forward_max_days` alone.

There is no quorum. A single plausible report from a device at the station
becomes the displayed price, and confidence is carried by the report count and
age rather than by withholding data — 96 stations across 7 fuel types is 672
cells, and a corroboration threshold at launch volumes would suppress nearly
everything, hardest in the week after a price change when reports matter most.
Quorum is what to add when traffic supports it.

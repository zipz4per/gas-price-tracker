## Why

Everything this project has built is a read path nobody can read. Six capabilities, 52 migrations, prices that know what kind of claim they are — and no way for a driver to see any of it. The PRD's first user story opens with a list of stations and it has never been possible to satisfy.

It is possible now. `get_station_prices` returns every station in a locality with its current price, the kind of figure that price is, and the sentence saying what it is; a station with no figure comes back too, carrying the reason. For RON 95 across all three localities that is 96 rows — one screen's worth.

There is a second reason to build the screen rather than more backend. The rule this system is organised around — that a figure is never supplied without the statement of what it is — is enforced in SQL and *cannot* be enforced there against a client. `price_basis` is a non-nullable domain, so a consumer cannot obtain a price without receiving the sentence; nothing stops that consumer from dropping it on the floor and rendering a bare number. The screen is where that promise is either kept or quietly broken, and until one exists the guarantee is untested.

## What Changes

- **Introduce the client application**, as an Expo project exporting to native and to the web from one codebase. The web export is what makes the work visible: a public repository of migrations and specs has nothing a reader can click.
- **Ship one screen end to end** — choose a locality and a fuel type, see every station in it, ordered by distance where location is available.
- **Show the kind of every price, always.** Observed, derived, and reference are three different claims, and the screen displays the system's own sentence rather than composing its own. A bare figure with no statement of what it is must not be renderable.
- **Show stations with no price rather than hiding them.** For RON 95, 95 of 96 stations currently show a locality reference range and one shows an observed report; for RON 97 every station shows an explicit absence. A station missing from the list is worse than a station with nothing to say.
- **Order by distance when location is available, and stay useful when it is not.** Location is what distinguishes twelve Lipa Petrons that share a name; without it the list must still be ordered by something a person can navigate.
- **Read from the hosted project with the anon key**, which is public by design and ships in the bundle. The protection is the grants and RLS behind it, not the secrecy of that key — a distinction worth stating plainly because a key in a client bundle looks like a leak.

### Explicitly out of scope

- **The map.** The list comes first because it can be read, tested, and deployed without a mapping dependency or an API key. The map is the next change and this one gives it a data path.
- **Submitting a price.** The backend accepts one and the flow needs GPS authorization, a candidate picker, and the brand's product names; that is its own change.
- **Choosing a locality from GPS.** Nothing maps coordinates to a locality, and at three localities the client can fetch all of them and sort. A proximity read path earns its place when coverage grows, not now.
- **Offline behaviour and caching.** NFR-2 asks for a usable cached state; it is real work and does not belong in the first screen.
- **Design system, theming, and visual polish** beyond what the content requires.

## Capabilities

### New Capabilities

- `price-display`: What a person is shown when a price is displayed to them — that every figure states what kind of claim it is, that absence is rendered rather than hidden, that a station is never dropped from a list for having nothing to say, and what the screen must still do when location is unavailable.

### Modified Capabilities

None. Every read path this screen consumes is unchanged.

## Impact

- **New:** an Expo application at the repository root, with a web export target and a static deploy for it.
- **New:** a dependency on `@supabase/supabase-js`, and on Expo and React Native — the project's first runtime dependencies outside Postgres and Python.
- **New:** configuration carrying the Supabase URL and anon key, read from the environment and never committed. `.env.local` already holds hosted credentials and remains untracked; the service-role key must never reach the client, which is the one credential distinction that matters here.
- **Depends on:** `price-reports` for `get_station_prices`, `station-registry` for the stations it returns, and `locality-registry` for the localities offered.
- **Unblocks:** the map, the submission flow, and a README with something to link to.

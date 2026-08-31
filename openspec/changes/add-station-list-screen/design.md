## Context

See `proposal.md` — Why, and `specs/price-display/spec.md` for the behaviour required.

Three facts shape everything below.

**The read path already returns a finished row.** `get_station_prices(locality, fuel_type)` gives one row per station carrying the figure, its kind, the sentence describing it, the absence reason when there is no figure, the report count and age, the reference period, coordinates, and the OpenStreetMap attribution. The client computes almost nothing; it arranges what it is handed.

**The system's central guarantee stops at the network boundary.** `price_basis` is a non-nullable domain, so a caller cannot obtain a figure without receiving the statement of what it is. Nothing stops that caller from rendering the number and discarding the sentence. Postgres cannot enforce this; only the client's own structure can.

**Absence is the common case, not the edge.** Across the three localities and seven fuel types, 208 of 364 Lipa rows carry no figure at all, and for RON 95 — the best-covered fuel — 95 of 96 stations show a locality reference range rather than an observed price. A design that treats "has a price" as the main path and "no price" as an error state would be wrong about most of its own data.

## Goals / Non-Goals

**Goals:**

- A structure in which rendering a bare price is awkward rather than merely discouraged.
- One codebase producing a native app and a static site that can be linked from the repository.
- A screen that is correct with no location, no reports, and no reference data.

**Non-Goals:**

- A design system. Content first; the visual language can come when there is more than one screen to make consistent.
- Caching, offline state, and refresh policy. NFR-2 is real and is not this change.
- Any write path.

## Decisions

### Expo at the repository root, exporting to web

`npx create-expo-app` with TypeScript and `expo-router`. Native and web from one source, and `expo export --platform web` produces a static `dist/` that deploys anywhere.

**Why expo-router for one screen.** It is more than this screen needs and less than the next two will. It also gives the web export real URLs, which matters for something linked from a README — a single-route app with no addressable state is a screenshot with extra steps.

**At the root, not in a subdirectory.** Expo's tooling assumes it owns the root, and fighting that buys nothing at this size. `app/` becomes the router's route directory; the existing `openspec/`, `supabase/`, `scripts/` and `docs/` are untouched.

**Deploy to GitHub Pages via Actions.** The repository is already public GitHub, so this adds no account and no service. It serves from a subpath — `/gas-price-tracker/` — so the export needs its base URL set, and getting that wrong produces a blank page with working assets, which is a confusing failure worth knowing about in advance.

### One component owns the figure and its statement

This is the decision the whole change exists to make.

```
  <StationPrice row={row} />     the only thing that renders a price
```

It takes the whole result row, never a number. There is no prop for a figure alone, no formatter that accepts a `numeric`, and no path by which a call site can obtain a rendered price without the kind and the statement coming with it. A component that wants only the number has to reach past the one that exists, which is visible in review in a way that forgetting a caveat is not.

**Why structure rather than discipline.** The rule survived six capabilities in Postgres because a domain constraint enforced it. On the client nothing can, so the next best thing is a shape where breaking it takes deliberate effort. The alternative — a `formatPrice()` helper plus a convention that callers also render the basis — is exactly the arrangement the SQL comments have been arguing against all along: *a consumer who has to remember to add the caveat is a consumer who will eventually forget.*

The same component renders the absent case. A row with no figure is not a different component and not a branch at the call site; it is the same component displaying the reason instead of a number.

### Styling with NativeWind

React Native has no CSS, so Tailwind cannot be used directly. NativeWind is the
route to it: Tailwind class names compiled to React Native styles at build time,
working on native and on web from one source. That last property is why it fits
here — a codebase targeting both would otherwise style them separately, which is
the fork Expo was chosen to avoid.

**Adopted from the first component rather than later.** Two more screens are
already scoped — the map and the submission flow — and the submission flow is
the style-heavy one: forms, focus and disabled states, validation, a candidate
picker. Starting with `StyleSheet` and converting when that arrives means a
migration touching every component that renders anything, which is real work
avoided entirely by choosing once.

It also keeps the four price states legible where they matter. Observed,
derived, reference and absent must be distinguishable at a glance, and utility
classes put that difference in the markup beside the content it describes rather
than in a separate block a reader has to hold in their head.

**Three things this costs, recorded because they are facts rather than
arguments:**

Setup is five touchpoints — a Tailwind config with content globs, the Babel
preset, the Metro wrapper, a global stylesheet, and a TypeScript declaration
adding `className` to React Native components. All of it lands in project setup,
which is already the stretch of this change with the longest gap between starting
and having anything on screen.

Version alignment with the Expo SDK is the thing that actually breaks. NativeWind
majors track SDK ranges, so the version is taken from NativeWind's own
documentation against whatever `create-expo-app` installs — never pinned from
memory or copied from an older project.

Not all of Tailwind survives the translation. There is no `grid`, pseudo-classes
are limited, and there is no arbitrary-CSS escape hatch: what remains is
flexbox, spacing, colour, typography, and NativeWind's own additions. **A class
with no React Native equivalent is silently inert** — it does not warn, it does
nothing. On a first screen, where "nothing happened" already has several
plausible causes, that is worth knowing before it is met.

**`StyleSheet` remains available and is not forbidden.** The two coexist, and
anything Tailwind cannot express is written directly rather than approximated by
a class that does not apply.

### The anon key ships in the bundle, and that is correct

Configuration is read from `EXPO_PUBLIC_SUPABASE_URL` and `EXPO_PUBLIC_SUPABASE_ANON_KEY`. Expo inlines any `EXPO_PUBLIC_*` variable into the built bundle, which is exactly right for these two and exactly wrong for anything else.

**The rule, stated because the shape invites the mistake:** never give a secret an `EXPO_PUBLIC_` prefix. The anon key is a public identifier; what protects the database is the grants and RLS behind it — `anon` holds `select` on the read tables, no write policy exists, and `submit_price_report` is the only way a row reaches `price_reports`. The service-role key bypasses all of that and must never appear in client configuration, in a build environment, or in `app.config`.

`.env.local` already holds hosted credentials and stays untracked. The web export's build environment needs the URL and anon key only.

### Types generated from the database, not hand-written

`supabase gen types typescript` produces the row shape from the real schema, so a change to `station_price_result` breaks the build rather than the screen. Hand-written interfaces drift silently and would drift first on exactly the fields this design depends on.

### Distance is computed on the client, with the same formula

Each row carries `latitude` and `longitude`. Sorting happens client-side using the equirectangular approximation `distance_metres()` uses, so a distance shown on screen and a distance used by the proximity gate agree.

**Why not ask the database to sort.** The read path is per-locality and returns tens of rows; sending coordinates to sort them would make the client's location a server input for a query that does not need it, which is a privacy cost with no return.

### Location never blocks the list

The list renders as soon as rows arrive, ordered by brand and name. A location, if one arrives, reorders it. A refusal is a state the screen displays, not an error it reports.

```
  rows arrive          ─▶  list, ordered by brand and name
  location arrives     ─▶  reordered by distance, distances shown
  location refused     ─▶  list stays, ordering criterion stated
  location never comes ─▶  same as refused
```

**Why not request location first.** Location permission is refused often and permanently, and everything on this screen except ordering works without it. A screen that waits for a decision it may never get is broken for those users forever.

## Risks / Trade-offs

- **The client can still drop the statement.** The component makes it awkward; nothing makes it impossible. → Structure plus a test asserting the rendered output contains the statement for each kind. This is a weaker guarantee than the database's and is recorded as one.

- **A near-empty first impression.** For RON 95 the screen shows 95 locality ranges and one observed price; for RON 97 it shows explicit absence at every station. That is honest and it is not compelling. → It is also the argument for the submission flow being the next change: the screen visibly wants to be told something it does not know.

- **The anon key in a public bundle reads as a leak.** Anyone auditing the repository will see it and reasonably ask. → Stated in the proposal, in this design, and in the README when it exists. The check that matters is that `service_role` never appears anywhere near the client.

- **GitHub Pages serves from a subpath.** A wrong base URL yields a blank page with assets loading correctly, which is hard to diagnose from the symptom. → Set it explicitly and verify the deployed URL, not just the local export.

- **Expo and React Native are the project's first runtime dependencies outside Postgres and Python.** A supply chain arrives with them, and NativeWind adds Tailwind to it. → Accepted; it is the cost of a client existing at all.

- **A NativeWind version misaligned with the Expo SDK breaks the build before anything renders.** It is the most likely way project setup consumes a session. → Take the version from NativeWind's documentation against the SDK `create-expo-app` actually installs, and verify a styled component renders on both native and web before building anything on top of it.

- **A Tailwind class with no React Native equivalent does nothing, silently.** No warning, no error, no style. → Verify the four price states are visually distinguishable rather than assuming the classes applied, and fall back to `StyleSheet` for anything Tailwind cannot express rather than approximating it.

## Migration Plan

1. Expo app with TypeScript and expo-router at the repository root; `.gitignore` for `node_modules`, `dist`, `.expo`.
2. NativeWind, with its version taken from its own documentation against the installed SDK, verified rendering on native and web before anything is built on it.
3. Supabase client from `EXPO_PUBLIC_*` configuration, with a check that fails loudly when either variable is missing.
4. Generated database types, committed, with the command to regenerate them documented.
5. `StationPrice` — the only component that renders a figure, covering all four states.
6. The list screen: locality and fuel type selection, rows, distances, and the location states.
7. Web export and the GitHub Pages workflow; verify the deployed URL.

Nothing here changes the database, so there is no rollback beyond reverting the commit.

## Open Questions

- **Whether the fuel type selector shows all seven grades or only those with data.** Three fuel types have no figure anywhere; showing them is honest and showing an entirely empty list is a poor first experience. Deferrable — it changes a list of options, not the screen.
- **Where the deployed site lives long-term.** GitHub Pages is chosen for having no additional account; a custom domain or another host is a later decision that does not affect the code.

## Context

See `proposal.md` — Why, and `specs/price-display/spec.md` for the behaviour required.

Four facts shape everything below.

**The read path already returns a finished row.** `get_station_prices(locality, fuel_type)` gives one row per station carrying the figure, its kind, the sentence describing it, the absence reason when there is no figure, the report count and age, the reference period, coordinates, and the OpenStreetMap attribution. The client computes almost nothing; it arranges what it is handed.

**The system's central guarantee stops at the network boundary.** `price_basis` is a non-nullable domain, so a caller cannot obtain a figure without receiving the statement of what it is. Nothing stops that caller from rendering the number and discarding the sentence. Postgres cannot enforce this; only the client's own structure can.

**Absence is the common case, not the edge.** Across the three localities and seven fuel types there are 672 rows: 254 carry a locality reference range and 418 carry no figure at all. Not one is `observed` or `derived` — nobody has submitted a price report yet. A design that treats "has a price" as the main path and "no price" as an error state would be wrong about most of its own data, and a design that only exercises the states the live data happens to contain would ship two of the four untested.

**The same screen is a phone app and a web page.** One codebase exports to both, and the web export is what a reader clicks from the README. A layout tuned for a 390-point phone does not become a desktop page by being served in a browser — it becomes a phone app with a very wide margin.

## Goals / Non-Goals

**Goals:**

- A structure in which rendering a bare price is awkward rather than merely discouraged.
- One codebase producing a native app and a static site that can be linked from the repository.
- A screen that is correct with no location, no reports, and no reference data.
- A layout that answers to the window it is in, on one code path, without a native/web fork.

**Non-Goals:**

- A design system. Content first; the visual language can come when there is more than one screen to make consistent.
- Caching, offline state, and refresh policy. NFR-2 is real and is not this change.
- Any write path.

## Decisions

### Expo at the repository root, exporting to web

`npx create-expo-app` with TypeScript and `expo-router`. Native and web from one source, and `expo export --platform web` produces a static `dist/` that deploys anywhere.

**Why expo-router for one screen.** It is more than this screen needs and less than the next two will. It also gives the web export real URLs, which matters for something linked from a README — a single-route app with no addressable state is a screenshot with extra steps.

**At the root, not in a subdirectory.** Expo's tooling assumes it owns the root, and fighting that buys nothing at this size. Application code lives under `src/`, with `src/app/` as the router's route directory; the existing `openspec/`, `supabase/`, `scripts/` and `docs/` are untouched.

**`src/app/` is a route directory, and that has a consequence worth stating.** Every file in it becomes a public page. A colocated `index.test.tsx` is not a test beside its component — it is a route, exported to `dist/index.test/` and served to anyone who visits it. Tests for screens live in `src/__tests__/` and import the screen by path. This is the kind of rule that is obvious once it has bitten and invisible before.

**Deploy to GitHub Pages via Actions.** The repository is already public GitHub, so this adds no account and no service. It serves from a subpath — `/gas-price-tracker/` — so the export needs `expo.experiments.baseUrl` set, and getting that wrong produces a blank page with working assets, which is a confusing failure worth knowing about in advance.

### One component owns the figure and its statement

This is the decision the whole change exists to make.

```
  <StationPrice row={row} />     the only thing that renders a price
```

It takes the whole result row, never a number. There is no prop for a figure alone, no exported formatter that accepts a `numeric` — the peso formatter is module-private and deliberately unexported — and no path by which a call site can obtain a rendered price without the kind and the statement coming with it. A component that wants only the number has to reach past the one that exists, which is visible in review in a way that forgetting a caveat is not.

**Why structure rather than discipline.** The rule survived six capabilities in Postgres because a domain constraint enforced it. On the client nothing can, so the next best thing is a shape where breaking it takes deliberate effort. The alternative — a `formatPrice()` helper plus a convention that callers also render the basis — is exactly the arrangement the SQL comments have been arguing against all along: *a consumer who has to remember to add the caveat is a consumer who will eventually forget.*

The same component renders the absent case. A row with no figure is not a different component and not a branch at the call site; it is the same component displaying the reason instead of a number. The four states are chosen by `row.price_kind ?? 'absent'`, so the absent case is not a fifth thing bolted on — it is what the row's own null means.

**Two of the four states have no live data.** Nothing in the hosted project is `observed` or `derived` today. They are exercised by tests over hand-built rows, which is the only way they can be exercised before the submission flow exists, and is the reason the tests assert the supplied statement appears for *each* kind rather than for whatever the database currently returns.

### Styling with `StyleSheet`

React Native has no CSS, so Tailwind cannot be used directly. The route to it is
NativeWind, which compiles Tailwind class names into React Native styles at build
time. It is not being used, and this records why and what would change the
answer.

The whole styling surface of this screen is small enough to see at once:

```
  row / card   flexDirection, padding, and an edge — a hairline or a border
  figure       fontSize, tabular numerals
  observed / derived / reference / absent    a colour and a weight each
  basis        smaller, dimmer, beneath the figure
```

Four price states, a row, and the same row with different edges. A utility
framework earns its place by making consistency cheap across many surfaces, and
there is one here.

**What it would cost is concentrated in the riskiest place.** NativeWind needs a
Tailwind config, a Babel preset, a Metro wrapper, a global stylesheet and a
TypeScript declaration — five touchpoints, all in project setup, which is already
the stretch of this change with the longest gap between starting and having
anything on screen. It must also align with whatever Expo SDK
`create-expo-app` installs, and a mismatch there fails the build with an error
that names a file in the toolchain rather than the version that caused it.

**And it introduces a translation layer that fails quietly.** React Native
understands only part of Tailwind's vocabulary — there is no `grid`,
pseudo-classes are limited, and there is no arbitrary-CSS escape hatch. A class
with no equivalent is **silently inert**: no warning, no error, no style, just a
missing instruction the build never mentions. On a first screen, where "nothing
happened" already has several plausible causes, that is a poor property to add.

`StyleSheet` has neither problem. It is built in, so there is no version to align
and no dependency to add, and it expresses exactly what React Native supports —
nothing is quietly dropped in translation.

**NativeWind can be adopted later, incrementally.** It coexists with
`StyleSheet` and applies per component, so this is not a door closing. What
follows is when to walk through it, stated as triggers someone can actually
notice rather than as a feeling about repetition.

**The moment you are about to write `theme.ts`.** A module exporting colours and
spacing, imported everywhere, is a design system — a worse Tailwind, built by
hand, with no tooling, no autocomplete, and a config nobody else maintains. If
that file is about to exist, the decision has already been made; NativeWind is
the same decision with the work done. This trigger is self-detecting, which is
why it is first: you notice yourself creating the file.

**Or: the same literal style value in three or more `StyleSheet.create` blocks.**
Greppable, unlike the above. Two is coincidence; three is a system asking to
exist.

**The likely moment is the submission flow.** This screen is one component doing
four states plus a row. The map is mostly a library's surface. The submission
flow is the first with forms, focus and disabled states, validation, and a
candidate picker — and the first where copying styles out of here becomes
tempting. If that change finds itself reaching back into this one's styles, that
is the answer arriving.

**When it lands, it is its own change.** Adopting NativeWind touches build
configuration and every component that renders anything; reviewed alongside new
behaviour, neither is legible. A change that does only this can be verified by
the app looking identical afterwards, which is the strongest available test for a
styling migration and impossible if features moved at the same time.

**And the answer may be never.** Utility CSS pays back on breadth. If this stays
at two or three simple screens, `StyleSheet` carries it indefinitely and nobody
suffers.

### The layout answers to the window, not to the platform

The export is a page in a browser as much as it is an app on a phone. Stretching
a phone list across a 1400-pixel window gives every station a line of text with
two thirds of the screen to itself, which reads as an unfinished port rather than
a design. The screen therefore has a layout that varies, and the variable is the
window's width.

```
  narrow   ─▶  1 column, full-bleed rows separated by hairlines
  wider    ─▶  2 columns of bordered cards
  widest   ─▶  3 columns, capped at 1180pt of content
```

**A minimum card width, not device breakpoints.** `columnsFor(width)` in
`src/lib/grid.ts` divides the usable width by a minimum card width of 330pt and
takes as many columns as fit, up to three. What decides whether two stations
belong side by side is whether a name, a distance, a figure and the sentence
describing that figure stay readable together — a property of the content, not of
anyone's device. Breakpoints named after phones and tablets encode a guess about
hardware; a minimum width encodes the actual constraint, and it keeps working in
a half-width browser window, which no device breakpoint list covers.

**Three columns is the ceiling, and 1180pt is the content cap.** Past three, a
row of cards stops being a list and becomes a wall; past ~1180pt of content, the
eye has to travel further between a station's name and its price than between
two different stations.

**Fixed card widths rather than `flex: 1`.** The last row of a grid is usually
not full — 52 stations in three columns leaves one station alone on the final row
— and a flexed card there stretches to three times the width of every other card
on screen. `cardWidthFor` returns an explicit width for multi-column layouts and
`undefined` for one column, where a full-bleed row has no width of its own.

**A card and a row differ in their edges, not in what they say.** `StationRow`
takes `layout` and `width` from the list and changes only its container: a
hairline bottom border in a single column, a bordered rounded card in a grid.
Same children, same `StationPrice`, same content in both. Nothing is hidden at
narrow widths, so there is no "mobile version" of the information.

**The header and the attribution are pinned, not scrolled.** The locality and
fuel selectors and the sentence stating the current ordering sit above the list
rather than inside it; the OpenStreetMap attribution sits below. Two reasons.
The selectors are how you change what the list is showing, and a control that
scrolls away is a control you have to hunt for after scrolling 52 rows. And the
attribution is a licence obligation that ODbL attaches to the display of the
data — pinning it means it is on screen whenever station data is, rather than
only for a reader who reaches the bottom.

**React Native forces a remount when the column count changes.** `FlatList`
rejects a changed `numColumns` on a live list, so the list carries a key derived
from the column count and is rebuilt when the window crosses a threshold. That
resets scroll position on resize. Accepted: resizing a window is rare on the
web and impossible on a phone, and the alternative is a hand-rolled grid that
gives up virtualization for the 52 rows of the largest locality.

**Native is unaffected.** Every phone width resolves to one column, which is the
layout that already existed. There is no platform branch anywhere in this — the
same code produces both, and the web layout is not a fork to keep in sync.

### The anon key ships in the bundle, and that is correct

Configuration is read from `EXPO_PUBLIC_SUPABASE_URL` and `EXPO_PUBLIC_SUPABASE_ANON_KEY`. Expo inlines any `EXPO_PUBLIC_*` variable into the built bundle, which is exactly right for these two and exactly wrong for anything else.

**The rule, stated because the shape invites the mistake:** never give a secret an `EXPO_PUBLIC_` prefix. The anon key is a public identifier; what protects the database is the grants and RLS behind it — `anon` holds `select` on the read tables, no write policy exists, and `submit_price_report` is the only way a row reaches `price_reports`. The service-role key bypasses all of that and must never appear in client configuration, in a build environment, in `app.config`, or in the deploy workflow.

**Inlining is a syntactic rewrite, and this is the sharp edge.** Expo's Babel transform replaces the literal expression `process.env.EXPO_PUBLIC_NAME` with the value. It does not read the environment at runtime and it does not follow indirection. `process.env[name]`, a destructured `const { EXPO_PUBLIC_SUPABASE_URL } = process.env`, or any helper that takes the *name* and looks it up will compile to a lookup against an object that is empty in the bundle — and it will do so **silently**. The dev server has a real `process.env` and works; the export does not and ships a bundle with no credentials in it, failing at first request with an error about a URL rather than about configuration. Every reference must therefore be the literal member expression, written out in full at the call site; a helper may take the resulting *value*, never the name.

`.env.local` already holds hosted credentials, including a service-role key, and stays untracked. The web export's build environment needs the URL and anon key only, and the deploy workflow supplies them as repository *variables* — it contains no `secrets.` reference at all, which makes "no secret is involved here" checkable by reading the file.

### Types generated from the database, not hand-written

`supabase gen types typescript` produces the row shape from the real schema, so a change to `station_price_result` breaks the build rather than the screen. Hand-written interfaces drift silently and would drift first on exactly the fields this design depends on.

**The generator does not understand domains.** `price_basis` is a domain over `text`, and the generator emits `unknown` for it — which is the one field this entire design is organised around, and `unknown` cannot be rendered. The row type is therefore the generated composite with that single field narrowed to `string` by hand, in one place, with the reason recorded there. Narrowing one field is a smaller lie than hand-writing the whole shape, and it stays honest because everything else still regenerates.

### Distance is computed on the client, with the same formula

Each row carries `latitude` and `longitude`. Sorting happens client-side using the equirectangular approximation `distance_metres()` uses, so a distance shown on screen and a distance used by the proximity gate agree.

**Pinned to the database, not re-derived from it.** The client formula is not a second implementation of "distance between two points" — it reproduces the SQL exactly, including the detail that the cosine is taken at the *first* latitude, which makes the function deliberately asymmetric. A textbook-correct symmetric version would be a better distance function and a worse match, and matching is the whole point. It is verified against values read from `distance_metres()` on the hosted project rather than against an independent formula.

**Why not ask the database to sort.** The read path is per-locality and returns tens of rows; sending coordinates to sort them would make the client's location a server input for a query that does not need it, which is a privacy cost with no return.

### Location never blocks the list

The list renders as soon as rows arrive, ordered by brand and name. A location, if one arrives, reorders it. A refusal is a state the screen displays, not an error it reports.

```
  rows arrive          ─▶  list, ordered by brand and name
  location arrives     ─▶  reordered by distance, distances shown
  location refused     ─▶  list stays, ordering criterion stated
  location never comes ─▶  same as refused
```

The hook has exactly those four states — `pending`, `available`, `declined`, `unavailable` — and the screen never awaits it. Each state has its own sentence in the pinned header, so the ordering in use is always stated rather than inferred from whether distances happen to be visible.

**Why not request location first.** Location permission is refused often and permanently, and everything on this screen except ordering works without it. A screen that waits for a decision it may never get is broken for those users forever.

### Every registered fuel type is offered, and the screen opens on RON 95

All seven registered grades appear in the selector. Hiding the ones with no data would make the app quietly disagree with the registry, and "this grade has no data" is a true and useful thing for the screen to say — it is the same claim the absent state exists to make.

Opening on one of them would be a poor first impression, so the opening grade is RON 95, the best-covered one, falling back to the first registered grade if it ever leaves the registry. The distinction is between what is *offered* and what is *shown first*; only the second needs an opinion.

## Risks / Trade-offs

- **The client can still drop the statement.** The component makes it awkward; nothing makes it impossible. → Structure plus a test asserting the rendered output contains the statement for each kind. This is a weaker guarantee than the database's and is recorded as one.

- **An empty-handed first impression.** Every price on the screen today is a locality reference range or an explained absence; there is not one observed report in the system. That is honest and it is not compelling. → It is also the argument for the submission flow being the next change: the screen visibly wants to be told something it does not know.

- **Two price states ship unexercised by real data.** `observed` and `derived` are covered only by tests over constructed rows. → Their rendering will meet real data for the first time when the submission flow lands, and that change should verify them against it rather than assuming this one did.

- **The anon key in a public bundle reads as a leak.** Anyone auditing the repository will see it and reasonably ask. → Stated in the proposal, in this design, and in `docs/frontend.md`. The check that matters is that `service_role` never appears anywhere near the client, and it is a grep over the built bundle, not a claim.

- **GitHub Pages serves from a subpath.** A wrong base URL yields a blank page with assets loading correctly, which is hard to diagnose from the symptom. → Set it explicitly and verify the deployed URL, not just the local export.

- **The grid remounts the list on a column change.** Scroll position resets when a browser window crosses a threshold. → Accepted; the alternative costs virtualization for a case that happens rarely and never on a phone.

- **Expo and React Native are the project's first runtime dependencies outside Postgres and Python.** A supply chain arrives with them. → Accepted; it is the cost of a client existing at all, and no styling dependency is added on top of it.

## Migration Plan

1. Expo app with TypeScript and expo-router at the repository root, code under `src/`; `.gitignore` for `node_modules`, `dist`, `.expo`.
2. Supabase client from literal `EXPO_PUBLIC_*` references, with a check that fails loudly when either variable is missing.
3. Generated database types, committed, with `price_basis` narrowed and the regeneration command documented.
4. `StationPrice` — the only component that renders a figure, covering all four states.
5. The list screen: locality and fuel type selection, rows, distances, and the location states.
6. The window-driven layout: `grid.ts`, the card/row variants, the pinned header and attribution.
7. Web export and the GitHub Pages workflow; verify the deployed URL and grep the deployed bundle.

Nothing here changes the database, so there is no rollback beyond reverting the commit.

## Open Questions

- **Where the deployed site lives long-term.** GitHub Pages is chosen for having no additional account; a custom domain or another host is a later decision that does not affect the code.
- **Whether the locality selector survives a fourth locality.** Three fit in a pinned row of chips. A dozen do not, and at that point the choice is a picker or a proximity read path — the latter being the thing this change explicitly deferred. Nothing to decide until coverage grows.

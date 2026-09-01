## 1. Project setup

- [x] 1.1 Create an Expo app with TypeScript and expo-router at the repository root; verify `npx expo start` runs and that `openspec/`, `supabase/`, `scripts/` and `docs/` are untouched
- [x] 1.2 Add `node_modules`, `dist`, `.expo` and Expo's generated artefacts to `.gitignore`; verify `git status` is clean after an install and a web export
- [x] 1.3 Add `@supabase/supabase-js` and a client built from `EXPO_PUBLIC_SUPABASE_URL` and `EXPO_PUBLIC_SUPABASE_ANON_KEY`, failing loudly at startup when either is missing; verify the failure message names the missing variable rather than surfacing as a network error later
- [x] 1.4 Verify no variable holding a secret carries an `EXPO_PUBLIC_` prefix, and that the service-role key appears nowhere in the app source, `app.config`, or any build configuration
- [x] 1.5 Generate database types with `supabase gen types typescript`, commit them, and document the regeneration command; verify the generated `station_price_result` shape matches the function's actual columns
- [x] 1.6 Narrow `price_basis` by hand where the generator emits `unknown` for the domain, recording why at the narrowing; verify the field is renderable and that every other field still comes from the generator
- [x] 1.7 Reference each `EXPO_PUBLIC_` variable as a literal `process.env.NAME` expression rather than a dynamic lookup, since inlining is a syntactic rewrite that fails silently; verify by grepping the built bundle for the project ref and the anon key, not by the dev server working

## 2. The price component

- [x] 2.0 Style with `StyleSheet` and add no styling dependency; verify the four price states are visually distinguishable from one another and that no Tailwind or NativeWind package is installed
- [x] 2.1 Implement `StationPrice`, taking a whole result row and rendering the figure, its kind, and the supplied statement together; verify no prop accepts a bare figure and no exported helper formats a price on its own
- [x] 2.2 Render the observed case with its report count and how recently it was observed; verify the age is shown relative to now and the count accompanies it
- [x] 2.3 Render the derived case so it reads as carried forward rather than observed, with the observation's date available; verify the wording is the statement the read path supplied and not composed by the component
- [x] 2.4 Render the reference case as a range across the locality, carrying the proxy attribution where one applies; verify a Malvar station names Tanauan City as the source
- [x] 2.5 Render the absent case in the same component, showing the supplied reason and no numeric value; verify nothing displays a zero, a blank, or an em dash where a price would be
- [x] 2.6 Add a test asserting that for each of the four states the rendered output contains the statement the row supplied; verify the test fails if the statement is removed from the component

## 3. The list screen

- [x] 3.1 Fetch a locality and fuel type through `get_station_prices` and render one row per station; verify Lipa City with RON 95 renders 52 rows and that none is filtered out
- [x] 3.2 Display the locality and fuel type currently in view, and offer selection among the covered localities and registered fuel types; verify only the three covered localities are offered
- [x] 3.3 Render every station including those with no figure; verify RON 97 in Lipa City renders all 52 stations, each showing why no price is available, and that the screen is not shown as empty or as an error
- [x] 3.4 Order by brand and name before any location is known, and state the criterion in use; verify the list renders before a location request resolves
- [x] 3.5 Request location without blocking, and reorder by distance when it arrives, showing each station's distance; verify the twelve Lipa Petron stations become distinguishable by distance
- [x] 3.6 Handle a declined or unavailable location as a displayed state rather than an error; verify the list is complete, the ordering criterion is stated, and the absence of distances is explained
- [x] 3.7 Compute distance with the same equirectangular formula the proximity gate uses; verify a distance shown on screen matches `distance_metres()` for the same pair of points
- [x] 3.8 Display the OpenStreetMap attribution the rows carry; verify it appears on any screen showing station data, as ODbL requires
- [x] 3.9 Keep screen tests outside `src/app`, where every file becomes a public route; verify the web export produces only the intended routes and no test page among them

## 4. The layout

- [x] 4.1 Decide the column count from the window's width against a minimum card width rather than device breakpoints; verify the rule is a pure function testable without a window and that a half-width browser window resolves as sensibly as a phone
- [x] 4.2 Give each card an explicit width instead of flexing it; verify the single station on an unfilled final row is the same width as every other card
- [x] 4.3 Render the same content as a full-bleed row in one column and a bordered card in a grid; verify a card and a row differ only in their edges and that nothing is hidden at narrow widths
- [x] 4.4 Pin the selectors, the ordering statement, and the OpenStreetMap attribution outside the scrolling list; verify the attribution is on screen with the first row rather than only at the bottom
- [x] 4.5 Remount the list when the column count changes, since `numColumns` cannot change on a live one; verify a resize across a threshold relays rather than warning or leaving the old column count
- [x] 4.6 Verify every phone width resolves to one column and that no platform branch exists — the web layout and the native layout are the same code path

## 5. Deploy

- [x] 5.1 Produce a web export with `expo export --platform web` and the base URL set for a GitHub Pages subpath; verify the export loads from that subpath rather than only from the local root
- [x] 5.2 Add a GitHub Actions workflow publishing the export to Pages, with the Supabase URL and anon key supplied from repository configuration; verify the workflow does not reference the service-role key
- [ ] 5.3 Verify the deployed site loads real data from the hosted project, and that the deployed URL — not just the local export — renders the list
- [x] 5.4 Verify the deployed bundle contains the anon key and does not contain the service-role key, by searching the built assets for both

## 6. Documentation

- [x] 6.1 Document how to run the app locally and what configuration it needs; verify a reader can start it without reading the source
- [x] 6.2 Record why the anon key is in the bundle and what actually protects the database, alongside the rule that no secret takes an `EXPO_PUBLIC_` prefix; verify the note names the grants and RLS rather than asserting the key is unimportant

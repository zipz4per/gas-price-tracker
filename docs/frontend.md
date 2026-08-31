# The app

An Expo project at the repository root: one codebase producing a native app and
a static web export. Today it shows one screen — every station in a locality
with what the system can say about the price of one fuel type there.

## Running it locally

```bash
npm install
npm start          # then press w for web, i for iOS, a for Android
npm run web        # or straight to the browser
npm test           # the test suite
```

Node 22 or newer. Everything else comes from `npm install`.

### Configuration

Two variables, both read from `.env.local` at the repository root, which Expo
loads automatically and which is untracked:

| Variable | What it is |
|---|---|
| `EXPO_PUBLIC_SUPABASE_URL` | the project's REST endpoint |
| `EXPO_PUBLIC_SUPABASE_ANON_KEY` | the anon key — public by design, see below |

Missing either one fails at startup with a message naming the variable, rather
than surfacing later as a network error nobody can place.

**Reference them literally.** Expo inlines an `EXPO_PUBLIC_*` variable by
rewriting the expression `process.env.EXPO_PUBLIC_NAME` during the build. It is
a syntactic substitution, so a dynamic lookup — `process.env[name]` — is
invisible to it and survives into the bundle as a read of an object that is
empty in a browser. That works in development, where the variables really are in
the environment, and fails only in the built app, where it presents as missing
configuration rather than a missing transform.

## Layout

```
  src/app/          expo-router's route directory — every file here becomes a URL
  src/components/   StationPrice, StationRow, ChoiceRow
  src/lib/          the Supabase client, the read paths, distance, the location hook
  src/__tests__/    tests for anything in src/app, which cannot hold its own
```

A test file placed beside a screen in `src/app/` exports as a real page and
ships in the build. Tests for routes live in `src/__tests__/` for that reason;
everything else is colocated.

### `StationPrice` is the only thing that renders a price

It takes a whole result row and never a number. There is no prop for a bare
figure and no exported formatter that accepts one, so a call site cannot put a
price on screen without the kind of claim it is and the sentence describing it
coming with it.

The database enforces this up to the network boundary — `price_basis` is a
non-nullable domain, so a caller cannot obtain a figure without receiving the
statement — and cannot enforce it one step further. The component's shape is
what carries the rule the rest of the way, together with a test asserting the
statement is rendered in each of the four states.

## Regenerating the database types

`src/lib/database.types.ts` is generated, not written. A change to
`station_price_result` should break the build rather than the screen.

```bash
# against the local stack
supabase gen types typescript --local > src/lib/database.types.ts

# against the hosted project
supabase gen types typescript --project-id "$SUPABASE_HOSTED_PROJECT_REF" \
  > src/lib/database.types.ts
```

Run it after any migration that touches a table, function, or composite type the
app reads, and commit the result.

One narrowing is applied by hand, in `src/lib/stationPrices.ts`: the generator
emits `unknown` for domain types, so `price_basis` arrives untyped. It is
narrowed to `string`, which is what the non-nullable domain actually guarantees.

## The web export and the deploy

```bash
npx expo export --platform web    # writes dist/
```

GitHub Pages serves this repository from `/gas-price-tracker/`, so the export
sets `expo.experiments.baseUrl` in `app.json` to match. Getting that wrong
produces a blank page with every asset loading correctly, which is difficult to
read backwards from the symptom — verify the deployed URL, not just a local
`dist/`.

`.github/workflows/deploy-web.yml` builds and publishes on every push to `main`.
It reads the two variables from **repository variables**, not secrets:

```
Settings → Secrets and variables → Actions → Variables
  EXPO_PUBLIC_SUPABASE_URL
  EXPO_PUBLIC_SUPABASE_ANON_KEY
```

## Why the anon key is in a public bundle

Because it is a public identifier, and treating it as a secret would misdescribe
what protects the data.

Every `EXPO_PUBLIC_*` variable is inlined into the built bundle, so anyone who
loads the site can read the anon key. That is how a Supabase client is meant to
work. What stands between that key and the database is not its secrecy:

- `anon` holds `select` on the read tables and nothing more. There is no write
  policy on any of them.
- Row-level security is enabled, with read policies only.
- `submit_price_report` is the single path by which a row reaches
  `price_reports`, and it is `security definer` — its checks are unavoidable
  because there is no route around it.

So the key identifies a caller; the grants and the policies decide what that
caller can do. Rotating it would change the identifier and none of the
protection.

**The service-role key is a different thing entirely.** It bypasses row-level
security completely. It must never take an `EXPO_PUBLIC_` prefix, never appear
in `app.json` or any build configuration, and never be added to the deploy
workflow — anything that workflow can read reaches a public bundle. `.env.local`
holds one, which is exactly why the prefix rule matters there.

To check a build:

```bash
grep -c "$EXPO_PUBLIC_SUPABASE_ANON_KEY" dist/_expo/static/js/web/*.js   # expect 1
grep -c "service_role" dist/_expo/static/js/web/*.js                     # expect 0
```

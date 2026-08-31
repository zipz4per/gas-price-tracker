# Brand review

Two questions about brands go stale in different ways, and each has its own view.

| Question | Surface | Cadence |
|---|---|---|
| **Which brand is this station?** | `stations_needing_brand_review` | Whenever an import surfaces a name no rule resolves |
| **Does this brand's product list still match its signage?** | `brands_needing_product_review` | Every 180 days |

The first is answered by adding a rule or recording why a name stays unresolved.
The second is answered by opening the brand's own site and comparing its lineup.

---

## Which brand is this station?

Stations whose provider name resolved to no registered brand:

```sql
select * from stations_needing_brand_review;
```

**A non-empty list is the normal state, not a failure.** The rules surface what
they cannot resolve rather than guessing, because a station filed under the wrong
brand is labelled as a brand it is not, and a station dropped for being
unrecognised is a hole in the map with nothing to indicate it. So an unresolved
station is registered, shown, and listed here.

> Corrected 2026-08-31 by `add-price-reports`. A wrong brand no longer produces a
> wrong *price*: a station's reference figure is the locality-wide range across
> all brands, so it does not consult the station's brand at all. The consequence
> of a wrong brand is a wrong **label**, and — since `add-brand-fuel-products` —
> the wrong **product names** on the submission form.

Each entry is settled one of two ways: **add a rule**, or **record why it stays
unresolved**.

## Settled 2026-08-31

The first import surfaced 36 names matching no major brand. Thirty-one were real
regional retailers DOE does not monitor, and each got an explicit rule to
`INDEPENDENT` — one rule per trade name, never a fallback, so a station reaches
that brand because someone recognised the name:

```
  Uno Fuel      Flexfuel     RePhil        Astral Fuel   Gasso      BM Gas
  EcoOil        BB Gas       Petro Gazz    Gazz          Maxfill    Smartfuels
  Equator       Nitro        Global Oil    N Energy      Hanz Fuels Argon Fuel
  Fuel Express  Rojan Fuel Express         FAB Gas       Felimon Magpantay
```

Five remain, and they are irreducible rather than missing rules.

### Four stations with no name at all

```
  way/798608214    Lipa City   amenity=fuel and nothing else
  way/1323985748   Lipa City   amenity=fuel and nothing else
  way/1135309652   Lipa City   fixme=name; the mapper's own note reads
                               "2023-01. Needs validation. Very likely a gas
                               station, based on layout from current imagery."
  way/1499707495   Lipa City   has an address and building=roof, but no name
```

**Recorded as unresolvable, not excluded.** No rule can ever reach a station
with no identifying text, so these are not waiting on maintenance here. They are
returned as pins with an unknown brand and no reference price — precisely the
third state the read path exists to express, arriving on the first import rather
than as a hypothetical.

`way/1135309652` is worth noting: a contributor flagged their own entry as
unvalidated. The remedy for all four is upstream — survey them and add the name
to OpenStreetMap, which the ODbL share-alike terms make the natural place for it
anyway. A rule invented here would assert something nobody has checked.

### One probable upstream mis-tag

```
  node/6337145236  Taguig City   name="Solane Factory", amenity=fuel, no other tags
```

Solane is an LPG (cooking gas) brand, and a *factory* is a filling plant rather
than a retail forecourt. This is most likely tagged `amenity=fuel` in error.

**Left registered with no brand, deliberately.** Excluding it would mean the
import deciding that the provider is wrong about what a place is, which is the
same class of inference this design refuses everywhere else — we do not infer
station existence from DOE, and we should not infer station non-existence from a
name either. It carries no brand, so it shows no reference price, which is the
mildest form the mistake can take. If someone surveys it and confirms it is not
a forecourt, the fix belongs in OpenStreetMap.

## Adding a rule

```sql
insert into brand_name_rules (brand_code, pattern, note) values
  ('INDEPENDENT', '\yexample\s+fuels?\y', 'Regional retailer, not DOE-monitored.');
```

Then re-run `python3 scripts/import-stations.py`; the upsert recomputes
`brand_code` for every station.

Patterns are case-insensitive POSIX regex matched against the provider's brand
tag, then operator, then name — stopping at the first field that matches
anything. Use `\y` word boundaries: without them a rule for `petron` would claim
"Petro Gazz". Two different brands matching one string resolves to null and
comes back here, which is the intended outcome rather than a bug.

---

## Does this brand's product list still match its signage?

```sql
select * from brands_needing_product_review;
```

Brands whose lineup has never been checked, or was last checked more than **180
days** ago. Rebrands and product renames run on a scale of years, so a shorter
interval produces review work with nothing to find — and reviews that reliably
find nothing stop being done.

A brand's products are what the submission form and every price label are
rendered from. A driver at a Petron reads "XCS" off the canopy, not "RON 95", so
the form asks in the brand's words while storing the grade. When a lineup goes
stale the app asks about a product the station no longer sells, and **nothing
detects that on its own** — a wrong product name reads exactly like a right one.
That is the whole reason this view exists.

### Reviewing one

Open the brand's own published product page. Not a third-party summary, not
memory: a wrong entry is indistinguishable from a right one to anyone reading the
table later, so the source and the date are recorded with the answer.

```sql
update brands
   set products_verified_at = now(),
       products_source_url  = 'https://www.example.com/products/'
 where code = 'EXAMPLE';
```

Three things to check, in order:

1. **Does every product still exist?** A retired grade leaves a form field
   nobody can fill.
2. **Is anything missing?** A fuel type with no entry is one the app treats as
   not sold there, and it cannot receive a price report at that brand's
   stations.
3. **Is the order still the canopy's order?** The list is presented as the brand
   presents it, not by octane, so a reader does not have to translate.

Add or correct entries in `brand_fuel_products`. The `sort_order` is unique per
brand, so reordering means moving both rows.

### When a lineup cannot be sourced

Leave the brand with no entries and record why. A station of a brand with no
catalogue falls back to canonical grade names — the same path an unbranded
station takes — which is a supported surface rather than a degradation. Inventing
a lineup to fill the gap is the one thing not to do.

### Three naming surfaces, and which to edit

Brand naming is spread across three hand-curated lists. They go stale for
different reasons and are edited for different reasons, so the question is
always "what changed in the world?" rather than "which table looks relevant?"

| What changed in the world | Edit |
|---|---|
| **A brand renamed itself** — Total became TotalEnergies | `brand_name_rules`: widen the pattern so it matches the old and new spellings. `brands.display_name` for the label. Then re-review its `brand_fuel_products`: a rebrand usually renames products too. |
| **A new operator appeared** — a name in `stations_needing_brand_review` | A `brands` row if it is a real chain worth naming, with `is_retailer = true` and a `sort_order`. Then one `brand_name_rules` pattern for its trade name. Leave `brand_fuel_products` empty until a lineup can be sourced. |
| **A brand renamed a product** — XCS became something else | `brand_fuel_products.product_name` for that one row, then stamp `products_verified_at` and `products_source_url`. The fuel type does not change: a product name is a presentation of a grade. |
| **A brand added or dropped a fuel** | `brand_fuel_products`: insert or delete the row. Deleting one stops that brand's stations accepting reports for that grade, which is the intended effect. |
| **A provider writes a name a new way** — "Uni Oil" beside "Unioil" | `brand_name_rules`, if the pattern cannot already absorb it. Most can: `\ymax\s?fill\y` and `\y(petro\s+)?gazz\y` were written to. |
| **A word turns out not to be a descriptor** | `brand_name_affixes` — see the warning below. |

| List | Goes stale when |
|---|---|
| `brand_name_rules` | A provider starts writing a trade name differently |
| `brand_name_affixes` | A word treated as a descriptor turns out to be part of a trade name |
| `brand_fuel_products` | A brand renames, retires, or launches a product |

All three share this document and the 180-day cadence above. A single review pass
should read `stations_needing_brand_review` and `brands_needing_product_review`
together, because a name nobody recognised and a lineup nobody has checked are
usually the same brand.

**`brand_name_affixes` deserves a particular warning.** An affix is safe only
when no rule needs the word it removes, which is a property of this registry
rather than of English. Adding `gas` broke three rules — `\ybb\s+gas\y`,
`\yfab\s+gas\y`, `\ybm\s+gas\y` — because "gas" is part of those trade
names, and three stations silently stopped resolving to a brand. Affixes fold on
word boundaries only; a substring rule would leave "Petron" as "n".

Run this after any change to that list, and read every row:

```sql
select * from check_brand_name_normalization();
```

Every row must report `passed = true`. The identity cases are the ones that
catch substring folding — comparing two names for sameness does not, because
substring folding destroys identity while preserving difference.

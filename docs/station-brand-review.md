# Station brand review

Stations whose provider name resolved to no registered brand. Query it with:

```sql
select * from stations_needing_brand_review;
```

**A non-empty list is the normal state, not a failure.** The rules surface what
they cannot resolve rather than guessing, because a station filed under the wrong
brand is shown the wrong brand's reference price — a wrong number attached to a
real place — and a station dropped for being unrecognised is a hole in the map
with nothing to indicate it. So an unresolved station is registered, shown, and
listed here.

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

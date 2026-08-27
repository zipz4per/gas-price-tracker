# DOE Reference Price — Manual Load Procedure

How to get a week's DOE pump-price figures into the database by hand. Takes
about five minutes per report, two reports per week.

This is the working ingestion path, not a stopgap to be embarrassed about. It
exists because the automated parser is the riskiest component in the project
(see [Why not just parse the PDF](#why-not-just-parse-the-pdf)), and keeping it
off the critical path means the app can ship without it. When the parser is
built it will produce **exactly the same flat rows** described here, so this
document also specifies the parser's output contract — and remains the fallback
for the weeks when the parser breaks.

---

## 1. Find this week's report

There are two reports and they are addressed differently. This is stored in the
`doe_regions` table so nothing has to hard-code it.

| Region | Address | How to find the current one |
|---|---|---|
| **NCR** | `prod-cms.doe.gov.ph/documents/d/guest/ncr-price-monitoring-{MMDDYYYY}-pdf` | **Construct it.** The slug is the reporting period's start date as `MMDDYYYY`. For the week of 18 Aug 2026 → `ncr-price-monitoring-08182026-pdf`. |
| **Region IV-A (CALABARZON)** | `prod-cms.doe.gov.ph/documents/d/guest/region-iv-a-calabarzon-{N}-pdf` | **Look it up.** `{N}` is an opaque counter (22 as of Aug 2026) with no relationship to any date. Open the [South Luzon pump prices page](https://doe.gov.ph/data-and-prices/liquid-fuels/retail-pump-prices/south-luzon-pump-prices) and follow the current link. |

If a constructed NCR address 404s, DOE may have published late or shifted the
date convention — check the index page rather than guessing at nearby dates.

## 2. Read the period from the document

**Do not assume a week.** The two reports cover different spans and say so in
different words:

| Report | Wording in the document | Span |
|---|---|---|
| NCR | `(For the week of August 18-24, 2026)` | 7 days |
| CALABARZON | `DATE MONITORING: August 18 - 20, 2026` | 3 days |

Record three things: `period_start`, `period_end`, and `period_label` — the
label **verbatim**, including the "DATE MONITORING:" prefix. The app renders
what the document actually said rather than asserting a week.

## 3. Read the price table

Columns are brands; rows are fuel types, grouped by locality.

```
  PROVINCE  CITY/MUNICIPALITY  PRODUCT   PETRON  SHELL  CALTEX  ...  OVERALL RANGE  COMMON PRICE
  Batangas  Tanauan City       RON 91    74.50   76.40  77.50        71.70 - 84.50  74.40
                                         74.50   77.40  77.51
```

Each brand cell holds a **min and a max**. Where a brand shows one number, min
and max are the same. The `OVERALL RANGE` column is not a brand — record it
under the reserved brand code `OVERALL`.

**Only these localities matter.** Everything else in the report is ignored:

| App locality | Read the rows labelled | Region |
|---|---|---|
| Malvar | **`Tanauan City`** — Malvar is absent from DOE reports entirely | IV-A |
| Lipa City | `Lipa City` | IV-A |
| Taguig City | **`Taguig Cty`** — the typo is in the source document | NCR |

## 4. Handle the four ways DOE says "no data"

These are not interchangeable and none of them is a price:

| In the document | Means | Record as |
|---|---|---|
| `#N/A` | No figure available (NCR's marker) | leave the cell empty |
| `None` | No figure available (CALABARZON's marker) | leave the cell empty |
| `0.00` or a `0.00 - 0.00` range | Nothing was reported | leave the cell empty |
| `No LFRO` | **No Liquid Fuel Retail Outlet** — the locality has no station at all | put `No LFRO` in the cell |

The first three mean *we don't have a figure*. The fourth means *there is
nothing to have a figure about*, which is a different fact and is stored
differently — it marks the whole locality as `no_outlet`.

You may pass the raw text through unchanged; the loader normalizes all four. It
is safer to transcribe `#N/A` literally than to interpret it.

## 5. Build the flat rows

One JSON object per **locality × fuel type × brand**, with prices as raw text:

```json
[
  {"locality":"Tanauan City","fuel":"RON_91","brand":"PETRON","min":"74.50","max":"74.50","common":"None"},
  {"locality":"Tanauan City","fuel":"RON_91","brand":"SHELL","min":"76.40","max":"77.40","common":"None"},
  {"locality":"Tanauan City","fuel":"RON_91","brand":"OVERALL","min":"71.70","max":"84.50","common":"74.40"},
  {"locality":"Lipa City","fuel":"RON_91","brand":"PETRON","min":"74.40","max":"74.40","common":"None"}
]
```

**A brand with no figures needs no row at all** — omitting it is correct and is
what a blank column means. Do not invent zeros.

Valid `fuel` codes: `RON_100` `RON_97` `RON_95` `RON_91` `DIESEL` `DIESEL_PLUS` `KEROSENE`
Valid `brand` codes: `PETRON` `SHELL` `CALTEX` `PHOENIX` `TOTAL` `UNIOIL` `SEAOIL` `FLYING_V` `PTT` `INDEPENDENT` `OVERALL`

## 6. Load it

Requires the service-role key from `.env.local` — never a client key.

```sql
select public.load_doe_reference_prices(
  'IV-A',
  'https://prod-cms.doe.gov.ph/documents/d/guest/region-iv-a-calabarzon-22-pdf',
  '2026-08-18', '2026-08-20',
  'DATE MONITORING: August 18 - 20, 2026',
  '[ ...the rows... ]'::jsonb
);
```

It returns a run id. **Always check the outcome** — the function does not raise
on failure, it records one:

```sql
select status, failure_reason from public.doe_load_runs
where id = '<the returned run id>';
```

## 7. If the run failed

Nothing was stored and the previous week's data is untouched and still being
served. Fix the input and re-run; there is nothing to clean up.

| `failure_reason` says | What happened | Fix |
|---|---|---|
| `registered locality X matched no rows` | A locality in the registry wasn't found in your rows | Check the source label — DOE may have renamed or re-spelled it. Update `localities.doe_source_label` if the document genuinely changed. |
| `ambiguous match for X: N distinct source labels` | Two locality labels in your input normalize to the same registry entry | You probably transcribed one locality twice with different spacing. Merge them. |
| `price out of plausible bounds for F` | A price fell outside that fuel's allowed range | Usually a decimal-point slip. Kerosene legitimately runs high (₱113–₱135), which is why bounds are per fuel type. |
| `min > max` | A brand's min exceeds its max | The two numbers are swapped. |
| `unrecognized price value: X` | A cell contained something the parser couldn't read | If it's a new DOE absence marker, add it to `normalize_doe_price()` rather than editing it away by hand. |

---

## Why not just parse the PDF

Because the obvious approach silently corrupts data, and it was tested before
this procedure was written.

Extracting the CALABARZON report as **plain text** fails in two ways:

**The locality label detaches from its rows.** Every city name appears exactly
once, in a block far from the numbers:

```
Batangas City
Lian
Lipa City
Tanauan City
```

Rows themselves arrive as bare `RON 95  74.10 75.00 81.20 83.80 ...` with no
indication of which city they belong to.

**Blank brand columns vanish entirely.** Compare two rows from the same city:

```
RON 100   84.10 84.50                                  ← 1 pair
RON 95    74.10 74.50  81.70 82.00  76.10 76.10  ...   ← 6 pairs
```

A brand with no data emits *nothing* — no placeholder, no separator. So field
position cannot identify a brand. A regex-based parser will happily assign
Shell's price to Petron, and **it will not error**. That is the worst possible
failure here: a plausible wrong number, indistinguishable downstream from a
correct one, shown to a driver deciding where to buy fuel.

Correct parsing requires **coordinate-based extraction** — matching each word's
y-position to a product row and its x-position to a brand column header, where
the *gap* at an absent brand's x-position is itself the information:

```
  PETRON  SHELL  CALTEX  PHOENIX  TOTAL          <- header x-positions
    217     276     330     383     445
  74.50   76.40   77.50            79.90         <- values at matching x
                              ↑
                          no value = Phoenix absent
```

That is real engineering, not a regular expression — which is exactly why it is
a separate change rather than a prerequisite for shipping.

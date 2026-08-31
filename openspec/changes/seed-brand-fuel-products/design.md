## Context

See `proposal.md` — Why. Nothing here is architecture: every table, constraint and function this change writes to already exists and is unchanged. What it needs is a method for reading lineups off the open web without ever guessing, and a rule for what to do when the reading runs out.

## Goals / Non-Goals

**Goals:**

- A sourcing order that is tried the same way for every brand, so an unsourced brand is a fact about the brand rather than about how hard someone looked.
- Every seeded row traceable to a page and a date.
- A stated rule for stopping, so a partial lineup is never committed by momentum.

**Non-Goals:**

- Rendering JavaScript. Two brands hide their fuel pages behind it and will stay unsourced rather than justify a headless browser.
- Automating this. It is a curation pass, run by a person, and its output is a migration.

## Decisions

### Look for specification documents before marketing pages

Marketing pages are where the grade is least likely to appear and JavaScript most likely to hide it. A brand's technical publications say it plainly, because that is what they are for.

The order to try, per brand:

```
  1. product data sheet / technical data sheet   states the grade outright
  2. safety data sheet (SDS/MSDS)                names the product, often the grade
  3. the brand's product page                    marketing copy; sometimes states it
  4. a sitemap                                   finds pages the navigation hides
  5. stop
```

Petron was reached at step 4 — its sitemap listed fuel products the category page never rendered. Shell and Caltex failed at step 3 and are worth retrying at steps 1 and 2, which this change has not yet done.

**Why not a search engine.** A result is a third-party summary until it lands on the brand's own domain; the domain is the test, not the route taken to it.

### A grade comes from a statement, never from a name

"Blaze 100" naming its octane is a convenience and not a source. The grade is taken from a sentence on the page — *"Premium Plus Grade (RON 100)"*, *"can run on 91 RON fuel"* — or the product is not seeded.

This is the rule that leaves Petron's diesels out. Both read "Distillate fuel with additive" and both call themselves premium; nothing states which is the standard grade. Their names suggest an answer and their names are not evidence.

### A brand is seeded whole or not at all

The catalogue is authoritative, so a brand with entries offers only those fuels. A lineup missing a grade the brand actually sells silently stops its stations receiving reports for that grade — the failure looks like correct behaviour from every angle except the forecourt.

So a brand is committed only when every fuel it sells has a sourced grade. Petron with three gasolines and no diesel is not a partial success; it is twenty stations that can no longer report diesel.

### Unsourced is a recorded state

A brand that cannot be read keeps its `products_review_note`, updated with what was tried this time and where it stopped. `products_verified_at` stays null so it remains in `brands_needing_product_review`.

An empty catalogue is not a failure of this change. It is the honest output of applying the rule, and the reason the fallback to canonical grade names was specified as a first-class surface rather than a degradation.

### Check each lineup against the reference data before committing it

DOE reports prices by brand and grade. A brand DOE prices for `RON_91` whose seeded lineup omits RON 91 is a contradiction, and one of the two sources is wrong:

```sql
select p.brand_code, p.fuel_type_code
  from doe_reference_prices p
 where p.brand_presence = 'reported'
   and p.brand_code <> 'OVERALL'
   and not exists (select 1 from brand_fuel_products c
                    where c.brand_code = p.brand_code
                      and c.fuel_type_code = p.fuel_type_code);
```

Empty is the expected result. Anything returned is investigated before the seed is committed — most likely a grade read from the wrong page, and occasionally a product the brand has retired since DOE last monitored it.

## Risks / Trade-offs

- **A data sheet describes a product the brand no longer sells.** Specification documents outlive their products. → The date consulted is recorded per brand, and the DOE cross-check above catches a lineup that disagrees with what is currently being priced.

- **A brand sells a grade under two products** — a standard and a premium of the same octane. The catalogue is keyed on `(brand, fuel_type)` and cannot hold both. → Seed the one whose grade is stated; if both state the same grade, the brand is unsourceable until the schema question is reopened. This is Petron's diesel problem in a different place, and it is the most likely reason a brand stays empty.

- **Seeding a brand narrows what its stations accept.** Intended, and the sharpest consequence of this change. → The whole-or-nothing rule is what bounds it; the DOE cross-check is what verifies it.

- **This work goes stale.** Lineups change and nothing detects it. → `brands_needing_product_review` and the 180-day cadence already exist for exactly this.

## Open Questions

- **Whether `DIESEL_PLUS` earns its place in `fuel_types`.** DOE has never reported it in any loaded period, and it is one half of the ambiguity that leaves Petron unseeded. If it were removed, a brand's single diesel product would map cleanly — but that is a change to a registered fuel type and belongs to whichever change wants to argue for it, not here.

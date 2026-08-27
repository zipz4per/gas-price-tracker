-- Locality label normalization.
--
-- Deliberately conservative: lowercase, strip punctuation, collapse internal
-- whitespace runs, trim the ends. NOTHING ELSE. No edit distance, no trigram
-- similarity, no "did you mean".
--
-- The temptation is real, because the NCR report misspells Taguig as
-- "Taguig Cty" and a fuzzy matcher would absorb that automatically. It would
-- also, in the same document, let "Batangas City" quietly match rows belonging
-- to "Batangas" the province. A mis-attributed price is worse than a missing
-- one: a driver sees a plausible number with no way to know it came from the
-- wrong town, and nothing downstream can detect it.
--
-- So tolerance is DECLARED, not inferred: localities.doe_source_label stores
-- the document's spelling verbatim, typo included, and this function only
-- absorbs the differences that carry no meaning.

create or replace function public.normalize_locality_label(label text)
returns text
language sql
immutable
strict
parallel safe
set search_path = ''
as $$
  select btrim(
           regexp_replace(
             regexp_replace(lower(label), '[^a-z0-9]+', ' ', 'g'),
             '\s+', ' ', 'g'
           )
         );
$$;

comment on function public.normalize_locality_label(text) is
  'Normalizes a locality label for matching: lowercase, punctuation to space, '
  'collapse whitespace, trim. Intentionally NOT fuzzy — "Taguig Cty" and '
  '"Taguig City" must stay distinct, as must "Batangas City" and "Batangas".';

-- Matching is done on the normalized form, so index it.
create index localities_doe_source_label_normalized_idx
  on public.localities (public.normalize_locality_label(doe_source_label));

-- A normalized source label must be unique within a DOE region: two registry
-- entries resolving to the same rows would make attribution ambiguous, and the
-- design requires a registry entry to match exactly one source label.
create unique index localities_region_source_label_unique_idx
  on public.localities (doe_region_code, public.normalize_locality_label(doe_source_label));

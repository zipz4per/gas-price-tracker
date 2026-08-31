-- Which sources reported an adjustment, and what each of them said.
--
-- An adjustment exists only because two independent witnesses agreed, so the
-- witnesses are part of the record rather than a detail of how it was made. When
-- a figure later turns out to be wrong, the question is always "who said this,
-- and what exactly did they write" - and re-fetching an article that may have
-- been edited or taken down is not an answer.
--
-- amount_reported is stored per source even though corroboration required them
-- to match. They match today; a later rule that accepts near-agreement would
-- make the individual figures the only record of how near, and a column added
-- then cannot describe rows written now.

create table public.price_adjustment_sources (
  adjustment_id   uuid not null
    references public.price_adjustments (id) on delete cascade,
  source_code     text not null
    references public.adjustment_sources (code),

  amount_reported numeric(6,2) not null,

  -- The phrase the figure was read from. A citation, not a reproduction, and
  -- never displayed to a user: it exists so a wrong number can be explained.
  citation_span   text,
  article_url     text,
  published_at    timestamptz,

  primary key (adjustment_id, source_code)
);

comment on table public.price_adjustment_sources is
  'The witnesses behind each adjustment: who reported it, what figure they gave, '
  'and the phrase it was read from.';

create index price_adjustment_sources_source_idx
  on public.price_adjustment_sources (source_code);

alter table public.price_adjustment_sources enable row level security;

-- The free-text source column on price_adjustments was explicitly a placeholder
-- - its comment in 20260831160100 says this change replaces it with proper
-- multi-source attribution. Two attribution mechanisms on one table is how they
-- start disagreeing, so the placeholder goes rather than lingering beside its
-- replacement.
alter table public.price_adjustments drop column source;

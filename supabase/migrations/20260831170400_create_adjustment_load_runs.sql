-- What each ingestion attempt did, including the ones that found nothing.
--
-- Finding nothing is a finding. "No adjustment was announced this week" and "we
-- failed to find out" have opposite consequences for everything downstream: the
-- first means a derived price is still current, the second means nobody knows
-- whether it is. A run that cannot tell them apart lets a broken feed look like
-- a quiet market for as long as it stays broken.
--
-- This is the same discipline distinguish-absent-doe-data established for
-- reference data, applied to a second source.

create type public.adjustment_run_outcome as enum (
  'recorded',               -- at least one adjustment was recorded
  'none_announced',         -- sources reached, no announcement found
  'corroboration_missing',  -- an announcement found, but only one witness
  'conflict',               -- witnesses disagreed on the amount
  'failed'                  -- the attempt did not complete; nothing is known
);

comment on type public.adjustment_run_outcome is
  'How an ingestion attempt ended. Only ''failed'' means the state of the world '
  'is unknown; the other four are all things the run established.';

create table public.adjustment_load_runs (
  id           uuid primary key default gen_random_uuid(),

  -- Monotonic, and the only thing runs are ordered by.
  --
  -- started_at cannot do that job alone: now() is the TRANSACTION timestamp, so
  -- several runs written in one transaction share it exactly, and "the most
  -- recent run" then resolves to whichever row the planner happened to return.
  -- A feed-health view that reports an arbitrary row's outcome is worse than no
  -- view, because it looks authoritative.
  seq          bigserial not null unique,

  -- clock_timestamp(), not now(), for the same reason: a run starts at a moment
  -- on the wall, not when its transaction opened.
  started_at   timestamptz not null default clock_timestamp(),
  finished_at  timestamptz,

  outcome      public.adjustment_run_outcome not null,

  -- Which sources the run intended to read, and which it actually got a
  -- response from. A run that reaches two of three sources is not a failure,
  -- but the difference is the thing to look at when corroboration goes missing
  -- for weeks.
  sources_consulted text[] not null default '{}',
  sources_reached   text[] not null default '{}',

  -- How many adjustments this run wrote. Zero on every outcome but 'recorded'.
  adjustments_recorded integer not null default 0
    constraint adjustment_load_runs_recorded_not_negative check (adjustments_recorded >= 0),

  -- Required when the attempt failed, and forbidden from standing in for one.
  failure_reason text,

  note text,

  -- A failure with no reason is a failure nobody can act on, and the shape of
  -- record that lets "we could not check" decay into "nothing happened".
  constraint adjustment_load_runs_failure_has_reason
    check ((outcome = 'failed') = (failure_reason is not null)),

  -- Only a run that recorded something may claim to have recorded something.
  constraint adjustment_load_runs_recorded_matches_outcome
    check ((outcome = 'recorded') = (adjustments_recorded > 0))
);

comment on table public.adjustment_load_runs is
  'One row per ingestion attempt. A run that reached its sources and found no '
  'announcement records none_announced, never failed.';

create index adjustment_load_runs_seq_idx
  on public.adjustment_load_runs (seq desc);

-- What each witness said, when they disagreed.
--
-- A conflict produces no adjustment, so without this the disagreement would
-- leave nothing behind but an outcome word. One row per source, holding the
-- figure it gave and the text it was read from, so the disagreement can be
-- settled by a person reading both.
create table public.adjustment_run_conflicts (
  id           uuid primary key default gen_random_uuid(),
  run_id       uuid not null
    references public.adjustment_load_runs (id) on delete cascade,

  category     text not null,
  effective_at timestamptz not null,

  source_code  text not null
    references public.adjustment_sources (code),
  amount       numeric(6,2) not null,

  -- The phrase the number was read from. A citation, not a reproduction: it is
  -- what makes a wrong figure explicable without re-fetching an article that may
  -- have changed or gone. Never displayed to users.
  citation_span text,
  article_url   text,
  published_at  timestamptz
);

comment on table public.adjustment_run_conflicts is
  'What each source reported when sources disagreed. One row per disagreeing '
  'source; the run records outcome = conflict and writes no adjustment.';

create index adjustment_run_conflicts_run_idx
  on public.adjustment_run_conflicts (run_id);

-- The state of the feed, in one row.
--
-- The two timestamps are deliberately separate. "When did we last run?" and
-- "when did we last actually find out?" diverge the moment a feed breaks, and
-- only the second one says whether a derived price can be trusted.
create view public.adjustment_feed_state as
select
  (select r.started_at from public.adjustment_load_runs r
    order by r.seq desc limit 1)
    as last_run_at,
  (select r.started_at from public.adjustment_load_runs r
    where r.outcome <> 'failed'
    order by r.seq desc limit 1)
    as last_reached_sources_at,
  (select r.outcome from public.adjustment_load_runs r
    order by r.seq desc limit 1)
    as last_outcome,
  (select max(a.effective_at) from public.price_adjustments a)
    as last_adjustment_effective_at,
  (select count(*) from public.price_adjustments a)
    as adjustments_on_record;

comment on view public.adjustment_feed_state is
  'Feed health in one row. last_run_at and last_reached_sources_at diverge as '
  'soon as the feed breaks; only the second says whether a derived price rests '
  'on a current picture.';

alter table public.adjustment_load_runs      enable row level security;
alter table public.adjustment_run_conflicts  enable row level security;
alter view  public.adjustment_feed_state     set (security_invoker = true);

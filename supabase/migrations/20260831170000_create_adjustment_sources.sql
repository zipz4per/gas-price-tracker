-- Where announcements are read from, and which of those count as independent.
--
-- Corroboration is the first of two checks standing behind a deliberately
-- simple extractor, and it is worthless if both sources are the same copy.
-- Philippine outlets frequently run identical wire copy, so two feeds can carry
-- one story under two mastheads and look exactly like agreement.
--
-- Hence independence_group. Two sources corroborate each other only when their
-- groups DIFFER. An outlet that republishes another's copy is placed in the
-- originator's group, which makes the pair count once rather than twice.
--
-- The group is a maintained judgement, not a measurement. An outlet with its own
-- business desk today may syndicate tomorrow, and nothing here detects that. The
-- near-identical citation-span guard in the ingestion is the second line, and the
-- DOE cross-check is the third.

create table public.adjustment_sources (
  code               text primary key,
  display_name       text not null,
  feed_url           text not null,

  -- Sources agree only across groups. Default the group to the source's own
  -- code, so a newly added outlet is independent until someone says otherwise -
  -- the failure mode of that default is a missed corroboration, not a false one.
  independence_group text not null,

  active             boolean not null default true,

  -- Why this source is in this group, and anything known about its reliability.
  note               text,

  created_at         timestamptz not null default now()
);

comment on table public.adjustment_sources is
  'Feeds consulted for price adjustment announcements. Two sources corroborate '
  'only when their independence_group differs; a republisher shares its '
  'originator''s group.';

comment on column public.adjustment_sources.independence_group is
  'Editorial independence, not a distinct URL. Sources in one group are treated '
  'as a single witness because they may be carrying the same copy.';

create index adjustment_sources_group_idx
  on public.adjustment_sources (independence_group) where active;

-- Configuration, not public data: RLS on with no policy. The ingestion runs
-- server-side holding the service-role key, which bypasses RLS by design, and a
-- table with no policy cannot have one mis-scoped later.
alter table public.adjustment_sources enable row level security;

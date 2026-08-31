-- Correcting an adjustment, and keeping what it used to say.
--
-- A published figure can be revised by the outlets, or read wrong by us. Either
-- way the fix has to reach every price that descends from it, and because
-- derived prices are computed on read rather than written down, it does: the
-- correction lands and the next query is right. There is no backfill, no job,
-- and no station to visit individually.
--
-- What is NOT automatic is the record of what changed. Editing in place would
-- make a figure a driver saw yesterday unexplainable, and this app is built on
-- being able to say what a number is and where it came from. So the previous
-- values are kept, with the reason, before the live row moves.

create table public.price_adjustment_revisions (
  id            uuid primary key default gen_random_uuid(),
  adjustment_id uuid not null
    references public.price_adjustments (id) on delete cascade,

  -- What the adjustment said before this correction.
  superseded_amount       numeric(6,2) not null,
  superseded_effective_at timestamptz  not null,

  -- Required, and required to say something. A correction with no reason is a
  -- figure that changed and nobody can say why.
  reason        text not null
    constraint price_adjustment_revisions_reason_not_blank
      check (length(btrim(reason)) > 0),

  revised_at    timestamptz not null default clock_timestamp()
);

comment on table public.price_adjustment_revisions is
  'What an adjustment said before each correction. Append-only: one row per '
  'correction, oldest first, so a figure shown in the past can still be '
  'explained.';

create index price_adjustment_revisions_adjustment_idx
  on public.price_adjustment_revisions (adjustment_id, revised_at);

alter table public.price_adjustment_revisions enable row level security;

create function public.correct_price_adjustment(
  p_adjustment_id uuid,
  p_reason        text,
  p_amount        numeric     default null,
  p_effective_at  timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_current record;
  v_amount    numeric(6,2);
  v_effective timestamptz;
begin
  select a.id, a.amount, a.effective_at into v_current
    from public.price_adjustments a
   where a.id = p_adjustment_id;

  if not found then
    raise exception using
      errcode = '22023',
      message = format('unknown adjustment: %L', p_adjustment_id);
  end if;

  if p_reason is null or length(btrim(p_reason)) = 0 then
    raise exception using
      errcode = '22023',
      message = 'a correction requires a reason',
      hint    = 'The reason is what makes a changed figure explicable later.';
  end if;

  v_amount    := coalesce(p_amount, v_current.amount);
  v_effective := coalesce(p_effective_at, v_current.effective_at);

  -- A correction that corrects nothing would add a revision row asserting a
  -- change that did not happen, which is worse than no record at all.
  if v_amount = v_current.amount and v_effective = v_current.effective_at then
    raise exception using
      errcode = '22023',
      message = 'correction changes nothing',
      detail  = format('amount is already %s and effective_at is already %s',
                       v_current.amount, v_current.effective_at);
  end if;

  -- The old values are recorded BEFORE the live row moves, so a failure of the
  -- update cannot leave a revision describing a change that did not happen.
  insert into public.price_adjustment_revisions
    (adjustment_id, superseded_amount, superseded_effective_at, reason)
  values (p_adjustment_id, v_current.amount, v_current.effective_at, p_reason);

  update public.price_adjustments
     set amount = v_amount, effective_at = v_effective
   where id = p_adjustment_id;

  return p_adjustment_id;
end;
$$;

comment on function public.correct_price_adjustment(uuid, text, numeric, timestamptz) is
  'Correct a recorded adjustment''s amount or effective instant, retaining what '
  'it said before and why it changed. Every price derived from it reflects the '
  'correction on the next read; nothing is backfilled.';

-- An administrative operation, not a client one. No grant to anon or
-- authenticated: the default PUBLIC grant is revoked and only service_role,
-- which the ingestion runs as, is given it back.
revoke all on function public.correct_price_adjustment(uuid, text, numeric, timestamptz) from public;
grant execute on function public.correct_price_adjustment(uuid, text, numeric, timestamptz)
  to service_role;

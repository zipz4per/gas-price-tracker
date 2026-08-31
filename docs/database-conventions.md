# Database conventions

Rules that are easy to get wrong here specifically, because the obvious version
is right about Postgres and wrong about this project.

## Closing a function to the public

**`revoke ... from public` does not close anything on a Supabase project.**

Stock Postgres grants EXECUTE on a new function to `PUBLIC`, so revoking from
`PUBLIC` is how you close it. Supabase additionally installs *default
privileges* that grant EXECUTE on every new function in `public` to `anon`,
`authenticated` and `service_role` **explicitly**:

```sql
select defaclrole::regrole, defaclacl from pg_default_acl where defaclobjtype = 'f';
--  postgres  {postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}
```

An explicit grant survives a revoke aimed at `PUBLIC`. So this closes nothing:

```sql
-- WRONG. anon keeps the grant it was given by default.
revoke all on function public.f(...) from public;
grant execute on function public.f(...) to service_role;
```

and this is the pattern to copy:

```sql
-- RIGHT.
revoke all on function public.f(...) from public, anon, authenticated;
grant execute on function public.f(...) to service_role;
```

The wrong version is dangerous rather than merely useless, because it reads as
though the door is shut. It was used on `correct_price_adjustment`, a
`SECURITY DEFINER` function that rewrites price adjustments, and left it callable
by anyone holding the anon key that ships in the client — see
`openspec/bugs/archive/*-admin-functions-callable-by-anon/`.

**Check, don't assume.** After adding any function not meant for the public:

```sql
select p.proname,
       has_function_privilege('anon', p.oid, 'EXECUTE')          as anon,
       has_function_privilege('authenticated', p.oid, 'EXECUTE')  as authenticated,
       has_function_privilege('service_role', p.oid, 'EXECUTE')   as service_role
  from pg_proc p join pg_namespace n on n.oid = p.pronamespace
 where n.nspname = 'public' and p.prokind = 'f'
 order by anon desc, p.proname;
```

A function intended for the app's clients *should* show `anon = true`; that is
most of them. The list is worth reading whole rather than filtered, because the
mistake looks identical to the intended state until you know which is which.

## Closing a table to writes

The same default privileges hand `anon` and `authenticated` **ALL** privileges
on every new table in `public` — insert, update, delete and truncate included.
A new table is anonymously writable until something says otherwise.

Both barriers, in this order:

```sql
revoke all on table public.t from anon, authenticated;
grant select on table public.t to anon, authenticated;

alter table public.t enable row level security;
create policy t_public_read on public.t for select to anon, authenticated using (true);
-- and no INSERT, UPDATE or DELETE policy at all
```

RLS alone would do it, but then one missing `enable row level security` is the
difference between a read-only table and an open one. A policy that does not
exist cannot be mis-scoped later; a policy that exists can be widened by
accident.

## `CASE` drops the type modifier

A `CASE` whose branches differ returns the bare type, not the typmod, so this
fails against a composite type declaring `numeric(6,2)`:

```sql
-- ERROR: structure of query does not match function result type
case when cond then x::numeric(6,2) else null end
```

Cast the whole expression instead:

```sql
(case when cond then x else null end)::numeric(6,2)
```

The same applies to `smallint` columns returned into an `integer` in a
`RETURNS TABLE` — `fuel_types.sort_order` is `smallint` and needs `::integer`.

## Composite types cannot carry `NOT NULL`

`CREATE TYPE ... AS (...)` accepts no column constraints, so a composite type
cannot promise a non-null attribute. A **domain** can, and a domain's
constraints *are* enforced on assignment through a composite:

```sql
create domain public.price_basis as text
  not null
  constraint price_basis_not_blank check (length(btrim(value)) > 0);
```

`row(...)::station_price_result` with a null basis now raises instead of
returning quietly. Use this wherever a comment would otherwise be the only thing
promising a field is always present.

## `now()` is the transaction timestamp

Several rows inserted in one transaction share `now()` exactly, so ordering by a
`now()`-defaulted column is undefined among them. Use `clock_timestamp()` when
the column means "when this happened", and order by a monotonic `bigserial` when
ordering has to be deterministic — `adjustment_load_runs.seq` exists for this.

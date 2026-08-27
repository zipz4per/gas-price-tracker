## Context

See `proposal.md` — Why. The working directory holds a PRD and OpenSpec planning artifacts, and nothing else: no git, no `.gitignore`, no `package.json`, no Supabase scaffolding. A hosted Supabase project exists and its public GitHub repository exists with no commits.

Docker is available locally, which makes the full local Supabase stack a viable development target rather than a theoretical one.

Two decisions here outlive this change and constrain every change after it, which is why they are recorded rather than left implicit.

## Goals / Non-Goals

**Goals:**

- A credential boundary that is structurally enforced rather than remembered.
- A development model where destructive schema iteration is free and carries no risk to real data.
- A working migration path for later changes to build on.

**Non-Goals:**

- Any schema, table, function, or policy — those belong to the capability changes.
- Any application code or client framework. The platform question (native versus web) remains open and is deliberately not answered here.
- Writing anything to the hosted project. It is linked and verified only.

## Decisions

### `.gitignore` is the repository's first commit

Version control is initialised with a `.gitignore` committed before any Supabase artifact or credential exists in the working tree.

*Why:* the failure mode is not that someone deliberately commits a secret — it is a blanket `git add .` weeks later sweeping up a file that had been sitting untracked and harmless the whole time. Ordering removes the window in which that is possible. Because the remote has no commits yet, this is achievable as a guarantee rather than merely as a policy; the repository is public, so a service-role key reaching its history could only be remedied by rotating the key, since deleting a commit does not reach forks, caches, or anything that already scraped it.

*Alternative rejected:* adding `.gitignore` alongside the first Supabase files. Functionally equivalent if nothing goes wrong, but it leaves a window open for no benefit.

### The service-role credential never enters the repository

The service-role key and database password live only in an untracked local environment file. Migrations and seed files never contain either.

*Why:* the service-role key bypasses RLS entirely, so it is not a credential that restrictive policies can contain — the only control is that it never leaves the operator's machine. Keeping it out of migrations also means migration files stay safe to commit by default, which is what makes the rest of the workflow tenable.

### Local-first development, with migrations as the only path to hosted

Schema is built and verified against the local stack, where `supabase db reset` is free and destructive iteration carries no risk. It reaches hosted only via `supabase db push`, once verified.

*Why:* iteration speed and safety, but more importantly it keeps the two environments reconcilable. The rule that makes it work is that the hosted schema is **never** edited through the dashboard's table editor: a single click there diverges local from hosted and turns every subsequent push into a conflict to be untangled by hand.

*Alternative rejected:* developing directly against the hosted project. Simpler to start, and it means every mistake happens on the environment that will eventually hold real data — with no free reset available.

## Risks / Trade-offs

- **The local stack requires Docker running** → Confirmed available. If it becomes unavailable, hosted-only development remains possible but forfeits the free reset; that would be a deliberate fallback, not a silent one.
- **A linked project introduces the possibility of an accidental push** → This change performs a dry-run only. Real pushes are deferred to `add-doe-price-retrieval`, after local verification passes.
- **Convention can erode** — a later change could still hard-code a key into a migration → Partly mitigated by the ignore rules, which do not cover migration files. This is the residual risk, and it is a review concern rather than something the tooling can enforce.

## Migration Plan

Greenfield with no rollback concerns: nothing consumes this scaffolding yet, and no data exists. Reversal is deleting the created files.

Order matters within the change and is the substance of it: git and `.gitignore` first, then Supabase scaffolding, then the credential file, then linking. Performing these out of order reintroduces the exposure window the change exists to close.

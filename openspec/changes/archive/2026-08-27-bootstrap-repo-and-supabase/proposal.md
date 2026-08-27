## Why

The project has a PRD, planning artifacts, and a public GitHub repository that has never been committed to — but no version control locally, no Supabase project wiring, and no convention for where credentials live. Every subsequent change writes migrations, and the first of them will introduce a Supabase service-role key into the working tree.

That ordering is the reason this is its own change. A service-role key is a full Row-Level Security bypass; in a public repository it is a complete database compromise, and secret scanners find such keys within minutes. The repository currently has no `.gitignore`, so nothing prevents a later blanket `git add` from sweeping up a credential file that had been sitting untracked and harmless. Establishing that boundary **before** any credential exists is a one-time, cheap guarantee — and impossible to retrofit, since a key that reaches a public history can only be remedied by rotation.

Doing this as a separate change also keeps the capability changes that follow focused on behaviour rather than on tooling setup.

## What Changes

- **Initialise version control** with a `.gitignore` as the repository's first commit, covering environment files and the Supabase CLI's local state directories, and connect the existing empty public remote.
- **Initialise the Supabase project** locally and bring up the local development stack.
- **Establish the credential convention**: the service-role key and database password live only in an untracked local environment file, never in a migration, seed, or committed file.
- **Link the hosted Supabase project** by project reference and verify that migrations would apply cleanly against it, without writing anything.
- **Establish the migrations directory** and verify a clean reset cycle, giving later changes a working migration path.
- **Adopt a local-first development model**: schema work is built and verified against the local stack, and pushed to hosted only once verified. Migrations become the only path between the two.

## Capabilities

### New Capabilities

None. This change introduces no externally observable system behaviour — it establishes version control, project scaffolding, and a credential boundary. `.openspec.yaml` sets `skip_specs: true` accordingly.

### Modified Capabilities

None.

## Impact

- **New:** a git repository with `.gitignore` as its initial commit, connected to the existing public remote at `github.com/zipz4per/gas-price-tracker`.
- **New:** `supabase/config.toml` and an empty migrations directory.
- **New:** an untracked local environment file holding the service-role key and database password.
- **External:** the previously created hosted Supabase project becomes linked, but is not written to by this change.
- **Downstream:** every later change depends on this one. `add-locality-registry`, `add-doe-price-storage`, and `add-doe-price-retrieval` all write migrations and cannot proceed without it.
- **No impact on:** application code, schema, or any DOE data — none of which exist yet.

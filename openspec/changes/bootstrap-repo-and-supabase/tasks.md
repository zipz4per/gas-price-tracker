## 1. Version control and credential boundary

- [x] 1.1 Initialise the git repository and make a `.gitignore` covering `.env*`, `supabase/.temp/`, and `supabase/.branches/` the repository's **first commit**, before any credential or Supabase artifact exists in the working tree; verify `git log` shows it as the initial commit and `git status --ignored` lists the patterns as ignored
- [ ] 1.2 Connect the empty public GitHub remote and verify the pushed history begins with the `.gitignore` commit and contains no service-role key or database password; the remote has no prior commits, so this is a prevention check rather than an audit of existing history

## 2. Supabase project scaffolding

- [x] 2.1 Initialise the Supabase project locally (`npx supabase init`) and verify `supabase/config.toml` exists and `npx supabase start` brings the local stack up
- [x] 2.2 Establish the credential convention — the service-role key and database password live only in an untracked `.env.local`, never in a migration, seed, or committed file; verify the file is git-ignored and absent from `git status`
- [ ] 2.3 Link the hosted Supabase project by project ref and verify `npx supabase db push --dry-run` reports a clean, empty diff against the remote; this step performs no writes
- [ ] 2.4 Create the migrations directory structure and verify an empty migration applies cleanly with `npx supabase db reset`

## 3. Verification

- [ ] 3.1 Verify the local-first loop end to end: apply an empty migration, run `npx supabase db reset`, and confirm the stack returns to a clean state without touching the hosted project
- [ ] 3.2 Verify the credential boundary holds by confirming `.env.local` is ignored, absent from `git status`, and that no committed file contains a service-role key or database password

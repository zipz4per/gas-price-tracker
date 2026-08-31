import { createClient } from '@supabase/supabase-js';

import type { Database } from './database.types';

/**
 * Configuration comes from EXPO_PUBLIC_* variables, which Expo inlines into the
 * built bundle.
 *
 * That is correct for these two and wrong for everything else. The URL and the
 * anon key are public identifiers: what protects the database is the grants and
 * the row-level security behind them — `anon` holds `select` on the read tables,
 * no write policy exists, and `submit_price_report` is the only path by which a
 * row reaches `price_reports`.
 *
 * NEVER give a secret an EXPO_PUBLIC_ prefix. The service-role key bypasses all
 * of it, and `.env.local` — which Expo loads automatically — holds one.
 */
/**
 * Expo inlines an `EXPO_PUBLIC_*` variable by REWRITING the literal expression
 * `process.env.EXPO_PUBLIC_NAME` at build time. It is a syntactic substitution,
 * not a runtime lookup, so a dynamic access — `process.env[name]` — is invisible
 * to it and survives into the bundle as a read of an object that is empty in a
 * browser.
 *
 * That failure is quiet in exactly the wrong way: it type-checks, it works in
 * development where the variables are really in the environment, and it fails
 * only in the built app, where it looks like a missing configuration rather
 * than a missing transform. Hence the literal references below and a check that
 * takes the value rather than fetching it.
 */
function required(name: string, value: string | undefined): string {
  if (!value) {
    throw new Error(
      `Missing ${name}. The app cannot reach Supabase without it. ` +
        `Set it in .env.local (see docs/frontend.md); it must be a public value, ` +
        `because every EXPO_PUBLIC_ variable is inlined into the built bundle.`,
    );
  }
  return value;
}

export const supabase = createClient<Database>(
  required('EXPO_PUBLIC_SUPABASE_URL', process.env.EXPO_PUBLIC_SUPABASE_URL),
  required('EXPO_PUBLIC_SUPABASE_ANON_KEY', process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY),
  {
    auth: {
      // Nothing in this app authenticates. There is no session to persist and
      // no token to refresh, and asking React Native for storage it does not
      // have by default is a warning nobody needs to read.
      persistSession: false,
      autoRefreshToken: false,
    },
  },
);

# Database schema

Schema changes live in [`supabase/migrations/`](../supabase/migrations) and are applied by
GitHub Actions. Nobody runs DDL by hand in either project's SQL editor.

| Project | Ref |
|---|---|
| Production | `lhwxovefpwxylulnptwo` |
| Dev | `khavbdocjufkyhwpiniw` |

## Why

In October 2026 the Canvas tables were created in production by hand, so dev never
got them and the dev dashboard came up empty. With every change going through a
migration, dev always gets it first.

## If you need to change the database

1. Add a migration: `supabase migration new <name>`, then write the SQL. Make it safe to
   re-run where you can (`if not exists`, `drop policy if exists` before `create policy`).
2. Open a PR. The **Database migrations** workflow lists what's pending on dev.
3. On merge to `main`, the workflow applies it to dev, then waits for **@solema247** to
   approve the `production` environment before applying it to production.
4. Update `src/lib/database.types.ts` to match.

The **Schema drift check** workflow compares the two `public` schemas every night and
fails if they differ.

## One-time setup

1. Repo secrets: `SUPABASE_ACCESS_TOKEN` (from
   https://supabase.com/dashboard/account/tokens, with access to both projects),
   `DEV_DB_PASSWORD`, `PROD_DB_PASSWORD`.
2. Repo variables: `DEV_PROJECT_REF=khavbdocjufkyhwpiniw`,
   `PROD_PROJECT_REF=lhwxovefpwxylulnptwo`.
3. An environment named `production` with @solema247 as a required reviewer.
4. Baseline the migration history so the first push doesn't re-run migrations that are
   already in place:

   ```bash
   supabase link --project-ref lhwxovefpwxylulnptwo && scripts/db/baseline-migration-history.sh
   supabase link --project-ref khavbdocjufkyhwpiniw && scripts/db/baseline-migration-history.sh
   ```

5. Run **Schema drift check** manually once. It should pass.

## If you only work on the app

You don't need any of this. Clone the repo as usual.

#!/usr/bin/env bash
# One-time setup. Neither Supabase project has a migration history yet, so the
# first `supabase db push` would try to re-run every migration in the repo. This
# marks migrations as already applied on a project without running them.
#
# Usage (from the repo root, after `supabase link --project-ref <ref>`):
#   scripts/db/baseline-migration-history.sh                  # mark all as applied
#   scripts/db/baseline-migration-history.sh 20261012120000   # leave these pending
#
# Both projects already have every migration in supabase/migrations as of
# 2026-10-12 (the Canvas one was applied to dev by hand), so run it with no
# arguments on each.

set -euo pipefail

pending=" $* "
applied=()
for f in supabase/migrations/*.sql; do
  version=$(basename "$f" | cut -d_ -f1)
  if [[ "$pending" == *" $version "* ]]; then
    echo "leave pending: $version"
  else
    applied+=("$version")
  fi
done

if [ ${#applied[@]} -eq 0 ]; then
  echo "Nothing to mark as applied."
  exit 0
fi

echo "Marking ${#applied[@]} migrations as applied on the linked project..."
supabase migration repair --status applied "${applied[@]}"
supabase migration list

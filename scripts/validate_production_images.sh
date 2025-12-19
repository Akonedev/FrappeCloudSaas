#!/usr/bin/env bash
set -euo pipefail

ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo '.')
f="$ROOT/docker/compose.production.yml"
[ -f "$f" ] || { echo "no production compose file found - skipping"; exit 0; }

if grep -n "image: .*:latest" "$f" || grep -n "image:[[:space:]]*[^:[:space:]]\+\([[:space:]]*$\)" "$f"; then
  echo "ERROR: found unpinned or 'latest' image tags in production compose ($f)" >&2
  exit 2
fi

echo "Production image pinning validation passed."

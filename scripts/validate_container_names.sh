#!/usr/bin/env bash
set -euo pipefail

# Validate container naming conventions in docker compose files
# Rule: All containers MUST be named with prefix fcs-press- OR
# services defined in compose must use a service name starting with fcs-press-

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
FILES=( 
  "$ROOT/docker/compose.yaml"
  "$ROOT/docker/compose.yml"
  "$ROOT/compose.yaml"
  "$ROOT/compose.yml"
)

# also glob docker/**/compose*.yml
while IFS= read -r f; do FILES+=("$f"); done < <(find "$ROOT" -type f -regextype posix-extended -regex '.*(compose|docker).*(\.ya?ml)$' -print 2>/dev/null || true)

seen=()
for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  # avoid duplicates
  skip=false
  for s in "${seen[@]}"; do [[ "$s" == "$f" ]] && skip=true && break; done
  $skip && continue
  seen+=("$f")

  echo "Checking container names in $f"

  awk 'BEGIN{in_services=0}
  /^services:/ {in_services=1; next}
  # if we hit a top-level key (no indent) we exit services block
  /^[^[:space:]]/ { in_services=0 }
  # match only top-level service names in services: (exactly two-space indent)
  in_services==1 && match($0, /^  ([a-zA-Z0-9_.-]+):/, m) { svc=m[1]; if (svc !~ /^fcs-press-/) print "SERVICE:" svc }
  in_services==1 && match($0, /^[[:space:]]+container_name:[[:space:]]*(.*)$/, m) { print "CONTAINER:" m[1] }
  ' "$f" | while read -r line; do
    if [[ "$line" == SERVICE:* ]]; then
      svc=${line#SERVICE:}
      if ! grep -qP "^\s*${svc}:" "$f"; then
        echo "Unable to locate service $svc in $f (skipping)" >&2
      else
        block=$(awk -v s="$svc" 'BEGIN{p=0} $0 ~ "^\s*"s":"{p=1} p==1 && NF==0{exit} p==1{print}' "$f")
        if echo "$block" | grep -q "container_name:"; then
          raw=$(echo "$block" | sed -n "s/.*container_name:[[:space:]]*\(.*\)$/\1/p")
          # strip surrounding quotes and spaces
          cname=$(echo "$raw" | sed -E "s/^['\"]?(.*)['\"]?$/\1/" | xargs)
          if [[ -n "$cname" && ! "$cname" =~ ^fcs-press- ]]; then
            echo "ERROR: container_name '$cname' in service '$svc' of $f does not start with 'fcs-press-'"
            exit 2
          fi
        else
          if [[ ! "$svc" =~ ^fcs-press- ]]; then
            echo "ERROR: service '$svc' in $f does not have container_name and service name is not prefixed with 'fcs-press-'"
            exit 2
          fi
        fi
      fi
    elif [[ "$line" == CONTAINER:* ]]; then
      cname=${line#CONTAINER:}
      if [[ ! "$cname" =~ ^fcs-press- ]]; then
        echo "ERROR: container_name '$cname' in $f does not start with 'fcs-press-'"
        exit 2
      fi
    fi
  done
done

echo "All container naming checks passed."
exit 0

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
  in_services==1 && /^[[:space:]]+[a-zA-Z0-9_.-]+:/{
    svc=$1; gsub(":","",svc); cur=svc; if (cur !~ /^fcs-press-/) { printf("SERVICE:%s\n",cur) }
  }
  in_services==1 && /^[[:space:]]+container_name:[[:space:]]*(.*)/{
    name=$2; gsub(/^["' ]+|["' ]+$/,"",name); if (name !~ /^fcs-press-/) { printf("CONTAINER:%s\n",name) }
  }
  ' "$f" | while read -r line; do
    if [[ "$line" == SERVICE:* ]]; then
      svc=${line#SERVICE:}
      if ! grep -qP "^\s*${svc}:" "$f"; then
        echo "Unable to locate service $svc in $f (skipping)" >&2
      else
        block=$(awk -v s="$svc" 'BEGIN{p=0} $0 ~ "^\s*"s":"{p=1} p==1 && NF==0{exit} p==1{print}' "$f")
        if echo "$block" | grep -q "container_name:"; then
          cname=$(echo "$block" | sed -n "s/.*container_name:[[:space:]]*\(['\"]\?\)\(.*\)\1/\2/p" | tr -d '"\'')
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

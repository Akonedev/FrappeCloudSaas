#!/usr/bin/env bash
set -euo pipefail

# Validate host ports in docker compose files fall inside the allowed range.
# Allowed range: 48510-49800 (per constitution)

ROOT="$(git rev-parse --show-toplevel 2>/dev/null || echo ".")"
ALLOWED_MIN=48510
ALLOWED_MAX=49800

FILES=( 
  "$ROOT/docker/compose.yaml"
  "$ROOT/docker/compose.yml"
  "$ROOT/compose.yaml"
  "$ROOT/compose.yml"
)
while IFS= read -r f; do FILES+=("$f"); done < <(find "$ROOT" -type f -regextype posix-extended -regex '.*(compose|docker).*(\.ya?ml)$' -print 2>/dev/null || true)

seen=()
for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  skip=false
  for s in "${seen[@]}"; do [[ "$s" == "$f" ]] && skip=true && break; done
  $skip && continue
  seen+=("$f")

  echo "Checking ports in $f"

  # extract port lines that look like '    - "8080:80"' or '    - 8080:80'
  # We'll handle mappings like host:container, hostIP:host:container, and ranges host:container
  grep -E "^[[:space:]]*-[[:space:]]*\"?[0-9]+(:[0-9]+)+\"?" -n "$f" 2>/dev/null || true | while IFS=: read -r ln line; do
    # extract the left-most number(s) before the first ':'
    entry=$(echo "$line" | sed -E 's/^[[:space:]]*-[[:space:]]*\"?//; s/\"?\s*$//')
    host=$(echo "$entry" | cut -d: -f1)
    # if host includes ip (e.g., 127.0.0.1:8080) then host will be ip; detect if numeric or ip
    if [[ "$host" =~ ^[0-9]+$ ]]; then
      # numeric host port
      port=$host
    else
      # if host has ip:port pattern like 127.0.0.1:8080, take last part
      if [[ "$host" =~ [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+ ]]; then
        # assume format ip:port
        port=$(echo "$entry" | awk -F":" '{print $(NF-1)}')
      else
        # maybe it's just host-range or container-only mapping, ignore if not numeric
        continue
      fi
    fi

    # If port is a range like 49000-49010, check both
    if [[ "$port" =~ - ]]; then
      IFS=- read -r p1 p2 <<< "$port"
      for p in $p1 $p2; do
        if ! [[ "$p" =~ ^[0-9]+$ ]]; then continue; fi
        if (( p < ALLOWED_MIN || p > ALLOWED_MAX )); then
          echo "ERROR: port $p in $f (line $ln) is outside allowed range $ALLOWED_MIN-$ALLOWED_MAX"
          exit 2
        fi
      done
    else
      if ! [[ "$port" =~ ^[0-9]+$ ]]; then continue; fi
      if (( port < ALLOWED_MIN || port > ALLOWED_MAX )); then
        echo "ERROR: port $port in $f (line $ln) is outside allowed range $ALLOWED_MIN-$ALLOWED_MAX"
        exit 2
      fi
    fi
  done
done

echo "All port validations passed."
exit 0

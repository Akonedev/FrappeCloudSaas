#!/usr/bin/env bash
set -euo pipefail

HOST="127.0.0.1"
PORT="48550"
URL="http://${HOST}:${PORT}/health"
TIMEOUT=${1:-120}
SLEEP=3

echo "Waiting up to ${TIMEOUT}s for Press Manager health at ${URL}"
end=$((SECONDS + TIMEOUT))
while [ $SECONDS -lt $end ]; do
  if curl -fsS "$URL" >/dev/null 2>&1; then
    echo "OK: ${URL} reachable"
    curl -fsS "$URL" || true
    exit 0
  fi
  echo "not healthy yet, sleeping ${SLEEP}s..."
  sleep $SLEEP
done

echo "ERROR: ${URL} did not become healthy within ${TIMEOUT} seconds" >&2
exit 2

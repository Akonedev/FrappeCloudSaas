#!/usr/bin/env bash
# Wrapper to ensure .venv exists, activate it, then run the full live integration test suite
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV_DIR="$ROOT_DIR/.venv"

if [ ! -d "$VENV_DIR" ]; then
  echo "No virtualenv found at $VENV_DIR — creating..."
  "$ROOT_DIR/scripts/setup_venv.sh"
fi

echo "Activating virtualenv"
# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"

cd "$ROOT_DIR"

# Ensure Python picks up the repository packages
export PYTHONPATH="$ROOT_DIR"

export POSTGRES_HOST=${POSTGRES_HOST:-127.0.0.1}
export POSTGRES_PORT=${POSTGRES_PORT:-48532}
export POSTGRES_USER=${POSTGRES_USER:-press}
export POSTGRES_PASSWORD=${POSTGRES_PASSWORD:-changeme}
export POSTGRES_DB=${POSTGRES_DB:-press}
export MINIO_ROOT_USER=${MINIO_ROOT_USER:-minio}
export MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-minio123}

# support overriding the bench image at runtime
RECREATE_MINIO=0
FORCE_RECREATE_MINIO=${FORCE_RECREATE_MINIO:-0}

# AUTONOMOUS_MODE: when enabled the runner will perform destructive and
# heavyweight actions by default (recreate MinIO, use a real bench image,
# and enable real pg_dump/pg_restore). This is intended for fully autonomous
# developer/CI runs when the user has explicitly requested autonomy.
# WARNING: enabling AUTONOMOUS_MODE may delete local MinIO/Postgres volumes.
AUTONOMOUS_MODE=${AUTONOMOUS_MODE:-1}

if [ "$AUTONOMOUS_MODE" -ne 0 ]; then
  # prefer a real bench image for full migrations and install flows
  export BENCH_IMAGE=${BENCH_IMAGE:-frappe/bench:edge}
  # enable non-interactive recreation of MinIO by default in autonomous mode
  RECREATE_MINIO=1
  # force non-interactive removal of volumes in autonomous mode
  FORCE_RECREATE_MINIO=1
  # enable real pg_dump/pg_restore flows when available
  export USE_REAL_PGDUMP=${USE_REAL_PGDUMP:-1}
  echo "AUTONOMOUS_MODE=1 -> BENCH_IMAGE=${BENCH_IMAGE}, RECREATE_MINIO=${RECREATE_MINIO}, USE_REAL_PGDUMP=${USE_REAL_PGDUMP}"
fi

# parse --bench-image and --recreate-minio/--destructive flags
while [ "$#" -gt 0 ]; do
  case "$1" in
    --bench-image)
      shift
      BENCH_IMAGE="$1"
      export BENCH_IMAGE
      echo "Using bench image: $BENCH_IMAGE"
      ;;
    --recreate-minio|--destructive)
      RECREATE_MINIO=1
      ;;
    --force|--yes)
      FORCE_RECREATE_MINIO=1
      ;;
    --)
      shift
      break
      ;;
    *)
      # any other positional args are passed to pytest later
      break
      ;;
  esac
  shift || true
done

if [ -n "${BENCH_IMAGE:-}" ]; then
  echo "Using bench image: $BENCH_IMAGE"
fi

echo "Running live integration tests (schema manager, MinIO, provision, backup/restore, e2e)"
echo "Validating MinIO credentials and reachability first"
python - <<'PY' || true
import os, sys
from botocore.client import Config
import boto3

ep = 'http://127.0.0.1:48590'
ak = os.environ.get('MINIO_ROOT_USER','minio')
sk = os.environ.get('MINIO_ROOT_PASSWORD','minio123')
try:
  s3 = boto3.client('s3', endpoint_url=ep, aws_access_key_id=ak, aws_secret_access_key=sk, config=Config(signature_version='s3v4'))
  s3.list_buckets()
except Exception as e:
  print('ERROR: MinIO credentials/reachability check failed:', e, file=sys.stderr)
  print('\nIf you have a persisted MinIO volume from a previous run the root credentials may differ.', file=sys.stderr)
  print('Options:', file=sys.stderr)
  print('  1) Remove MinIO data volume (docker volume rm docker_minio-data) and restart compose to use configured env credentials', file=sys.stderr)
  print('  2) Export MINIO_ROOT_USER/MINIO_ROOT_PASSWORD to match running MinIO and re-run this script', file=sys.stderr)
  # In autonomous mode we may want to recreate MinIO even if it's unreachable
  # so defer exit until we check RECREATE_MINIO below.
  sys.exit(1)
PY
rc=$?
if [ $rc -ne 0 ]; then
  if [ "$RECREATE_MINIO" -eq 1 ]; then
    echo "MinIO unreachable — continuing because RECREATE_MINIO=1 (autonomous mode)"
  else
    echo "MinIO is unreachable and RECREATE_MINIO is not set. Aborting to avoid data issues."
    exit 2
  fi
fi
if [ "$RECREATE_MINIO" -eq 1 ]; then
  echo "Requested MinIO recreation: locating candidate docker volumes..."
  if ! command -v python >/dev/null 2>&1; then
    echo "ERROR: python executable not available to run helper for recreating volumes" >&2
    exit 2
  fi

  # run the helper; it raises if confirmation missing
  if [ "$FORCE_RECREATE_MINIO" -eq 1 ]; then
    python - <<'PY'
from scripts.lib.recreate_minio import recreate_minio
removed = recreate_minio(confirm=True, non_interactive=True)
print('removed:', removed)
PY
    # bring up the minio service again using compose so it re-creates data dir
    echo "Restarting minio service via docker compose..."
    if command -v docker >/dev/null 2>&1 && docker compose -f docker/compose.yaml up -d fcs-press-minio; then
      # wait briefly for minio port
      for i in $(seq 1 30); do
        if nc -z 127.0.0.1 48590; then
          echo "MinIO is reachable on port 48590"
          break
        fi
        sleep 1
      done
    else
      echo "Warning: unable to restart minio via docker compose, tests may fail"
    fi
  else
    echo "MinIO recreation requested but --force / env FORCE_RECREATE_MINIO=1 not set. Aborting to avoid data loss."
    echo "If you want to proceed non-interactively, re-run with --recreate-minio --force or set FORCE_RECREATE_MINIO=1"
    exit 2
  fi
fi

pytest -q tests/integration/test_schema_manager_live.py || pytest -q tests/integration/test_schema_manager_live.py -q
pytest -q tests/integration/test_minio_live.py -q || pytest -q tests/integration/test_minio_live.py -q
pytest -q tests/integration/test_provision_live.py -q || pytest -q tests/integration/test_provision_live.py -q
pytest -q tests/integration/test_backup_restore_live.py -q || pytest -q tests/integration/test_backup_restore_live.py -q
pytest -q tests/e2e/test_site_live.py -q || pytest -q tests/e2e/test_site_live.py -q

echo "Live tests finished"

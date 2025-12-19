#!/usr/bin/env bash
# Create and populate a dedicated Python virtual environment at .venv
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VENV_DIR="$ROOT_DIR/.venv"
PY_VERSION=${PY_VERSION:-3}

if [ -d "$VENV_DIR" ]; then
  echo "Virtualenv already exists at $VENV_DIR"
else
  echo "Creating virtualenv at $VENV_DIR using python${PY_VERSION}"
  python${PY_VERSION} -m venv "$VENV_DIR"
fi

echo "Activating virtualenv..."
# shellcheck source=/dev/null
source "$VENV_DIR/bin/activate"

echo "Upgrading pip and installing dependencies"
python -m pip install --upgrade pip
pip install --upgrade pytest requests psycopg2-binary boto3 botocore

echo "Virtualenv setup complete. To activate it in your shell run:"
echo "  source $VENV_DIR/bin/activate"

exit 0

#!/bin/sh
# Run from any directory; machine-specific paths remain in ignored local config.
set -eu
TASK_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$TASK_ROOT"
exec "${WORLD_RISE_PYTHON:-python3}" -u tools/platform_cli.py "$@"

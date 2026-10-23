#!/bin/bash
# Recreate all macOS icon representations from the generated 1024px master.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 "$ROOT/scripts/release/icon.py"

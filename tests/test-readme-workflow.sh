#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for path in "$ROOT_DIR/README.md" "$ROOT_DIR/README_EN.md"; do
  if ! grep -Fq "openspec-sync-specs" "$path"; then
    echo "expected $path to document the standalone sync workflow" >&2
    exit 1
  fi
done

echo "readme workflow test passed"

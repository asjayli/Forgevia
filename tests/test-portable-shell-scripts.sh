#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

assert_not_contains() {
  local path="$1"
  local needle="$2"

  if grep -Fq -- "$needle" "$path"; then
    echo "expected $path to avoid non-portable find option: $needle" >&2
    exit 1
  fi
}

for path in \
  "$ROOT_DIR/scripts/install-claude.sh" \
  "$ROOT_DIR/scripts/doctor-claude.sh" \
  "$ROOT_DIR/scripts/list-change-tasks.sh"
do
  assert_not_contains "$path" "-mindepth"
  assert_not_contains "$path" "-maxdepth"
done

echo "portable shell scripts test passed"

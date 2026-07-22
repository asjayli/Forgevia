#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SYNC="$ROOT_DIR/scripts/sync-platform-assets.mjs"
MANIFEST="$ROOT_DIR/manifests/platform-assets.json"

# The shared source is the single hand-edited origin; the platform directories
# are rendered from it. This test pins three invariants:
#   1. a clean tree passes --check;
#   2. every shared entry is present on both platforms;
#   3. tampering a rendered file is caught, and re-rendering is idempotent.

test_file_exists() {
  [[ -f "$1" ]] || { echo "expected file to exist: $1" >&2; exit 1; }
}

test_file_exists "$SYNC"
test_file_exists "$MANIFEST"
test_file_exists "$ROOT_DIR/assets/shared/skills/forgevia-implement/SKILL.md"

# 1. A clean tree must pass --check.
node "$SYNC" --check

# 2. Every shared entry must exist on both platforms (parity).
for platform in codex claude; do
  for rel in $(node -e 'for (const s of require(process.argv[1]).shared) console.log(s)' "$MANIFEST"); do
    test_file_exists "$ROOT_DIR/assets/$platform/$rel/SKILL.md"
  done
done

# 3. Tampering a rendered file is detected and --check fails.
target="$ROOT_DIR/assets/codex/skills/forgevia-archive/SKILL.md"
backup="$(mktemp)"
cp "$target" "$backup"
trap 'cp "$backup" "$target"; rm -f "$backup"' EXIT
printf '\n<!-- parity tamper -->\n' >> "$target"

set +e
node "$SYNC" --check >/tmp/forgevia-parity.out 2>&1
status=$?
set -e

if [[ "$status" -eq 0 ]]; then
  echo "FAIL: --check did not detect a tampered rendered file" >&2
  exit 1
fi
grep -q "DRIFT.*forgevia-archive" /tmp/forgevia-parity.out || {
  echo "FAIL: expected DRIFT report for forgevia-archive" >&2
  cat /tmp/forgevia-parity.out >&2
  exit 1
}

# Restore and confirm the tree is clean again.
cp "$backup" "$target"
trap - EXIT
rm -f "$backup"
node "$SYNC" --check

# 4. Re-rendering is idempotent: rendering again leaves content unchanged.
node "$SYNC" >/dev/null
node "$SYNC" --check

echo "platform asset parity test passed"

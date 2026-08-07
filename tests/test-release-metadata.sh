#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$ROOT_DIR/scripts/check-release-metadata.sh"

# The check script resolves the repo root from its own location, so negative
# cases tamper real metadata files and restore them on exit (same pattern as
# tests/test-platform-asset-parity.sh).

BACKUP_DIR="$(mktemp -d)"
TAMPERED=()

restore_all() {
  local rel
  for rel in "${TAMPERED[@]}"; do
    cp "$BACKUP_DIR/$(basename "$rel")" "$ROOT_DIR/$rel"
  done
  rm -rf "$BACKUP_DIR"
}
trap restore_all EXIT

tamper() {
  local rel="$1"
  if [[ ! -e "$BACKUP_DIR/$(basename "$rel")" ]]; then
    cp "$ROOT_DIR/$rel" "$BACKUP_DIR/$(basename "$rel")"
    TAMPERED+=("$rel")
  fi
}

expect_check_failure() {
  local label="$1"
  set +e
  bash "$CHECK" >"$BACKUP_DIR/check.out" 2>&1
  local status=$?
  set -e
  if [[ "$status" -eq 0 ]]; then
    echo "FAIL: check passed despite tampered $label" >&2
    exit 1
  fi
}

version="$(cat "$ROOT_DIR/VERSION")"

# 1. A clean tree passes the check.
bash "$CHECK"

# 2. A malformed VERSION is rejected.
tamper VERSION
printf 'not-a-version\n' > "$ROOT_DIR/VERSION"
expect_check_failure "VERSION"
cp "$BACKUP_DIR/VERSION" "$ROOT_DIR/VERSION"

# 3. A CHANGELOG without the current version is rejected.
tamper CHANGELOG.md
sed -i "s/\[$version\]/[0.0.0-tampered]/" "$ROOT_DIR/CHANGELOG.md"
expect_check_failure "CHANGELOG.md"
cp "$BACKUP_DIR/CHANGELOG.md" "$ROOT_DIR/CHANGELOG.md"

# 4. A manifest fireflyVersion that disagrees with VERSION is rejected.
tamper manifests/codex.json
sed -i "s/\"fireflyVersion\": \"$version\"/\"fireflyVersion\": \"0.0.0-tampered\"/" \
  "$ROOT_DIR/manifests/codex.json"
expect_check_failure "manifests/codex.json"
cp "$BACKUP_DIR/codex.json" "$ROOT_DIR/manifests/codex.json"

# 5. THIRD_PARTY_NOTICES without a declared override component is rejected.
tamper THIRD_PARTY_NOTICES.md
sed -i '/superpowers/d' "$ROOT_DIR/THIRD_PARTY_NOTICES.md"
expect_check_failure "THIRD_PARTY_NOTICES.md"
cp "$BACKUP_DIR/THIRD_PARTY_NOTICES.md" "$ROOT_DIR/THIRD_PARTY_NOTICES.md"

# 6. Everything restored: the tree is clean again.
bash "$CHECK"

restore_all
trap - EXIT

echo "release metadata test passed"

#!/usr/bin/env bash

# Validates firefly release metadata consistency:
#   - VERSION is a well-formed semantic version.
#   - Both platform manifests expose the same fireflyVersion as VERSION.
#   - README.md / README_EN.md display the current version.
#   - CHANGELOG.md documents the current version.
#   - LICENSE is present and identifies Apache-2.0.
#   - THIRD_PARTY_NOTICES.md declares every vendored/override upstream
#     (playwright-interactive, OpenSpec, superpowers), and the vendored
#     playwright-interactive LICENSE.txt/NOTICE.txt are retained.
#   - The OpenSpec override target version still matches the pinned OpenSpec
#     version in each manifest.
#
# Dependency-light on purpose (bash + grep + sed): it runs in CI-like
# environments before any toolchain is guaranteed.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

failures=0

fail() {
  echo "FAIL: $1" >&2
  failures=$((failures + 1))
}

require_file() {
  [[ -f "$1" ]] || fail "missing required file: ${1#"$ROOT_DIR"/}"
}

require_contains() {
  local path="$1"
  local needle="$2"
  local label="$3"
  grep -Fq -- "$needle" "$path" || fail "expected $label to contain: $needle"
}

# Extracts the first JSON string value for a field name (no JSON parser needed).
json_string_field() {
  local path="$1"
  local field="$2"
  sed -n "s/.*\"$field\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" "$path" | head -n 1
}

# 1. Required metadata files exist.
require_file "$ROOT_DIR/VERSION"
require_file "$ROOT_DIR/CHANGELOG.md"
require_file "$ROOT_DIR/LICENSE"
require_file "$ROOT_DIR/THIRD_PARTY_NOTICES.md"
require_file "$ROOT_DIR/manifests/codex.json"
require_file "$ROOT_DIR/manifests/claude.json"
require_file "$ROOT_DIR/README.md"
require_file "$ROOT_DIR/README_EN.md"

if [[ "$failures" -gt 0 ]]; then
  echo "release metadata check failed: $failures problem(s)" >&2
  exit 1
fi

# 2. VERSION is a well-formed semantic version on a single line.
version="$(cat "$ROOT_DIR/VERSION")"
if [[ "$(wc -l < "$ROOT_DIR/VERSION")" -ne 1 ]]; then
  fail "VERSION must contain exactly one line"
fi
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?(\+[0-9A-Za-z.-]+)?$ ]]; then
  fail "VERSION is not a valid semantic version: $version"
fi

# 3. Both manifests expose fireflyVersion equal to VERSION.
codex_version="$(json_string_field "$ROOT_DIR/manifests/codex.json" fireflyVersion)"
claude_version="$(json_string_field "$ROOT_DIR/manifests/claude.json" fireflyVersion)"
[[ "$codex_version" == "$version" ]] \
  || fail "manifests/codex.json fireflyVersion is '$codex_version', expected '$version'"
[[ "$claude_version" == "$version" ]] \
  || fail "manifests/claude.json fireflyVersion is '$claude_version', expected '$version'"

# 4. READMEs display the current version.
require_contains "$ROOT_DIR/README.md" "$version" "README.md"
require_contains "$ROOT_DIR/README_EN.md" "$version" "README_EN.md"

# 5. CHANGELOG documents the current version.
require_contains "$ROOT_DIR/CHANGELOG.md" "[$version]" "CHANGELOG.md"

# 6. LICENSE identifies Apache-2.0.
require_contains "$ROOT_DIR/LICENSE" "Apache License" "LICENSE"
require_contains "$ROOT_DIR/LICENSE" "Version 2.0" "LICENSE"

# 7. Every vendored/override third-party component is declared.
for component in "playwright-interactive" "OpenSpec" "superpowers" "Microsoft"; do
  require_contains "$ROOT_DIR/THIRD_PARTY_NOTICES.md" "$component" "THIRD_PARTY_NOTICES.md"
done

# 8. The vendored playwright-interactive license files are retained on both platforms.
for platform in codex claude; do
  require_file "$ROOT_DIR/assets/$platform/skills/playwright-interactive/LICENSE.txt"
  require_file "$ROOT_DIR/assets/$platform/skills/playwright-interactive/NOTICE.txt"
done

# 9. OpenSpec override target version still matches the pinned OpenSpec version.
for platform in codex claude; do
  manifest="$ROOT_DIR/manifests/$platform.json"
  pinned="$(json_string_field "$manifest" version)"
  override="$(json_string_field "$manifest" overrideTargetVersion)"
  [[ -n "$pinned" && -n "$override" ]] \
    || fail "manifests/$platform.json is missing an OpenSpec version or overrideTargetVersion"
  [[ "$pinned" == "$override" ]] \
    || fail "manifests/$platform.json OpenSpec override targets '$override' but pins '$pinned'"
done

if [[ "$failures" -gt 0 ]]; then
  echo "release metadata check failed: $failures problem(s)" >&2
  exit 1
fi

echo "release metadata check passed (version $version)"

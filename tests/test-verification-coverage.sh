#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Pins the verification coverage ledger introduced in task group 6 on both
# rendered platforms. forgevia-implement, forgevia-review, openspec-apply-change
# and subagent-driven-development must each carry the five coverage statuses,
# the no-downgrade rule, and the browser-evidence rule. forgevia-implement
# additionally emits the ledger and the trusted-prior ratio warning;
# forgevia-verify-web produces browser-evidence; the code-reviewer prompt checks
# coverage row by row.

assert_contains() {
  local path="$1"
  local needle="$2"
  [[ -f "$path" ]] || { echo "missing file: $path" >&2; exit 1; }
  grep -qF "$needle" "$path" || {
    echo "expected [$needle] in $path" >&2
    exit 1
  }
}

for platform in codex claude; do
  implement="$ROOT_DIR/assets/$platform/skills/forgevia-implement/SKILL.md"
  review="$ROOT_DIR/assets/$platform/skills/forgevia-review/SKILL.md"
  apply="$ROOT_DIR/assets/$platform/skills/openspec-apply-change/SKILL.md"
  sdd="$ROOT_DIR/assets/$platform/superpowers/skills/subagent-driven-development/SKILL.md"

  for skill in "$implement" "$review" "$apply" "$sdd"; do
    # Five coverage statuses.
    assert_contains "$skill" "machine-reverified"
    assert_contains "$skill" "browser-evidence"
    assert_contains "$skill" "external-evidence"
    assert_contains "$skill" "trusted-prior"
    assert_contains "$skill" "unverified"
    # Hard gate: no machine-verifiable criterion downgraded to trusted-prior.
    assert_contains "$skill" "downgraded to \`trusted-prior\`"
    # Web/UI changes that declared browser verification need browser-evidence.
    assert_contains "$skill" "declared browser verification"
  done

  # forgevia-implement emits the ledger and warns on the trusted-prior ratio.
  assert_contains "$implement" "## Verification Coverage"
  assert_contains "$implement" "trusted-prior / total > 30%"

  # forgevia-verify-web produces browser-evidence artifacts.
  verify_web="$ROOT_DIR/assets/$platform/skills/forgevia-verify-web/SKILL.md"
  assert_contains "$verify_web" "record the steps executed, the observed result, and an artifact path"

  # code-reviewer prompt checks coverage row by row.
  reviewer="$ROOT_DIR/assets/$platform/superpowers/skills/requesting-code-review/code-reviewer.md"
  assert_contains "$reviewer" "Verification coverage"
  assert_contains "$reviewer" "machine-reverified"
  assert_contains "$reviewer" "Is \`unverified\` zero?"
done

# Rendered copies must stay in sync with the shared source.
node "$ROOT_DIR/scripts/sync-platform-assets.mjs" --check

echo "verification coverage test passed"

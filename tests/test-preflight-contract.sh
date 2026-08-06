#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Pins the baseline preflight contract introduced in task group 5 on both
# rendered platforms. forgevia-implement, executing-plans,
# subagent-driven-development and openspec-apply-change must each carry:
#   - the once-before-first-modification baseline verification
#   - a Preflight section recorded in the SDD progress ledger
#   - HEAD + worktree + Verification Contract identity, with resumption skip
#   - the four-way red classification (clean / in-scope-red / unrelated-red /
#     user-worktree-red)
#   - the known-red visibility rule (stays in the final report)

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
  executing="$ROOT_DIR/assets/$platform/superpowers/skills/executing-plans/SKILL.md"
  sdd="$ROOT_DIR/assets/$platform/superpowers/skills/subagent-driven-development/SKILL.md"
  apply="$ROOT_DIR/assets/$platform/skills/openspec-apply-change/SKILL.md"

  for skill in "$implement" "$executing" "$sdd" "$apply"; do
    # Once, before the first candidate modification.
    assert_contains "$skill" "baseline verification once"
    # Recorded under a Preflight section in the SDD progress ledger.
    assert_contains "$skill" "Preflight"
    assert_contains "$skill" ".superpowers/sdd/progress.md"
    # Identified by HEAD + worktree + Verification Contract; resumption skips rerun.
    assert_contains "$skill" "Verification Contract"
    assert_contains "$skill" "already completed, do not rerun"
    # Four-way red classification.
    assert_contains "$skill" "in-scope-red"
    assert_contains "$skill" "unrelated-red"
    assert_contains "$skill" "user-worktree-red"
    # Known-red stays visible in the final report.
    assert_contains "$skill" "known-red"
    assert_contains "$skill" "stays visible in the final report"
  done
done

# Rendered copies must stay in sync with the shared source.
node "$ROOT_DIR/scripts/sync-platform-assets.mjs" --check

echo "preflight contract test passed"

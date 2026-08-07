#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Pins the review-strategy invariants introduced in task group 9
# (development vs review separation):
#   1. Development does not dispatch an independent reviewer per task/group;
#      implementer advances on completion plus targeted verification.
#   2. Independent review happens once, at the final whole-branch stage.
#   3. The final repair-review loop ends on APPROVE, or once every Critical and
#      Important finding is fixed and confirmed, after at most three further
#      rounds (severity-gated closing).
#   4. Remaining Minor findings are recorded in the coverage ledger, not dropped.
# Also pins that task-reviewer-prompt.md has been removed from both platforms.

assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || {
    echo "expected [$needle] in $3" >&2
    exit 1
  }
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" != *"$needle"* ]] || {
    echo "expected [$needle] to be absent in $3" >&2
    exit 1
  }
}

closing='once every Critical and Important finding has been fixed and confirmed by a fresh re-review, after at most three further review rounds'
minor='Minor findings are recorded as follow-up items in the coverage ledger, not silently dropped'

for platform in codex claude; do
  sdd="$ROOT_DIR/assets/$platform/superpowers/skills/subagent-driven-development/SKILL.md"
  ep="$ROOT_DIR/assets/$platform/superpowers/skills/executing-plans/SKILL.md"
  impl="$ROOT_DIR/assets/$platform/skills/firefly-implement/SKILL.md"
  router="$ROOT_DIR/assets/$platform/skills/firefly/SKILL.md"
  review="$ROOT_DIR/assets/$platform/skills/firefly-review/SKILL.md"
  apply="$ROOT_DIR/assets/$platform/skills/openspec-apply-change/SKILL.md"

  sdd_c="$(<"$sdd")"
  ep_c="$(<"$ep")"
  impl_c="$(<"$impl")"
  router_c="$(<"$router")"
  review_c="$(<"$review")"
  apply_c="$(<"$apply")"

  # 1 + 2: no per-task reviewer; independent review only at the final whole-branch stage.
  assert_contains "$sdd_c" 'it does not dispatch a task-level reviewer' "$sdd"
  assert_contains "$sdd_c" 'Independent review happens once, at the final whole-branch stage.' "$sdd"
  assert_not_contains "$sdd_c" 'dispatch task reviewer subagent (./task-reviewer-prompt.md)' "$sdd"

  assert_contains "$ep_c" 'Independent review is not per-task or per-group' "$ep"
  assert_contains "$ep_c" 'it happens once, at the final whole-branch stage (Step 5)' "$ep"

  assert_contains "$impl_c" 'Use an independent reviewer once for the complete branch before completion' "$impl"
  assert_not_contains "$impl_c" 'at dependency-ready task groups and for the complete branch' "$impl"

  assert_contains "$router_c" 'use `requesting-code-review` once for the complete branch before completion' "$router"
  assert_not_contains "$router_c" 'use `requesting-code-review` at dependency-ready checkpoints' "$router"

  assert_not_contains "$apply_c" 'dispatch an independent review agent different from the candidate producer' "$apply"

  # 3 + 4: severity-gated closing + Minor into coverage ledger, stated consistently.
  assert_contains "$sdd_c" "$closing" "$sdd"
  assert_contains "$sdd_c" "$minor" "$sdd"
  assert_contains "$ep_c" "$closing" "$ep"
  assert_contains "$ep_c" "$minor" "$ep"
  assert_contains "$impl_c" "$closing" "$impl"
  assert_contains "$impl_c" "$minor" "$impl"
  assert_contains "$review_c" "$closing" "$review"
  assert_contains "$review_c" "$minor" "$review"
  assert_contains "$apply_c" "$closing" "$apply"
  assert_contains "$apply_c" "$minor" "$apply"
done

# task-reviewer-prompt.md removed from both platforms.
for platform in codex claude; do
  target="$ROOT_DIR/assets/$platform/superpowers/skills/subagent-driven-development/task-reviewer-prompt.md"
  [[ ! -f "$target" ]] || {
    echo "expected task-reviewer-prompt.md removed: $target" >&2
    exit 1
  }
done

echo "review strategy test passed"

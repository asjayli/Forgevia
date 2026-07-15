#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

assert_file_contains() {
  local path="$1"
  local needle="$2"

  if [[ ! -f "$path" ]]; then
    echo "expected file to exist: $path" >&2
    exit 1
  fi
  if [[ "$(cat "$path")" != *"$needle"* ]]; then
    echo "expected $path to contain: $needle" >&2
    exit 1
  fi
}

assert_file_not_contains() {
  local path="$1"
  local needle="$2"

  if [[ "$(cat "$path")" == *"$needle"* ]]; then
    echo "expected $path to not contain: $needle" >&2
    exit 1
  fi
}

assert_occurrences_at_least() {
  local path="$1"
  local needle="$2"
  local minimum="$3"
  local count

  count="$({ grep -F -o -- "$needle" "$path" || true; } | wc -l | tr -d ' ')"
  if (( count < minimum )); then
    echo "expected $path to contain $needle at least $minimum times, found $count" >&2
    exit 1
  fi
}

forgevia_paths=(
  "$ROOT_DIR/assets/codex/skills/forgevia/SKILL.md"
  "$ROOT_DIR/.claude/skills/forgevia/SKILL.md"
)

for path in "${forgevia_paths[@]}"; do
  assert_file_contains "$path" "objective authorization envelope"
  assert_file_contains "$path" 'APPROVE'
  assert_file_contains "$path" 'REVISE'
  assert_file_contains "$path" 'ESCALATE'
  assert_file_contains "$path" "Only ESCALATE pauses the workflow for user input"
  assert_file_contains "$path" "does not authorize archive, push, merge, or release"
  assert_file_contains "$path" "different from the agent that produced the candidate"
done

forgevia_propose_paths=(
  "$ROOT_DIR/assets/codex/skills/forgevia-propose/SKILL.md"
  "$ROOT_DIR/.claude/skills/forgevia-propose/SKILL.md"
)

for path in "${forgevia_propose_paths[@]}"; do
  assert_file_contains "$path" '`APPROVE`'
  assert_file_contains "$path" '`REVISE`'
  assert_file_contains "$path" '`ESCALATE`'
  assert_file_contains "$path" "cannot be recovered from the provided input, referenced files, conversation, or repository evidence"
  assert_file_contains "$path" "the missing evidence, a recommended default, option impacts, and why work cannot continue"
  assert_file_not_contains "$path" "Stop and clarify"
done

forgevia_archive_paths=(
  "$ROOT_DIR/assets/codex/skills/forgevia-archive/SKILL.md"
  "$ROOT_DIR/.claude/skills/forgevia-archive/SKILL.md"
)

for path in "${forgevia_archive_paths[@]}"; do
  assert_file_contains "$path" '`APPROVE`'
  assert_file_contains "$path" '`REVISE`'
  assert_file_contains "$path" '`ESCALATE`'
  assert_file_contains "$path" "Repair only issues in the sync result or archive package that are inside the archive authorization envelope"
  assert_file_contains "$path" 'For any other validation failure, diagnose it and return `ESCALATE` with evidence instead of editing outside that envelope'
  assert_file_not_contains "$path" 'automatically repair an authorized `REVISE` or validation failure before review'
done

forgevia_implement_paths=(
  "$ROOT_DIR/assets/codex/skills/forgevia-implement/SKILL.md"
  "$ROOT_DIR/.claude/skills/forgevia-implement/SKILL.md"
)

for path in "${forgevia_implement_paths[@]}"; do
  assert_file_contains "$path" '`APPROVE`'
  assert_file_contains "$path" '`REVISE`'
  assert_file_contains "$path" '`ESCALATE`'
  assert_file_contains "$path" "first test failure"
  assert_file_contains "$path" "automatically continue to the next dependency-ready work unit"
  assert_file_contains "$path" 'Only `ESCALATE` requests user input'
done

for skill_name in forgevia-review forgevia-verify-web; do
  for path in \
    "$ROOT_DIR/assets/codex/skills/$skill_name/SKILL.md" \
    "$ROOT_DIR/.claude/skills/$skill_name/SKILL.md"
  do
    assert_file_contains "$path" '`APPROVE`'
    assert_file_contains "$path" '`REVISE`'
    assert_file_contains "$path" '`ESCALATE`'
    assert_file_contains "$path" "standalone read-only command"
    assert_file_contains "$path" 'return `REVISE` findings without'
    assert_file_contains "$path" 'only `ESCALATE` requests a user decision'
  done
done

assert_file_contains "$ROOT_DIR/assets/codex/skills/forgevia/SKILL.md" '`spawn_agent`'
assert_file_contains "$ROOT_DIR/.claude/skills/forgevia/SKILL.md" '`Task`'

for path in \
  "$ROOT_DIR/assets/codex/skills/forgevia-think/SKILL.md" \
  "$ROOT_DIR/.claude/skills/forgevia-think/SKILL.md"
do
  assert_file_contains "$path" "independent review"
  assert_file_contains "$path" '`APPROVE`'
  assert_file_contains "$path" '`REVISE`'
  assert_file_contains "$path" '`ESCALATE`'
  assert_file_contains "$path" "write the think artifact without waiting for user confirmation"
  assert_file_not_contains "$path" "Wait for explicit confirmation"
  assert_file_not_contains "$path" "Do not skip the confirmation step"
done

openspec_apply_paths=(
  "$ROOT_DIR/assets/codex/skills/openspec-apply-change/SKILL.md"
  "$ROOT_DIR/.codex/skills/openspec-apply-change/SKILL.md"
  "$ROOT_DIR/.claude/skills/openspec-apply-change/SKILL.md"
  "$ROOT_DIR/.claude/commands/opsx/apply.md"
)

for path in "${openspec_apply_paths[@]}"; do
  assert_file_contains "$path" "first test failure"
  assert_file_contains "$path" "diagnose, fix, run targeted verification"
  assert_file_contains "$path" "independent review"
  assert_file_contains "$path" '`APPROVE`'
  assert_file_contains "$path" '`REVISE`'
  assert_file_contains "$path" '`ESCALATE`'
  assert_file_contains "$path" 'Only `ESCALATE` pauses for user input'
  assert_file_not_contains "$path" "Error or blocker encountered"
  assert_file_not_contains "$path" "Pause on errors, blockers, or unclear requirements"
done

assert_file_contains "$ROOT_DIR/assets/codex/skills/openspec-apply-change/SKILL.md" '`spawn_agent`'
assert_file_contains "$ROOT_DIR/.codex/skills/openspec-apply-change/SKILL.md" '`spawn_agent`'
assert_file_contains "$ROOT_DIR/.claude/skills/openspec-apply-change/SKILL.md" '`Task`'
assert_file_contains "$ROOT_DIR/.claude/commands/opsx/apply.md" '`Task`'

openspec_archive_paths=(
  "$ROOT_DIR/assets/codex/skills/openspec-archive-change/SKILL.md"
  "$ROOT_DIR/.codex/skills/openspec-archive-change/SKILL.md"
  "$ROOT_DIR/.claude/skills/openspec-archive-change/SKILL.md"
  "$ROOT_DIR/.claude/commands/opsx/archive.md"
)

for path in "${openspec_archive_paths[@]}"; do
  assert_file_contains "$path" "Auto-select if only one active change exists"
  assert_file_contains "$path" "sync delta specs by default"
  assert_file_contains "$path" "independent review"
  assert_file_contains "$path" '`APPROVE`'
  assert_file_contains "$path" '`REVISE`'
  assert_file_contains "$path" '`ESCALATE`'
  assert_file_contains "$path" 'Only `ESCALATE` pauses for user input'
  assert_file_not_contains "$path" "Ask the user to confirm"
  assert_file_not_contains "$path" "Prompt user for confirmation"
  assert_file_not_contains "$path" "Archive without syncing"
  assert_file_not_contains "$path" "Proceed if user confirms"
  assert_file_not_contains "$path" "Do NOT guess or auto-select a change"
done

assert_file_contains "$ROOT_DIR/assets/codex/skills/openspec-archive-change/SKILL.md" '`spawn_agent`'
assert_file_contains "$ROOT_DIR/.codex/skills/openspec-archive-change/SKILL.md" '`spawn_agent`'
assert_file_contains "$ROOT_DIR/.claude/skills/openspec-archive-change/SKILL.md" '`Task`'
assert_file_contains "$ROOT_DIR/.claude/commands/opsx/archive.md" '`Task`'

openspec_propose_paths=(
  "$ROOT_DIR/assets/codex/skills/openspec-propose/SKILL.md"
  "$ROOT_DIR/.codex/skills/openspec-propose/SKILL.md"
  "$ROOT_DIR/.claude/skills/openspec-propose/SKILL.md"
  "$ROOT_DIR/.claude/commands/opsx/propose.md"
)

for path in "${openspec_propose_paths[@]}"; do
  assert_file_contains "$path" "independent review"
  assert_file_contains "$path" '`APPROVE`'
  assert_file_contains "$path" '`REVISE`'
  assert_file_contains "$path" '`ESCALATE`'
  assert_file_contains "$path" 'Only `ESCALATE` pauses for user input'
done

assert_file_contains "$ROOT_DIR/assets/codex/skills/openspec-propose/SKILL.md" '`spawn_agent`'
assert_file_contains "$ROOT_DIR/.codex/skills/openspec-propose/SKILL.md" '`spawn_agent`'
assert_file_contains "$ROOT_DIR/.claude/skills/openspec-propose/SKILL.md" '`Task`'
assert_file_contains "$ROOT_DIR/.claude/commands/opsx/propose.md" '`Task`'

propose_template="$ROOT_DIR/assets/openspec/dist/core/templates/workflows/propose.js"
assert_occurrences_at_least "$propose_template" "independent review" 2
assert_occurrences_at_least "$propose_template" '\`APPROVE\`' 2
assert_occurrences_at_least "$propose_template" '\`REVISE\`' 2
assert_occurrences_at_least "$propose_template" '\`ESCALATE\`' 2
assert_occurrences_at_least "$propose_template" 'Only \`ESCALATE\` pauses for user input' 2

echo "autonomous workflow contract test passed"

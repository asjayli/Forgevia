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

assert_files_equal() {
  local expected="$1"
  local actual="$2"

  if ! cmp -s "$expected" "$actual"; then
    echo "expected managed mirror files to match: $expected $actual" >&2
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

assert_file_in_order() {
  local path="$1"
  shift
  local remaining
  local needle

  remaining="$(<"$path")"
  for needle in "$@"; do
    if [[ "$remaining" != *"$needle"* ]]; then
      echo "expected $path to contain in order: $needle" >&2
      exit 1
    fi
    remaining="${remaining#*"$needle"}"
  done
}

assert_review_contract() {
  local path="$1"

  assert_file_in_order "$path" \
    'Objective: the authorized outcome.' \
    'Scope: the allowed repositories, changes, files, and systems.' \
    'Constraints: the binding process, architecture, safety, and platform rules.' \
    'Authorized effects: the writes and side effects allowed to the controller.' \
    'Terminal condition: the state at which this workflow must stop.' \
    'candidate producer identity' \
    'candidate artifacts, action, or diff' \
    'verification evidence' \
    'assumptions and risks'
  assert_file_in_order "$path" \
    'reviewer fails to start, times out, crashes, or returns an invalid verdict' \
    'reuse the unchanged review package' \
    'at most two new independent review agents' \
    'collected infrastructure evidence' \
    'never infer `APPROVE`'
  assert_file_contains "$path" 'The controller validates only reviewer identity, verdict structure, and supporting evidence; it does not recursively review the verdict.'
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
  assert_review_contract "$path"
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
  assert_review_contract "$path"
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
  assert_review_contract "$path"
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
  assert_review_contract "$path"
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
    assert_review_contract "$path"
    assert_file_contains "$path" 'A `REVISE` verdict returns findings and stops without editing product files, `tasks.md`, or `.superpowers/sdd/progress.md`.'
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
  assert_review_contract "$path"
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
  assert_review_contract "$path"
  assert_file_in_order "$path" \
    'Complete every task and its task-level review.' \
    'Run integration and global verification across the complete implementation.' \
    'Build a commit-bounded full-branch review package covering the complete implementation range, or a WORKTREE package when commit authorization or branch policy left changes uncommitted.' \
    'Dispatch a fresh full-branch reviewer that is independent from every candidate producer.' \
    'Only a final `APPROVE` may produce `Implementation Complete`.'
  assert_file_in_order "$path" \
    'A final `REVISE` with repair authorization dispatches implementation repair.' \
    'Rerun integration and global verification.' \
    'Build a fresh full-branch package and dispatch a fresh independent full-branch reviewer.'
  assert_file_contains "$path" 'When apply instructions report `state: "all_done"`, resume at integration and global verification; do not congratulate, suggest archive, or report completion yet.'
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
  assert_review_contract "$path"
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
  assert_review_contract "$path"
  assert_file_in_order "$path" \
    'Validate the current planning package before dispatching its reviewer.' \
    'If validation fails, repair only the matching planning artifact type and rerun the same validation.' \
    'Dispatch an independent review only after that planning validation passes.' \
    'After all apply-required artifacts are complete, run `openspec validate "<name>" --strict --no-interactive` for the complete change' \
    'If strict validation fails, repair the indicated proposal, design, specs, or tasks and rerun strict validation.' \
    'Independently review every package changed by strict-validation repair before reporting the proposal apply-ready.'
done

assert_file_contains "$ROOT_DIR/assets/codex/skills/openspec-propose/SKILL.md" '`spawn_agent`'
assert_file_contains "$ROOT_DIR/.codex/skills/openspec-propose/SKILL.md" '`spawn_agent`'
assert_file_contains "$ROOT_DIR/.claude/skills/openspec-propose/SKILL.md" '`Task`'
assert_file_contains "$ROOT_DIR/.claude/commands/opsx/propose.md" '`Task`'

openspec_sync_paths=(
  "$ROOT_DIR/assets/codex/skills/openspec-sync-specs/SKILL.md"
  "$ROOT_DIR/.codex/skills/openspec-sync-specs/SKILL.md"
  "$ROOT_DIR/.claude/skills/openspec-sync-specs/SKILL.md"
  "$ROOT_DIR/.claude/commands/opsx/sync.md"
)

for path in "${openspec_sync_paths[@]}"; do
  assert_file_contains "$path" "Auto-select if only one active change exists"
  assert_file_contains "$path" "independent review"
  assert_file_contains "$path" "Review the sync plan before editing main specs"
  assert_file_contains "$path" "delta-to-target mapping, content preservation, applicability, and idempotency preconditions"
  assert_file_contains "$path" 'If sync-plan validation fails or the plan review returns `REVISE`, repair the sync plan, rerun the same validation, and dispatch a fresh independent review'
  assert_file_contains "$path" 'Apply changes only after the sync-plan review returns `APPROVE`'
  assert_file_contains "$path" "If strict validation, idempotency, or content-preservation verification fails, repair the sync result, rerun the same failed validation, and only then dispatch the result review"
  assert_file_contains "$path" "reuse the unchanged review package"
  assert_file_contains "$path" "at most two new independent review agents"
  assert_file_contains "$path" "collected infrastructure evidence"
  assert_file_contains "$path" 'never infer `APPROVE`'
  assert_review_contract "$path"
  assert_file_contains "$path" '`APPROVE`'
  assert_file_contains "$path" '`REVISE`'
  assert_file_contains "$path" '`ESCALATE`'
  assert_file_contains "$path" 'Only `ESCALATE` pauses for user input'
  assert_file_not_contains "$path" "Always let the user choose"
  assert_file_not_contains "$path" "If something is unclear, ask for clarification"
done

assert_file_contains "$ROOT_DIR/assets/codex/skills/openspec-sync-specs/SKILL.md" '`spawn_agent`'
assert_file_contains "$ROOT_DIR/.codex/skills/openspec-sync-specs/SKILL.md" '`spawn_agent`'
assert_file_contains "$ROOT_DIR/.claude/skills/openspec-sync-specs/SKILL.md" '`Task`'
assert_file_contains "$ROOT_DIR/.claude/commands/opsx/sync.md" '`Task`'
assert_file_not_contains "$ROOT_DIR/INSTALL.claude.md" "artifact, confirmation, and versioning rules"
assert_file_contains "$ROOT_DIR/INSTALL.claude.md" "artifact, independent-review, and versioning rules"

propose_template="$ROOT_DIR/assets/openspec/dist/core/templates/workflows/propose.js"
assert_occurrences_at_least "$propose_template" "independent review" 2
assert_occurrences_at_least "$propose_template" '\`APPROVE\`' 2
assert_occurrences_at_least "$propose_template" '\`REVISE\`' 2
assert_occurrences_at_least "$propose_template" '\`ESCALATE\`' 2
assert_occurrences_at_least "$propose_template" 'Only \`ESCALATE\` pauses for user input' 2
assert_file_in_order "$propose_template" \
  'Objective: the authorized outcome.' \
  'Scope: the allowed repositories, changes, files, and systems.' \
  'Constraints: the binding process, architecture, safety, and platform rules.' \
  'Authorized effects: the writes and side effects allowed to the controller.' \
  'Terminal condition: the state at which this workflow must stop.' \
  'candidate producer identity' \
  'candidate artifacts, action, or diff' \
  'verification evidence' \
  'assumptions and risks'
assert_file_in_order "$propose_template" \
  'reviewer fails to start, times out, crashes, or returns an invalid verdict' \
  'reuse the unchanged review package' \
  'at most two new independent review agents' \
  'collected infrastructure evidence' \
  'never infer \`APPROVE\`'
assert_file_contains "$propose_template" 'The controller validates only reviewer identity, verdict structure, and supporting evidence; it does not recursively review the verdict.'
assert_file_in_order "$propose_template" \
  'Validate the current planning package before dispatching its reviewer.' \
  'If validation fails, repair only the matching planning artifact type and rerun the same validation.' \
  'Dispatch an independent review only after that planning validation passes.' \
  'After all apply-required artifacts are complete, run \`openspec validate "<name>" --strict --no-interactive\` for the complete change' \
  'If strict validation fails, repair the indicated proposal, design, specs, or tasks and rerun strict validation.' \
  'Independently review every package changed by strict-validation repair before reporting the proposal apply-ready.'

for skill_name in \
  openspec-apply-change \
  openspec-archive-change \
  openspec-explore \
  openspec-propose \
  openspec-sync-specs
do
  assert_files_equal \
    "$ROOT_DIR/assets/codex/skills/$skill_name/SKILL.md" \
    "$ROOT_DIR/.codex/skills/$skill_name/SKILL.md"
done

tracked_internal_planning="$(git -C "$ROOT_DIR" ls-files -- \
  'openspec/**' \
  'docs/plans/**' \
  '.forgevia/**' \
  '.superpowers/**')"
if [[ -n "$tracked_internal_planning" ]]; then
  echo "repository-local planning or runtime artifacts must not be tracked:" >&2
  echo "$tracked_internal_planning" >&2
  exit 1
fi

for internal_path in openspec/ docs/plans/ .forgevia/ .superpowers/; do
  if ! git -C "$ROOT_DIR" check-ignore -q "$internal_path"; then
    echo "expected repository-local path to be ignored: $internal_path" >&2
    exit 1
  fi
done

tracked_openspec_assets="$(git -C "$ROOT_DIR" ls-files -- 'assets/openspec/**')"
if [[ -z "$tracked_openspec_assets" ]]; then
  echo "expected product OpenSpec assets to remain tracked" >&2
  exit 1
fi

assert_file_contains "$ROOT_DIR/AGENTS.md" '不得使用 `git add -f`'
assert_file_contains "$ROOT_DIR/AGENTS.md" 'Codex 与 Claude Code 共同支持的能力交集'
assert_file_not_contains "$ROOT_DIR/README.md" "等你确认后"
assert_file_contains "$ROOT_DIR/README.md" "独立审查"
assert_file_contains "$ROOT_DIR/README.md" "无需逐步确认"
assert_file_not_contains "$ROOT_DIR/README_EN.md" "waits for your confirmation"
assert_file_contains "$ROOT_DIR/README_EN.md" "independent review"
assert_file_contains "$ROOT_DIR/README_EN.md" "without step-by-step confirmation"

echo "autonomous workflow contract test passed"

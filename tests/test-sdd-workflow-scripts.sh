#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_SCRIPTS="$ROOT_DIR/assets/codex/superpowers/skills/subagent-driven-development/scripts"
CLAUDE_SCRIPTS="$ROOT_DIR/assets/claude/superpowers/skills/subagent-driven-development/scripts"
TASK_BRIEF="$CODEX_SCRIPTS/task-brief"
REVIEW_PACKAGE="$CODEX_SCRIPTS/review-package"
SDD_WORKSPACE="$CODEX_SCRIPTS/sdd-workspace"
CODEX_SDD_SKILL="$ROOT_DIR/assets/codex/superpowers/skills/subagent-driven-development/SKILL.md"
CODEX_IMPLEMENTER_PROMPT="$ROOT_DIR/assets/codex/superpowers/skills/subagent-driven-development/implementer-prompt.md"
CODEX_REVIEWER_PROMPT="$ROOT_DIR/assets/codex/superpowers/skills/subagent-driven-development/task-reviewer-prompt.md"
CODEX_BRANCH_REVIEWER_PROMPT="$ROOT_DIR/assets/codex/superpowers/skills/requesting-code-review/code-reviewer.md"

EXECUTING_PLAN_SKILLS=(
  "$ROOT_DIR/assets/codex/superpowers/skills/executing-plans/SKILL.md"
  "$ROOT_DIR/assets/claude/superpowers/skills/executing-plans/SKILL.md"
)

SDD_SKILLS=(
  "$ROOT_DIR/assets/codex/superpowers/skills/subagent-driven-development/SKILL.md"
  "$ROOT_DIR/assets/claude/superpowers/skills/subagent-driven-development/SKILL.md"
)

IMPLEMENTER_PROMPTS=(
  "$ROOT_DIR/assets/codex/superpowers/skills/subagent-driven-development/implementer-prompt.md"
  "$ROOT_DIR/assets/claude/superpowers/skills/subagent-driven-development/implementer-prompt.md"
)

REVIEWER_PROMPTS=(
  "$ROOT_DIR/assets/codex/superpowers/skills/subagent-driven-development/task-reviewer-prompt.md"
  "$ROOT_DIR/assets/claude/superpowers/skills/subagent-driven-development/task-reviewer-prompt.md"
  "$ROOT_DIR/assets/codex/superpowers/skills/requesting-code-review/code-reviewer.md"
  "$ROOT_DIR/assets/claude/superpowers/skills/requesting-code-review/code-reviewer.md"
)

assert_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" != *"$needle"* ]]; then
    echo "expected output to contain: $needle" >&2
    exit 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" == *"$needle"* ]]; then
    echo "expected output to not contain: $needle" >&2
    exit 1
  fi
}

assert_file_exists() {
  local path="$1"

  if [[ ! -f "$path" ]]; then
    echo "expected file to exist: $path" >&2
    exit 1
  fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

for script_name in task-brief review-package sdd-workspace; do
  cmp "$CODEX_SCRIPTS/$script_name" "$CLAUDE_SCRIPTS/$script_name"
done

assert_contains "$(<"$CODEX_SDD_SKILL")" "does not expose model selection"
assert_not_contains "$(<"$CODEX_SDD_SKILL")" "Always specify the model explicitly"
assert_not_contains "$(<"$CODEX_IMPLEMENTER_PROMPT")" "model: [MODEL"
assert_not_contains "$(<"$CODEX_REVIEWER_PROMPT")" "model: [MODEL"
assert_not_contains "$(<"$CODEX_BRANCH_REVIEWER_PROMPT")" "model: [MODEL"

for path in "${EXECUTING_PLAN_SKILLS[@]}"; do
  contents="$(<"$path")"
  assert_contains "$contents" '`APPROVE` immediately advances to the next dependency-ready task group'
  assert_contains "$contents" 'Only after an `APPROVE` verdict, mark the task group complete'
  assert_contains "$contents" '`REVISE` triggers repair only inside the active authorization envelope'
  assert_contains "$contents" 'three consecutive repair cycles'
  assert_contains "$contents" '`tasks.md`, Git history, and `.superpowers/sdd/progress.md`'
  assert_contains "$contents" 'use the unchanged review package with a fresh independent reviewer for at most two infrastructure retries'
  assert_contains "$contents" 'If both retries fail, `ESCALATE` once with the collected infrastructure evidence; never infer `APPROVE`.'
  assert_not_contains "$contents" 'Ready for feedback.'
  assert_not_contains "$contents" 'Between dependency checkpoints: just report and wait'
  assert_not_contains "$contents" 'Verification fails repeatedly'
done

for path in "${SDD_SKILLS[@]}"; do
  contents="$(<"$path")"
  assert_contains "$contents" '`APPROVE` records progress and dispatches the next dependency-ready task group'
  assert_contains "$contents" '`REVISE` triggers repair only inside the active authorization envelope'
  assert_contains "$contents" 'standalone read-only run returns the findings without editing'
  assert_contains "$contents" 'three consecutive repair cycles'
  assert_contains "$contents" 'at most two infrastructure retries'
  assert_contains "$contents" '`tasks.md`, Git history, and `.superpowers/sdd/progress.md`'
  assert_contains "$contents" 'Pass an explicit objective authorization envelope containing objective, scope, constraints, authorized effects, and terminal condition to every task and final reviewer.'
  assert_contains "$contents" 'Treat each ledger completion line as evidence, not an unconditional DONE state.'
  assert_contains "$contents" 'If tasks, Git, and progress disagree, inspect the actual diff and verification evidence before deciding whether to continue, repair bookkeeping, or `ESCALATE`.'
  assert_not_contains "$contents" 'Dispatch fix subagents for Critical and Important findings.'
  assert_not_contains "$contents" 'Tasks listed there as complete are DONE'
done

for path in "${IMPLEMENTER_PROMPTS[@]}"; do
  contents="$(<"$path")"
  assert_contains "$contents" 'first test failure'
  assert_contains "$contents" 'active authorization envelope'
  assert_contains "$contents" 'Only report `BLOCKED` or `NEEDS_CONTEXT`'
  assert_not_contains "$contents" '**Ask them now.**'
  assert_not_contains "$contents" "It's always OK to pause and clarify."
done

for path in "${REVIEWER_PROMPTS[@]}"; do
  contents="$(<"$path")"
  assert_contains "$contents" '**Verdict:** [APPROVE | REVISE | ESCALATE]'
  assert_contains "$contents" '`REVISE` for every ordinary actionable finding, regardless of whether the controller is authorized to repair it.'
  assert_contains "$contents" 'A standalone read-only envelope returns `REVISE` findings without escalating merely because repair is unauthorized.'
  assert_contains "$contents" 'The controller uses the authorization envelope to either dispatch an authorized repair or return the findings unchanged.'
  assert_contains "$contents" '`ESCALATE` only when missing authorization or critical information is required to reach the already-authorized terminal condition.'
  assert_contains "$contents" '## Objective Authorization Envelope'
  assert_contains "$contents" '**Objective:** [OBJECTIVE]'
  assert_contains "$contents" '**Scope:** [SCOPE]'
  assert_contains "$contents" '**Constraints:** [CONSTRAINTS]'
  assert_contains "$contents" '**Authorized effects:** [AUTHORIZED_EFFECTS]'
  assert_contains "$contents" '**Terminal condition:** [TERMINAL_CONDITION]'
  assert_not_contains "$contents" 'confirm whether the deviation was intentional'
  assert_not_contains "$contents" 'actionable findings that can be repaired without changing the plan or authorization envelope'
done

repo_dir="$tmp_dir/repo"
mkdir -p "$repo_dir"
git -C "$repo_dir" init -q
git -C "$repo_dir" config user.email "test@example.com"
git -C "$repo_dir" config user.name "Forgevia Test"

cat > "$repo_dir/tasks.md" <<'EOF'
## 1. Prepare workspace

- [ ] 1.1 Add the workspace helper

```markdown
## 99. This fenced heading belongs to task 1
```

## 2. Review changes

- [ ] 2.1 Add the review helper
EOF

brief_output="$(cd "$repo_dir" && "$TASK_BRIEF" tasks.md 1)"
brief_path="$repo_dir/.superpowers/sdd/task-1-brief.md"
assert_contains "$brief_output" "wrote $brief_path"
assert_file_exists "$brief_path"
brief_contents="$(<"$brief_path")"
assert_contains "$brief_contents" "## 1. Prepare workspace"
assert_contains "$brief_contents" "## 99. This fenced heading belongs to task 1"
assert_not_contains "$brief_contents" "## 2. Review changes"

if (cd "$repo_dir" && "$TASK_BRIEF" tasks.md 3) >/dev/null 2>&1; then
  echo "expected task-brief to reject a missing task group" >&2
  exit 1
fi

printf 'base\n' > "$repo_dir/change.txt"
git -C "$repo_dir" add change.txt tasks.md
git -C "$repo_dir" commit -qm "base"
base_sha="$(git -C "$repo_dir" rev-parse HEAD)"

printf 'first change\n' >> "$repo_dir/change.txt"
git -C "$repo_dir" commit -am "first task commit" -q
printf 'second change\n' >> "$repo_dir/change.txt"
git -C "$repo_dir" commit -am "second task commit" -q
head_sha="$(git -C "$repo_dir" rev-parse HEAD)"

review_output="$(cd "$repo_dir" && "$REVIEW_PACKAGE" "$base_sha" "$head_sha")"
review_path="$repo_dir/.superpowers/sdd/review-$(git -C "$repo_dir" rev-parse --short "$base_sha")..$(git -C "$repo_dir" rev-parse --short "$head_sha").diff"
assert_contains "$review_output" "wrote $review_path: 2 commit(s)"
assert_file_exists "$review_path"
review_contents="$(<"$review_path")"
assert_contains "$review_contents" "first task commit"
assert_contains "$review_contents" "second task commit"
assert_contains "$review_contents" "## Diff"
assert_contains "$review_contents" "change.txt"

workspace_path="$(cd "$repo_dir" && "$SDD_WORKSPACE")"
if [[ "$workspace_path" != "$repo_dir/.superpowers/sdd" ]]; then
  echo "unexpected SDD workspace path: $workspace_path" >&2
  exit 1
fi

if [[ -n "$(git -C "$repo_dir" status --short --untracked-files=all)" ]]; then
  echo "expected SDD artifacts to remain ignored by git status" >&2
  exit 1
fi

echo "sdd workflow scripts test passed"

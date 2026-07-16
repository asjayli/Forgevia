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

TDD_SKILLS=(
  "$ROOT_DIR/assets/codex/superpowers/skills/test-driven-development/SKILL.md"
  "$ROOT_DIR/assets/claude/superpowers/skills/test-driven-development/SKILL.md"
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

TASK_REVIEWER_PROMPTS=(
  "$ROOT_DIR/assets/codex/superpowers/skills/subagent-driven-development/task-reviewer-prompt.md"
  "$ROOT_DIR/assets/claude/superpowers/skills/subagent-driven-development/task-reviewer-prompt.md"
)

REQUESTING_REVIEW_SKILLS=(
  "$ROOT_DIR/assets/codex/superpowers/skills/requesting-code-review/SKILL.md"
  "$ROOT_DIR/assets/claude/superpowers/skills/requesting-code-review/SKILL.md"
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

assert_in_order() {
  local remaining="$1"
  shift
  local needle

  for needle in "$@"; do
    if [[ "$remaining" != *"$needle"* ]]; then
      echo "expected output to contain in order: $needle" >&2
      exit 1
    fi
    remaining="${remaining#*"$needle"}"
  done
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
  assert_contains "$contents" 'The controller dispatches an authorized repair subagent for every `REVISE` finding, requires targeted verification, and dispatches a fresh independent reviewer.'
  assert_contains "$contents" 'Repeat this repair-review loop until an `APPROVE` verdict or the no-progress `ESCALATE` boundary.'
  assert_contains "$contents" 'three consecutive repair cycles'
  assert_contains "$contents" '`tasks.md`, Git history, and `.superpowers/sdd/progress.md`'
  assert_contains "$contents" 'use the unchanged review package with a fresh independent reviewer for at most two infrastructure retries'
  assert_contains "$contents" 'If both retries fail, `ESCALATE` once with the collected infrastructure evidence; never infer `APPROVE`.'
  assert_not_contains "$contents" 'Ready for feedback.'
  assert_not_contains "$contents" 'Between dependency checkpoints: just report and wait'
  assert_not_contains "$contents" 'Verification fails repeatedly'
  assert_in_order "$contents" \
    'After the final `APPROVE`, read the objective authorization envelope.' \
    'Forgevia implement and a complete Forgevia workflow default to a completion summary with the change still active.' \
    'If the envelope does not separately and explicitly authorize the relevant merge, push, or cleanup effect, return that summary without branch-finishing options.' \
    'Only when the envelope contains that explicit authorization may you invoke `superpowers:finishing-a-development-branch`.'
  assert_contains "$contents" 'The controller dispatches an authorized final repair subagent, reruns full verification, and dispatches a fresh independent final reviewer'
  assert_not_contains "$contents" 'Follow that skill to verify tests, present options, execute choice'
  assert_contains "$contents" 'Implementation runs continuously by default.'
  assert_contains "$contents" 'never ends the workflow or waits for feedback.'
  assert_contains "$contents" 'Before returning a completion summary, confirm every completion gate:'
  assert_contains "$contents" '`git diff --check` succeeds'
  assert_contains "$contents" 'The controller dispatches an authorized repair subagent for every `REVISE` finding, requires targeted verification, and dispatches a fresh independent reviewer.'
  assert_contains "$contents" 'Repeat this repair-review loop until an `APPROVE` verdict or the no-progress `ESCALATE` boundary.'
done

for path in "${SDD_SKILLS[@]}"; do
  contents="$(<"$path")"
  assert_contains "$contents" '`APPROVE` records progress and dispatches the next dependency-ready task group'
  assert_contains "$contents" 'The controller dispatches an authorized repair subagent for every `REVISE` finding, requires targeted verification, and dispatches a fresh independent reviewer.'
  assert_contains "$contents" 'standalone read-only run returns the findings without editing'
  assert_contains "$contents" 'three consecutive repair cycles'
  assert_contains "$contents" 'at most two infrastructure retries'
  assert_contains "$contents" '`tasks.md`, Git history, and `.superpowers/sdd/progress.md`'
  assert_contains "$contents" 'Pass an explicit objective authorization envelope containing objective, scope, constraints, authorized effects, and terminal condition to every task and final reviewer.'
  assert_contains "$contents" 'Treat each ledger completion line as evidence, not an unconditional DONE state.'
  assert_contains "$contents" 'If tasks, Git, and progress disagree, inspect the actual diff and verification evidence before deciding whether to continue, repair bookkeeping, or `ESCALATE`.'
  assert_not_contains "$contents" 'Dispatch fix subagents for Critical and Important findings.'
  assert_not_contains "$contents" 'Tasks listed there as complete are DONE'
  assert_contains "$contents" 'Pass the five authorization-envelope fields to every implementer and repair-subagent dispatch, not only to reviewers.'
  assert_contains "$contents" 'Before the initial implementer dispatch for each task, record a task-specific review baseline.'
  assert_contains "$contents" '`scripts/review-package --snapshot`'
  assert_contains "$contents" '`scripts/review-package TASK_TREE WORKTREE`'
  assert_contains "$contents" 'Never reuse a commit SHA or an earlier task snapshot as the baseline for a later uncommitted task.'
  assert_contains "$contents" 'Keep the same BASE and TASK_TREE throughout that task'
  assert_contains "$contents" '`Task N: in_progress (base <base>, tree <task-tree>)`'
  assert_contains "$contents" 'Capture the next task snapshot only after the previous task reaches `APPROVE`.'
  assert_not_contains "$contents" 'Before every implementer and repair-subagent dispatch'
  assert_contains "$contents" 'Use BASE..HEAD only when the candidate is fully committed; if any task change remains outside HEAD, use TASK_TREE..WORKTREE.'
  assert_contains "$contents" 'Verify that the review package exists and is readable before dispatch.'
  assert_contains "$contents" 'regenerate it from the same BASE or TASK_TREE baseline'
  assert_in_order "$contents" \
    'Final reviewer verdict?' \
    'Read objective authorization envelope' \
    'Return completion summary; keep change active' \
    'Invoke finishing-a-development-branch only for explicitly authorized effects'
  assert_contains "$contents" 'Implementation runs continuously by default.'
  assert_contains "$contents" 'Before returning a completion summary, confirm every completion gate:'
  assert_contains "$contents" '`git diff --check` succeeds'
  assert_contains "$contents" 'The controller dispatches an authorized repair subagent for every `REVISE` finding, requires targeted verification, and dispatches a fresh independent reviewer.'
  assert_contains "$contents" 'Dispatch an authorized repair subagent with every'
  assert_not_contains "$contents" 'Main controller repairs authorized findings'
  assert_not_contains "$contents" 'Dispatch a fix subagent'
done

for path in "${TDD_SKILLS[@]}"; do
  contents="$(<"$path")"
  assert_contains "$contents" 'Never use completion language or a final delivery format while any OpenSpec task remains unchecked.'
done

for path in "${IMPLEMENTER_PROMPTS[@]}"; do
  contents="$(<"$path")"
  assert_contains "$contents" 'first test failure'
  assert_contains "$contents" 'active authorization envelope'
  assert_contains "$contents" 'Only report `BLOCKED` or `NEEDS_CONTEXT`'
  assert_not_contains "$contents" '**Ask them now.**'
  assert_not_contains "$contents" "It's always OK to pause and clarify."
  assert_in_order "$contents" \
    '## Objective Authorization Envelope' \
    '**Objective:** [OBJECTIVE]' \
    '**Scope:** [SCOPE]' \
    '**Constraints:** [CONSTRAINTS]' \
    '**Authorized effects:** [AUTHORIZED_EFFECTS]' \
    '**Terminal condition:** [TERMINAL_CONDITION]'
  assert_contains "$contents" 'Create a commit only when authorized effects explicitly allow it and the current branch policy permits it.'
  assert_contains "$contents" 'Otherwise leave the working-tree changes uncommitted and explain that in the report.'
  assert_contains "$contents" 'Commits created: short SHA + subject, or `none` with the authorization or branch-policy reason'
  assert_not_contains "$contents" '4. Commit your work'
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

for path in "${TASK_REVIEWER_PROMPTS[@]}"; do
  contents="$(<"$path")"
  assert_contains "$contents" 'REVIEW_PACKAGE_UNAVAILABLE'
  assert_contains "$contents" 'Do not reconstruct a missing package with `git diff BASE..HEAD`'
  assert_contains "$contents" 'The controller must regenerate the package from the same task baseline and apply its bounded infrastructure retry policy.'
  assert_contains "$contents" 'The only non-verdict output is `REVIEW_PACKAGE_UNAVAILABLE` for this infrastructure failure.'
  assert_not_contains "$contents" 'If the diff file is missing, fetch the diff yourself'
done

for path in "${REQUESTING_REVIEW_SKILLS[@]}"; do
  contents="$(<"$path")"
  assert_contains "$contents" '`review-package BASE HEAD`'
  assert_contains "$contents" '`review-package BASE WORKTREE`'
  assert_contains "$contents" 'staged, unstaged, or untracked changes'
  assert_contains "$contents" 'Pass the printed path as `[DIFF_FILE]`'
  assert_contains "$contents" 'Do not dispatch a reviewer unless the package exists and is readable.'
  assert_not_contains "$contents" 'BASE_SHA=$(git rev-parse HEAD~1)'
done

branch_reviewer_contents="$(<"$CODEX_BRANCH_REVIEWER_PROMPT")"
assert_contains "$branch_reviewer_contents" '**Review package:** [DIFF_FILE]'
assert_contains "$branch_reviewer_contents" 'A supplied package is the authoritative change view and may represent either `BASE..HEAD` or `BASE..WORKTREE`.'
assert_contains "$branch_reviewer_contents" 'When a package is supplied, read it once instead of re-deriving the diff with Git.'
assert_contains "$branch_reviewer_contents" '- `[DIFF_FILE]` — commit-bounded or WORKTREE review package generated by the controller'
assert_contains "$branch_reviewer_contents" 'REVIEW_PACKAGE_UNAVAILABLE'
assert_contains "$branch_reviewer_contents" 'Do not reconstruct a missing WORKTREE package from BASE..HEAD.'
assert_not_contains "$branch_reviewer_contents" 'If no package is supplied, inspect the commit range directly'

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

outside_brief="$tmp_dir/outside-brief.md"
if (cd "$repo_dir" && "$TASK_BRIEF" tasks.md 1 "$outside_brief") >/dev/null 2>&1; then
  echo "expected task-brief to reject an OUTFILE outside the repo" >&2
  exit 1
fi

ln -s "$repo_dir/change.txt" "$repo_dir/brief-link.md"
if (cd "$repo_dir" && "$TASK_BRIEF" tasks.md 1 "$repo_dir/brief-link.md") >/dev/null 2>&1; then
  echo "expected task-brief to reject a symlink OUTFILE" >&2
  exit 1
fi
rm -f "$repo_dir/brief-link.md"

if compgen -G "$repo_dir/.task-brief.*" >/dev/null; then
  echo "task-brief left a temporary file in the repo" >&2
  exit 1
fi

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

mkdir -p "$repo_dir/nested"
task_one_base="$(cd "$repo_dir/nested" && "$REVIEW_PACKAGE" --snapshot)"
printf 'task one tracked\n' >> "$repo_dir/change.txt"
printf 'task one untracked\n' > "$repo_dir/task-one.txt"
task_one_output="$(cd "$repo_dir/nested" && "$REVIEW_PACKAGE" "$task_one_base" WORKTREE)"
task_one_path="${task_one_output#wrote }"
task_one_path="${task_one_path%%: *}"
assert_contains "$task_one_output" "worktree snapshot diff"
assert_file_exists "$task_one_path"
task_one_contents="$(<"$task_one_path")"
assert_contains "$task_one_contents" "task one tracked"
assert_contains "$task_one_contents" "task-one.txt"
assert_contains "$task_one_contents" "task one untracked"

task_two_base="$(cd "$repo_dir/nested" && "$REVIEW_PACKAGE" --snapshot)"
printf '\nTask two tracked\n' >> "$repo_dir/tasks.md"
printf 'task two untracked\n' > "$repo_dir/task-two.txt"
task_two_output="$(cd "$repo_dir/nested" && "$REVIEW_PACKAGE" "$task_two_base" WORKTREE)"
task_two_path="${task_two_output#wrote }"
task_two_path="${task_two_path%%: *}"
assert_file_exists "$task_two_path"
task_two_contents="$(<"$task_two_path")"
assert_contains "$task_two_contents" "Task two tracked"
assert_contains "$task_two_contents" "task-two.txt"
assert_contains "$task_two_contents" "task two untracked"
assert_not_contains "$task_two_contents" "task one tracked"
assert_not_contains "$task_two_contents" "task-one.txt"
assert_not_contains "$task_two_contents" "task one untracked"

custom_review_path="$repo_dir/review.diff"
custom_review_output="$(cd "$repo_dir/nested" && "$REVIEW_PACKAGE" "$task_two_base" WORKTREE "$custom_review_path")"
assert_contains "$custom_review_output" "wrote $custom_review_path"
assert_file_exists "$custom_review_path"
custom_review_contents="$(<"$custom_review_path")"
assert_not_contains "$custom_review_contents" "review.diff (untracked)"
assert_not_contains "$custom_review_contents" "diff --git a/review.diff b/review.diff"

existing_output_base="$(cd "$repo_dir/nested" && "$REVIEW_PACKAGE" --snapshot)"
existing_output="$(cd "$repo_dir/nested" && "$REVIEW_PACKAGE" "$existing_output_base" WORKTREE "$custom_review_path")"
assert_contains "$existing_output" "wrote $custom_review_path"
existing_output_contents="$(<"$custom_review_path")"
assert_not_contains "$existing_output_contents" "diff --git a/review.diff b/review.diff"

if ! git -C "$repo_dir" diff --cached --quiet; then
  echo "review snapshots must not modify the real index" >&2
  exit 1
fi

ln -s "$repo_dir/change.txt" "$repo_dir/review-link.diff"
if (cd "$repo_dir/nested" && "$REVIEW_PACKAGE" "$task_two_base" WORKTREE "$repo_dir/review-link.diff") >/dev/null 2>&1; then
  echo "expected review-package to reject a symlink OUTFILE" >&2
  exit 1
fi

outside_path="$tmp_dir/outside.diff"
if (cd "$repo_dir/nested" && "$REVIEW_PACKAGE" "$task_two_base" WORKTREE "$outside_path") >/dev/null 2>&1; then
  echo "expected review-package to reject an OUTFILE outside the repo/workspace" >&2
  exit 1
fi

mkdir -p "$tmp_dir/symlink-parent"
ln -s "$tmp_dir/symlink-parent" "$repo_dir/symlink-parent"
if (cd "$repo_dir/nested" && "$REVIEW_PACKAGE" "$task_two_base" WORKTREE "$repo_dir/symlink-parent/review.diff") >/dev/null 2>&1; then
  echo "expected review-package to reject an OUTFILE under a symlinked parent" >&2
  exit 1
fi

if compgen -G "$repo_dir/.review-package.*" >/dev/null; then
  echo "review-package left a temporary file in the repo" >&2
  exit 1
fi

symlink_repo="$tmp_dir/symlink-repo"
mkdir -p "$symlink_repo"
git -C "$symlink_repo" init -q
git -C "$symlink_repo" config user.email "test@example.com"
git -C "$symlink_repo" config user.name "Forgevia Test"
ln -s "$tmp_dir" "$symlink_repo/.superpowers"
if (cd "$symlink_repo" && "$SDD_WORKSPACE") >/dev/null 2>&1; then
  echo "expected sdd-workspace to reject a symlinked .superpowers" >&2
  exit 1
fi

nested_symlink_repo="$tmp_dir/nested-symlink-repo"
nested_symlink_target="$tmp_dir/nested-symlink-target"
mkdir -p "$nested_symlink_repo/.superpowers" "$nested_symlink_target"
git -C "$nested_symlink_repo" init -q
ln -s "$nested_symlink_target" "$nested_symlink_repo/.superpowers/sdd"
if (cd "$nested_symlink_repo" && "$SDD_WORKSPACE") >/dev/null 2>&1; then
  echo "expected sdd-workspace to reject a symlinked .superpowers/sdd directory" >&2
  exit 1
fi
if [[ -e "$nested_symlink_target/.gitignore" ]]; then
  echo "sdd-workspace must not write through a symlinked workspace directory" >&2
  exit 1
fi

linked_ignore_repo="$tmp_dir/linked-ignore-repo"
linked_ignore_target="$tmp_dir/linked-ignore-target"
mkdir -p "$linked_ignore_repo/.superpowers/sdd" "$linked_ignore_target"
git -C "$linked_ignore_repo" init -q
printf 'preserve me\n' > "$linked_ignore_target/.gitignore"
ln -s "$linked_ignore_target/.gitignore" "$linked_ignore_repo/.superpowers/sdd/.gitignore"
if (cd "$linked_ignore_repo" && "$SDD_WORKSPACE") >/dev/null 2>&1; then
  echo "expected sdd-workspace to reject a symlinked workspace .gitignore" >&2
  exit 1
fi
if [[ "$(cat "$linked_ignore_target/.gitignore")" != "preserve me" ]]; then
  echo "sdd-workspace must not write through a symlinked .gitignore" >&2
  exit 1
fi

echo "sdd workflow scripts test passed"

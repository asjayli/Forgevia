#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_SCRIPTS="$ROOT_DIR/assets/codex/superpowers/skills/subagent-driven-development/scripts"
CLAUDE_SCRIPTS="$ROOT_DIR/assets/claude/superpowers/skills/subagent-driven-development/scripts"
TASK_BRIEF="$CODEX_SCRIPTS/task-brief"
REVIEW_PACKAGE="$CODEX_SCRIPTS/review-package"
SDD_WORKSPACE="$CODEX_SCRIPTS/sdd-workspace"

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

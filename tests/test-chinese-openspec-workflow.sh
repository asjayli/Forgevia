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

assert_normalized_equal() {
  local codex_path="$1"
  local claude_path="$2"
  local codex_normalized
  local claude_normalized

  # Normalize both platform spellings to the same baseline on each side, so a
  # skill that legitimately references BOTH platform directories (e.g. a
  # read-only memory policy naming .codex/memory/ and .claude/memory/ together)
  # still compares equal after normalization.
  codex_normalized="$(sed -e 's/CODEX_HOME/CLIENT_HOME/g' -e 's/CLAUDE_HOME/CLIENT_HOME/g' -e 's/\.codex/.client/g' -e 's/\.claude/.client/g' "$codex_path")"
  claude_normalized="$(sed -e 's/CODEX_HOME/CLIENT_HOME/g' -e 's/CLAUDE_HOME/CLIENT_HOME/g' -e 's/\.codex/.client/g' -e 's/\.claude/.client/g' "$claude_path")"
  if [[ "$codex_normalized" != "$claude_normalized" ]]; then
    echo "expected normalized mirror files to match: $codex_path $claude_path" >&2
    exit 1
  fi
}

for path in \
  "$ROOT_DIR/assets/codex/skills/forgevia-propose/SKILL.md" \
  "$ROOT_DIR/assets/claude/skills/forgevia-propose/SKILL.md"
do
  assert_file_contains "$path" "必须、不得、禁止、应当"
  assert_file_contains "$path" "### Requirement:"
  assert_file_contains "$path" "forgevia\" validate"
done

for skill_name in forgevia-propose forgevia-review forgevia-archive; do
  assert_normalized_equal \
    "$ROOT_DIR/assets/codex/skills/$skill_name/SKILL.md" \
    "$ROOT_DIR/assets/claude/skills/$skill_name/SKILL.md"
done

for path in \
  "$ROOT_DIR/assets/codex/skills/forgevia-review/SKILL.md" \
  "$ROOT_DIR/assets/claude/skills/forgevia-review/SKILL.md" \
  "$ROOT_DIR/assets/codex/skills/forgevia-archive/SKILL.md" \
  "$ROOT_DIR/assets/claude/skills/forgevia-archive/SKILL.md"
do
  assert_file_contains "$path" "forgevia\" validate"
done

assert_file_contains "$ROOT_DIR/README.md" "forgevia validate"
assert_file_contains "$ROOT_DIR/README.md" "不支持中文章节或标题"
assert_file_contains "$ROOT_DIR/README_EN.md" "forgevia validate"
assert_file_contains "$ROOT_DIR/README_EN.md" "does not support Chinese section or heading keywords"

assert_file_contains "$ROOT_DIR/assets/codex/skills/openspec-archive-change/SKILL.md" "planningHome.changesDir"
assert_file_contains "$ROOT_DIR/assets/codex/skills/openspec-archive-change/SKILL.md" "artifactPaths.specs.existingOutputPaths"
assert_file_not_contains "$ROOT_DIR/assets/codex/skills/openspec-archive-change/SKILL.md" "mkdir -p openspec/changes/archive"
assert_file_contains "$ROOT_DIR/assets/codex/skills/openspec-explore/SKILL.md" "artifactPaths.<artifact>.existingOutputPaths"
assert_file_contains "$ROOT_DIR/assets/codex/skills/forgevia/SKILL.md" "changeRoot"
assert_file_contains "$ROOT_DIR/assets/claude/skills/forgevia/SKILL.md" "changeRoot"

for path in \
  "$ROOT_DIR/assets/claude/commands/opsx/sync.md" \
  "$ROOT_DIR/assets/claude/skills/openspec-sync-specs/SKILL.md" \
  "$ROOT_DIR/assets/codex/skills/openspec-sync-specs/SKILL.md"
do
  assert_file_contains "$path" "planningHome.root"
  assert_file_contains "$path" '<planningHome.root>/openspec/specs/<capability>/spec.md'
  assert_file_not_contains "$path" "For each repo-local capability"
done

for path in \
  "$ROOT_DIR/assets/claude/commands/opsx/archive.md" \
  "$ROOT_DIR/assets/claude/skills/openspec-archive-change/SKILL.md" \
  "$ROOT_DIR/assets/codex/skills/openspec-archive-change/SKILL.md"
do
  assert_file_contains "$path" '<planningHome.root>/openspec/specs/<capability>/spec.md'
  assert_file_not_contains "$path" 'at `openspec/specs/<capability>/spec.md`'
done

for root in "$ROOT_DIR/assets/codex/skills"; do
  while IFS= read -r path; do
    assert_file_not_contains "$path" "AskUserQuestion"
    assert_file_not_contains "$path" "TodoWrite"
    assert_file_not_contains "$path" "Task tool"
  done < <(find "$root" -mindepth 2 -maxdepth 2 -path '*/openspec-*/SKILL.md' -type f | sort)
done

echo "chinese OpenSpec workflow integration test passed"

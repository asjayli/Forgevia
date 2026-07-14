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

for path in \
  "$ROOT_DIR/assets/codex/skills/forgevia-propose/SKILL.md" \
  "$ROOT_DIR/.claude/skills/forgevia-propose/SKILL.md"
do
  assert_file_contains "$path" "必须、不得、禁止、应当"
  assert_file_contains "$path" "### Requirement:"
  assert_file_contains "$path" "validate-openspec-cn.mjs"
done

for path in \
  "$ROOT_DIR/assets/codex/skills/forgevia-review/SKILL.md" \
  "$ROOT_DIR/.claude/skills/forgevia-review/SKILL.md" \
  "$ROOT_DIR/assets/codex/skills/forgevia-archive/SKILL.md" \
  "$ROOT_DIR/.claude/skills/forgevia-archive/SKILL.md"
do
  assert_file_contains "$path" "validate-openspec-cn.mjs"
done

assert_file_contains "$ROOT_DIR/README.md" "validate-openspec-cn.mjs"
assert_file_contains "$ROOT_DIR/README.md" "不支持中文章节或标题"
assert_file_contains "$ROOT_DIR/README_EN.md" "validate-openspec-cn.mjs"
assert_file_contains "$ROOT_DIR/README_EN.md" "does not support Chinese section or heading keywords"

echo "chinese OpenSpec workflow integration test passed"

#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

for path in "$ROOT_DIR/README.md" "$ROOT_DIR/README_EN.md"; do
  if ! grep -Fq "openspec-sync-specs" "$path"; then
    echo "expected $path to document the standalone sync workflow" >&2
    exit 1
  fi
done

assert_contains() {
  local path="$1"
  local needle="$2"
  grep -Fq "$needle" "$path" || {
    echo "expected $path to contain: $needle" >&2
    exit 1
  }
}

assert_not_contains() {
  local path="$1"
  local needle="$2"
  if grep -Fq "$needle" "$path"; then
    echo "expected $path to not contain: $needle" >&2
    exit 1
  fi
}

assert_contains "$ROOT_DIR/README.md" '未指定子命令的交付请求默认执行完整交付'
assert_contains "$ROOT_DIR/README.md" '只读、探索、状态查询或评审意图不会被升级为代码实现'
assert_contains "$ROOT_DIR/README.md" '归档、同步规格、提交、推送、合并和发布仍需单独明确授权'
assert_contains "$ROOT_DIR/README.md" 'propose → implement → 必要的浏览器验证 → 最终独立评审'
assert_not_contains "$ROOT_DIR/README.md" '你只需要明确告诉 firefly 当前要执行哪个动作'
assert_not_contains "$ROOT_DIR/README.md" '未明确要求的后续阶段、归档、推送或发布不会自动执行'

assert_contains "$ROOT_DIR/README_EN.md" 'A delivery request without a subcommand runs the complete delivery workflow by default'
assert_contains "$ROOT_DIR/README_EN.md" 'Read-only, exploratory, status, and review intent is never upgraded to implementation'
assert_contains "$ROOT_DIR/README_EN.md" 'Archive, spec synchronization, commit, push, merge, and release still require separate explicit authorization'
assert_contains "$ROOT_DIR/README_EN.md" 'propose → implement → browser verification when relevant → final independent review'
assert_not_contains "$ROOT_DIR/README_EN.md" 'You tell firefly which action to run'
assert_not_contains "$ROOT_DIR/README_EN.md" 'It does not enter an unrequested later phase'

echo "readme workflow test passed"

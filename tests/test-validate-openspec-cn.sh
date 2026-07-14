#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="$ROOT_DIR/scripts/validate-openspec-cn.mjs"

assert_contains() {
  local haystack="$1"
  local needle="$2"

  if [[ "$haystack" != *"$needle"* ]]; then
    echo "expected output to contain: $needle" >&2
    exit 1
  fi
}

assert_exit_code() {
  local actual="$1"
  local expected="$2"

  if [[ "$actual" != "$expected" ]]; then
    echo "expected exit code $expected but got $actual" >&2
    exit 1
  fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

project_dir="$tmp_dir/project"
bin_dir="$tmp_dir/bin"
log_file="$tmp_dir/openspec.log"
mkdir -p "$project_dir/openspec/specs/main" \
  "$project_dir/openspec/changes/change/specs/capability" \
  "$bin_dir"

cat > "$project_dir/openspec/config.yaml" <<'EOF'
schema: spec-driven
EOF

cat > "$project_dir/openspec/changes/change/proposal.md" <<'EOF'
## Why

验证中文严格校验适配器。

## What Changes

- 新增中文强制词校验。
EOF

cat > "$project_dir/openspec/specs/main/spec.md" <<'EOF'
## Purpose

这是一段足够长的主规格目的说明，用于避免严格校验将目的描述过短视为警告。

## Requirements

### Requirement: 中文主规格
系统必须保留中文正文，同时仍满足 OpenSpec 的严格校验。

#### Scenario: 处理中文强制词
- **WHEN** 需求正文使用必须
- **THEN** 校验通过
EOF

cat > "$project_dir/openspec/changes/change/specs/capability/spec.md" <<'EOF'
## ADDED Requirements

### Requirement: 中文变更需求
系统不得修改源规格文件。

#### Scenario: 处理中文变更需求
- **WHEN** 变更需求使用不得
- **THEN** 校验通过

## MODIFIED Requirements

### Requirement: 中文修改需求
系统应当保留现有需求结构。

#### Scenario: 处理中文修改需求
- **WHEN** 修改需求使用应当
- **THEN** 校验通过
EOF

cat > "$bin_dir/openspec" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "\$*" >> "$log_file"
grep -q '^MUST 系统必须保留中文正文' openspec/specs/main/spec.md
grep -q '^MUST 系统不得修改源规格文件' openspec/changes/change/specs/capability/spec.md
grep -q '^MUST 系统应当保留现有需求结构' openspec/changes/change/specs/capability/spec.md
if [[ "\${FAKE_OPENSPEC_FAIL_ON:-}" == "\$1 \$2" ]]; then
  exit 9
fi
EOF
chmod +x "$bin_dir/openspec"
mkdir -p "$tmp_dir/staging"

set +e
output="$(TMPDIR="$tmp_dir/staging" PATH="$bin_dir:$PATH" node "$VALIDATOR" --root "$project_dir" 2>&1)"
status=$?
set -e

assert_exit_code "$status" "0"
assert_contains "$(cat "$log_file")" "validate --specs --strict --no-interactive"
assert_contains "$(cat "$log_file")" "validate --changes --strict --no-interactive"
if grep -q '^MUST ' "$project_dir/openspec/specs/main/spec.md"; then
  echo "validator modified the source main spec" >&2
  exit 1
fi
if grep -q '^MUST ' "$project_dir/openspec/changes/change/specs/capability/spec.md"; then
  echo "validator modified the source change spec" >&2
  exit 1
fi
if compgen -G "$tmp_dir/staging/forgevia-openspec-cn-*" >/dev/null; then
  echo "validator left a staging directory after success" >&2
  exit 1
fi

archived_change_project="$tmp_dir/archived-change"
cp -R "$project_dir" "$archived_change_project"
mkdir -p "$archived_change_project/openspec/changes/archive/old-change/specs/legacy"
cat > "$archived_change_project/openspec/changes/archive/old-change/proposal.md" <<'EOF'
## Why

历史变更。

## What Changes

- 历史行为。
EOF
cat > "$archived_change_project/openspec/changes/archive/old-change/specs/legacy/spec.md" <<'EOF'
## ADDED Requirements

### Requirement: 历史需求
系统提供历史功能。

#### Scenario: 历史场景
- **WHEN** 调用历史功能
- **THEN** 返回历史结果
EOF

set +e
archived_change_output="$(TMPDIR="$tmp_dir/staging" PATH="$bin_dir:$PATH" node "$VALIDATOR" --root "$archived_change_project" 2>&1)"
archived_change_status=$?
set -e

assert_exit_code "$archived_change_status" "0"

quoted_schema_project="$tmp_dir/quoted-schema"
cp -R "$project_dir" "$quoted_schema_project"
printf 'schema: "spec-driven" # supported YAML scalar\n' > "$quoted_schema_project/openspec/config.yaml"

set +e
quoted_schema_output="$(TMPDIR="$tmp_dir/staging" PATH="$bin_dir:$PATH" node "$VALIDATOR" --root "$quoted_schema_project" 2>&1)"
quoted_schema_status=$?
set -e

assert_exit_code "$quoted_schema_status" "0"

block_schema_project="$tmp_dir/block-schema"
cp -R "$project_dir" "$block_schema_project"
cat > "$block_schema_project/openspec/config.yaml" <<'EOF'
schema: >-
  spec-driven
EOF

set +e
block_schema_output="$(TMPDIR="$tmp_dir/staging" PATH="$bin_dir:$PATH" node "$VALIDATOR" --root "$block_schema_project" 2>&1)"
block_schema_status=$?
set -e

assert_exit_code "$block_schema_status" "0"

tagged_schema_project="$tmp_dir/tagged-schema"
cp -R "$project_dir" "$tagged_schema_project"
printf 'schema: !!str spec-driven\n' > "$tagged_schema_project/openspec/config.yaml"

set +e
tagged_schema_output="$(TMPDIR="$tmp_dir/staging" PATH="$bin_dir:$PATH" node "$VALIDATOR" --root "$tagged_schema_project" 2>&1)"
tagged_schema_status=$?
set -e

assert_exit_code "$tagged_schema_status" "0"

missing_modal_project="$tmp_dir/missing-modal"
cp -R "$project_dir" "$missing_modal_project"
sed -i 's/系统必须保留中文正文/系统提供中文正文/' "$missing_modal_project/openspec/specs/main/spec.md"

set +e
missing_modal_output="$(TMPDIR="$tmp_dir/staging" PATH="$bin_dir:$PATH" node "$VALIDATOR" --root "$missing_modal_project" 2>&1)"
missing_modal_status=$?
set -e

assert_exit_code "$missing_modal_status" "1"
assert_contains "$missing_modal_output" "缺少强制词"

chinese_header_project="$tmp_dir/chinese-header"
cp -R "$project_dir" "$chinese_header_project"
sed -i 's/^### Requirement:/### 需求:/' "$chinese_header_project/openspec/specs/main/spec.md"

set +e
chinese_header_output="$(TMPDIR="$tmp_dir/staging" PATH="$bin_dir:$PATH" node "$VALIDATOR" --root "$chinese_header_project" 2>&1)"
chinese_header_status=$?
set -e

assert_exit_code "$chinese_header_status" "1"
assert_contains "$chinese_header_output" "不支持中文结构标题"

unsupported_schema_project="$tmp_dir/unsupported-schema"
cp -R "$project_dir" "$unsupported_schema_project"
sed -i 's/spec-driven/custom-schema/' "$unsupported_schema_project/openspec/config.yaml"

set +e
unsupported_schema_output="$(TMPDIR="$tmp_dir/staging" PATH="$bin_dir:$PATH" node "$VALIDATOR" --root "$unsupported_schema_project" 2>&1)"
unsupported_schema_status=$?
set -e

assert_exit_code "$unsupported_schema_status" "1"
assert_contains "$unsupported_schema_output" "仅支持 spec-driven schema"

set +e
native_failure_output="$(TMPDIR="$tmp_dir/staging" FAKE_OPENSPEC_FAIL_ON='validate --changes' PATH="$bin_dir:$PATH" node "$VALIDATOR" --root "$project_dir" 2>&1)"
native_failure_status=$?
set -e

assert_exit_code "$native_failure_status" "9"
assert_contains "$(cat "$log_file")" "validate --changes --strict --no-interactive"
if compgen -G "$tmp_dir/staging/forgevia-openspec-cn-*" >/dev/null; then
  echo "validator left a staging directory after native failure" >&2
  exit 1
fi

echo "chinese OpenSpec validator test passed"

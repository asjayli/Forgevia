#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BOOTSTRAP="$ROOT_DIR/scripts/bootstrap-project.sh"

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "expected output to contain: $needle" >&2
    exit 1
  fi
}

assert_file_exists() {
  local path="$1"
  if [[ ! -e "$path" ]]; then
    echo "expected path to exist: $path" >&2
    exit 1
  fi
}

# Run bootstrap under the fake openspec PATH and assert it fails with the
# expected reason. Asserting stderr prevents a wrong-cause failure from passing.
run_fail() {
  local desc="$1"
  local expect="$2"
  shift 2
  local out
  if out="$(PATH="$bin_dir:$PATH" "$@" 2>&1)"; then
    echo "expected failure but succeeded: $desc" >&2
    exit 1
  fi
  if [[ -n "$expect" && "$out" != *"$expect"* ]]; then
    echo "$desc: expected stderr to contain [$expect]; got: $out" >&2
    exit 1
  fi
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

project_dir="$tmp_dir/project"
bin_dir="$tmp_dir/bin"
mkdir -p "$project_dir" "$bin_dir"

fake_log="$tmp_dir/openspec.log"
cat > "$bin_dir/openspec" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "\$*" >> "$fake_log"
target_dir="\${@: -1}"
mkdir -p "\$target_dir/openspec" "\$target_dir/.codex"
printf 'schema: spec-driven\n' > "\$target_dir/openspec/config.yaml"
EOF
chmod +x "$bin_dir/openspec"

help_output="$("$BOOTSTRAP" --help)"
assert_contains "$help_output" "Bootstrap OpenSpec in the current project"

default_output="$(PATH="$bin_dir:$PATH" "$BOOTSTRAP" "$project_dir")"
assert_contains "$default_output" "Running openspec init --tools codex,claude"
assert_file_exists "$project_dir/openspec"
assert_file_exists "$fake_log"
assert_contains "$(cat "$fake_log")" "init --tools codex,claude $project_dir"

line_count="$(wc -l < "$fake_log" | tr -d ' ')"
if [[ "$line_count" != "1" ]]; then
  echo "expected default openspec init to run exactly once" >&2
  exit 1
fi

second_output="$(PATH="$bin_dir:$PATH" "$BOOTSTRAP" --tools codex,claude "$project_dir")"
assert_contains "$second_output" "OpenSpec already initialized"

incomplete_project_dir="$tmp_dir/project-incomplete"
mkdir -p "$incomplete_project_dir/openspec"

incomplete_output="$(PATH="$bin_dir:$PATH" "$BOOTSTRAP" "$incomplete_project_dir")"
assert_contains "$incomplete_output" "Running openspec init --tools codex,claude"
assert_contains "$(cat "$fake_log")" "init --tools codex,claude $incomplete_project_dir"

second_project="$tmp_dir/project-explicit"
mkdir -p "$second_project"

bootstrap_output="$(PATH="$bin_dir:$PATH" "$BOOTSTRAP" --tools codex,claude "$second_project")"
assert_contains "$bootstrap_output" "Running openspec init --tools codex,claude"
assert_contains "$(cat "$fake_log")" "init --tools codex,claude $second_project"

second_project_dir="$tmp_dir/project-claude"
mkdir -p "$second_project_dir"

claude_output="$(PATH="$bin_dir:$PATH" "$BOOTSTRAP" --tools claude "$second_project_dir")"
assert_contains "$claude_output" "Running openspec init --tools claude"
assert_contains "$(cat "$fake_log")" "init --tools claude $second_project_dir"

third_project_dir="$tmp_dir/project-normalized"
mkdir -p "$third_project_dir"

normalized_output="$(PATH="$bin_dir:$PATH" "$BOOTSTRAP" --tools claude,codex "$third_project_dir")"
assert_contains "$normalized_output" "Running openspec init --tools codex,claude"
assert_contains "$(cat "$fake_log")" "init --tools codex,claude $third_project_dir"

# Robustness: a symbolic link anywhere in the project_dir path is refused.
real_parent="$tmp_dir/real-parent"
link_parent="$tmp_dir/link-parent"
mkdir -p "$real_parent"
ln -s "$real_parent" "$link_parent"
symlink_project="$link_parent/project"
mkdir -p "$symlink_project"
run_fail "symlinked project path component" "refusing symlinked project path component" "$BOOTSTRAP" "$symlink_project"

# Robustness: an explicitly empty project_dir is refused.
run_fail "empty project_dir" "project_dir must not be empty" "$BOOTSTRAP" ""

# Robustness: a newline embedded in project_dir is refused.
run_fail "newline in project_dir" "must not contain newline" "$BOOTSTRAP" $'proj\nname'

# Robustness: a symlinked openspec output is refused before initialization.
symlink_openspec_project="$tmp_dir/project-openspec-symlink"
mkdir -p "$symlink_openspec_project"
ln -s "$tmp_dir" "$symlink_openspec_project/openspec"
run_fail "symlinked openspec output" "refusing symlinked initializer output" "$BOOTSTRAP" "$symlink_openspec_project"

# Robustness: a symlinked openspec internal entry is refused before init scans it.
symlink_inside_project="$tmp_dir/project-openspec-inside"
mkdir -p "$symlink_inside_project/openspec"
ln -s "$tmp_dir" "$symlink_inside_project/openspec/changes"
run_fail "symlinked openspec internal entry" "refusing symlinked initializer output" "$BOOTSTRAP" "$symlink_inside_project"

# Robustness: a symlinked platform output root is refused before initialization.
symlink_root_project="$tmp_dir/project-root-symlink"
mkdir -p "$symlink_root_project"
ln -s "$tmp_dir" "$symlink_root_project/.codex"
run_fail "symlinked platform output root" "refusing symlinked initializer output" "$BOOTSTRAP" "$symlink_root_project"

# Robustness: an unknown option is refused.
run_fail "unknown option" "unsupported option" "$BOOTSTRAP" "--bogus" "$tmp_dir/project-bogus"

# Robustness: more than one project_dir is refused.
multi_a="$tmp_dir/project-multi-a"
multi_b="$tmp_dir/project-multi-b"
mkdir -p "$multi_a" "$multi_b"
run_fail "multiple project_dir" "only one project_dir" "$BOOTSTRAP" "$multi_a" "$multi_b"

echo "bootstrap project test passed"

#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

runtime_dir="$tmp_dir/runtime"
mkdir -p "$runtime_dir"
cp "$ROOT_DIR/scripts/firefly.sh" "$runtime_dir/firefly"

cat > "$runtime_dir/validate-openspec-cn.mjs" <<'EOF'
console.log(`validate ${process.argv.slice(2).join(' ')}`);
EOF

for command in bootstrap-project.sh list-change-tasks.sh firefly-draw.sh doctor-codex.sh; do
  cat > "$runtime_dir/$command" <<EOF
#!/usr/bin/env bash
echo "${command%.sh} \$*"
EOF
  chmod +x "$runtime_dir/$command"
done

validate_output="$("$runtime_dir/firefly" validate --root project)"
assert_contains "$validate_output" "validate --root project"

init_output="$("$runtime_dir/firefly" init --tools codex project)"
assert_contains "$init_output" "bootstrap-project --tools codex project"

tasks_output="$("$runtime_dir/firefly" tasks project)"
assert_contains "$tasks_output" "list-change-tasks project"

draw_output="$("$runtime_dir/firefly" draw feature-name)"
assert_contains "$draw_output" "firefly-draw feature-name"

doctor_output="$("$runtime_dir/firefly" doctor)"
assert_contains "$doctor_output" "doctor-codex"

repair_output="$("$runtime_dir/firefly" repair)"
assert_contains "$repair_output" "doctor-codex --repair"

set +e
unsupported_output="$("$runtime_dir/firefly" archive 2>&1)"
unsupported_status=$?
set -e

assert_exit_code "$unsupported_status" "1"
assert_contains "$unsupported_output" "Usage: firefly <command>"

echo "firefly command test passed"

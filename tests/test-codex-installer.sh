#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT_DIR/scripts/install-codex.sh"
DOCTOR="$ROOT_DIR/scripts/doctor-codex.sh"
MANIFEST="$ROOT_DIR/manifests/codex.json"

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    echo "expected output to contain: $needle" >&2
    exit 1
  fi
}

test_file_exists() {
  local path="$1"
  if [[ ! -f "$path" ]]; then
    echo "expected file to exist: $path" >&2
    exit 1
  fi
}

test_file_executable() {
  local path="$1"
  if [[ ! -x "$path" ]]; then
    echo "expected file to be executable: $path" >&2
    exit 1
  fi
}

test_path_not_exists() {
  local path="$1"
  if [[ -e "$path" ]]; then
    echo "expected path to not exist: $path" >&2
    exit 1
  fi
}

test_symbolic_link() {
  local path="$1"
  if [[ ! -L "$path" ]]; then
    echo "expected symbolic link to exist: $path" >&2
    exit 1
  fi
}

assert_link_target() {
  local path="$1"
  local expected="$2"
  local actual

  actual="$(readlink "$path")"
  if [[ "$actual" != "$expected" ]]; then
    echo "expected symbolic link target $expected but got $actual" >&2
    exit 1
  fi
}

assert_paths_equal() {
  local expected="$1"
  local actual="$2"

  if ! diff -qr "$expected" "$actual" >/dev/null; then
    echo "expected installed source mirror to match: $expected $actual" >&2
    diff -qr "$expected" "$actual" >&2 || true
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

test_file_exists "$MANIFEST"
test_file_exists "$INSTALLER"
test_file_exists "$DOCTOR"

manifest_skill_sources="$(node -e 'const m=require(process.argv[1]); console.log(m.managedAssets.filter(a => a.kind === "skill-directory" && a.source.startsWith("assets/codex/skills/")).map(a => a.source).sort().join("\n"))' "$MANIFEST")"
scanned_skill_sources="$(find "$ROOT_DIR/assets/codex/skills" -mindepth 1 -maxdepth 1 -type d -printf 'assets/codex/skills/%f\n' | sort)"
if [[ "$manifest_skill_sources" != "$scanned_skill_sources" ]]; then
  echo "Codex manifest skill assets do not match assets/codex/skills" >&2
  exit 1
fi

assert_contains "$(<"$MANIFEST")" '"version": "1.6.0"'
assert_contains "$(<"$MANIFEST")" '"overrideTargetVersion": "1.6.0"'
assert_contains "$(<"$MANIFEST")" '"source": "repo root (assets, scripts, manifests)"'
assert_contains "$(<"$INSTALLER")" 'npm install -g @fission-ai/openspec@1.6.0'

installer_help="$("$INSTALLER" --help)"
doctor_help="$("$DOCTOR" --help)"

assert_contains "$installer_help" "Install firefly Codex assets"
assert_contains "$installer_help" "$MANIFEST"
assert_contains "$doctor_help" "Check firefly Codex managed assets"
assert_contains "$doctor_help" "$MANIFEST"
assert_contains "$doctor_help" "--repair"
assert_contains "$doctor_help" "firefly runtime command dispatcher"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

export CODEX_HOME="$tmp_dir/.codex"
export FIREFLY_BIN_DIR="$tmp_dir/.local/bin"
export OPENSPEC_ROOT="$tmp_dir/openspec"
bin_dir="$tmp_dir/bin"
npm_log="$tmp_dir/npm.log"
export FAKE_NPM_ROOT="$tmp_dir/npm-global"
export FAKE_NPM_LOG="$npm_log"
mkdir -p "$bin_dir"
cat > "$bin_dir/npm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  install)
    printf '%s\n' "$*" >> "$FAKE_NPM_LOG"
    ;;
  root)
    printf '%s\n' "$FAKE_NPM_ROOT"
    ;;
  *)
    exit 1
    ;;
esac
EOF
chmod +x "$bin_dir/npm"
export PATH="$bin_dir:$PATH"

set +e
deprecated_flag_output="$("$INSTALLER" --install-openspec 2>&1)"
deprecated_flag_status=$?
set -e
assert_exit_code "$deprecated_flag_status" "1"
assert_contains "$deprecated_flag_output" "unknown argument: --install-openspec"

mkdir -p "$CODEX_HOME/superpowers/skills/brainstorming"
mkdir -p "$CODEX_HOME/superpowers/skills/writing-plans"
mkdir -p "$CODEX_HOME/superpowers/skills/executing-plans"
mkdir -p "$CODEX_HOME/superpowers/skills/subagent-driven-development"
mkdir -p "$CODEX_HOME/superpowers/skills/requesting-code-review"
mkdir -p "$CODEX_HOME/superpowers/skills/test-driven-development"
mkdir -p "$OPENSPEC_ROOT/dist/core"
mkdir -p "$OPENSPEC_ROOT/dist/core/templates/workflows"
printf '{"name":"@fission-ai/openspec","version":"1.6.0"}\n' > "$OPENSPEC_ROOT/package.json"
printf 'user local brainstorming\n' > "$CODEX_HOME/superpowers/skills/brainstorming/SKILL.md"
printf 'user local tdd\n' > "$CODEX_HOME/superpowers/skills/test-driven-development/SKILL.md"
printf 'export function serializeConfig() { return \"wrong\"; }\n' > "$OPENSPEC_ROOT/dist/core/config-prompts.js"
printf 'export const propose = \"wrong\";\n' > "$OPENSPEC_ROOT/dist/core/templates/workflows/propose.js"

mkdir -p "$FIREFLY_BIN_DIR"
printf '#!/usr/bin/env bash\n# firefly global command shim\necho user-command\n' > "$FIREFLY_BIN_DIR/firefly"
chmod +x "$FIREFLY_BIN_DIR/firefly"

set +e
command_collision_output="$("$INSTALLER" 2>&1)"
command_collision_status=$?
set -e
assert_exit_code "$command_collision_status" "1"
assert_contains "$command_collision_output" "refusing to replace existing command: $FIREFLY_BIN_DIR/firefly"
rm "$FIREFLY_BIN_DIR/firefly"

installer_output="$("$INSTALLER")"
assert_contains "$installer_output" "🧱 firefly Codex installer"
assert_contains "$installer_output" "✅ Applied openspec override"
assert_contains "$installer_output" "✅ Applied firefly-managed Codex assets"
assert_contains "$installer_output" "💾 Backed up"
assert_contains "$installer_output" "🎉 firefly Codex install complete"
assert_contains "$(cat "$npm_log")" "install -g @fission-ai/openspec@1.6.0"

for mirror_path in assets scripts manifests; do
  assert_paths_equal "$ROOT_DIR/$mirror_path" "$CODEX_HOME/firefly/$mirror_path"
done

test_path_not_exists "$CODEX_HOME/superpowers/skills/brainstorming/SKILL.md.firefly.bak"
test_path_not_exists "$CODEX_HOME/superpowers/skills/test-driven-development/SKILL.md.firefly.bak"
test_path_not_exists "$OPENSPEC_ROOT/dist/core/config-prompts.js.firefly.bak"
test_path_not_exists "$OPENSPEC_ROOT/dist/core/templates/workflows/propose.js.firefly.bak"
test_file_exists "$CODEX_HOME/skills/mermaid-diagram-specialist/SKILL.md"
test_file_exists "$CODEX_HOME/skills/firefly/SKILL.md"
test_file_exists "$CODEX_HOME/skills/firefly-init/SKILL.md"
test_file_exists "$CODEX_HOME/skills/firefly-doctor/SKILL.md"
test_file_exists "$CODEX_HOME/skills/firefly-repair/SKILL.md"
test_file_exists "$CODEX_HOME/skills/firefly-implement/SKILL.md"
test_file_exists "$CODEX_HOME/skills/firefly-archive/SKILL.md"
test_file_exists "$CODEX_HOME/skills/firefly-tasks/SKILL.md"
test_file_exists "$CODEX_HOME/skills/firefly-think/SKILL.md"
test_file_exists "$CODEX_HOME/skills/firefly-propose/SKILL.md"
test_file_exists "$CODEX_HOME/skills/firefly-review/SKILL.md"
test_file_exists "$CODEX_HOME/skills/firefly-verify-web/SKILL.md"
test_file_exists "$CODEX_HOME/skills/firefly-draw/SKILL.md"
test_file_exists "$CODEX_HOME/skills/openspec-propose/SKILL.md"
test_file_exists "$CODEX_HOME/skills/openspec-apply-change/SKILL.md"
test_file_exists "$CODEX_HOME/skills/openspec-archive-change/SKILL.md"
test_file_exists "$CODEX_HOME/skills/openspec-explore/SKILL.md"
test_file_exists "$CODEX_HOME/skills/openspec-sync-specs/SKILL.md"

for skill_name in openspec-propose openspec-apply-change openspec-archive-change openspec-explore openspec-sync-specs; do
  cmp "$ROOT_DIR/assets/codex/skills/$skill_name/SKILL.md" "$CODEX_HOME/skills/$skill_name/SKILL.md"
  assert_contains "$(<"$CODEX_HOME/skills/$skill_name/SKILL.md")" 'generatedBy: "1.6.0"'
done

assert_contains "$(<"$MANIFEST")" '"id": "openspec-sync-specs-skill"'

# Superpowers overrides: whole-directory overlays (subagent-driven-development,
# requesting-code-review) must land their extra files alongside SKILL.md, and
# the SDD runtime scripts must keep their exec bit through the cp -R overlay.
codex_sp_root="$CODEX_HOME/superpowers/skills"
test_file_exists "$codex_sp_root/brainstorming/SKILL.md"
test_file_exists "$codex_sp_root/writing-plans/SKILL.md"
test_file_exists "$codex_sp_root/executing-plans/SKILL.md"
test_file_exists "$codex_sp_root/test-driven-development/SKILL.md"
test_file_exists "$codex_sp_root/subagent-driven-development/SKILL.md"
test_file_exists "$codex_sp_root/subagent-driven-development/implementer-prompt.md"
test_file_executable "$codex_sp_root/subagent-driven-development/scripts/task-brief"
test_file_executable "$codex_sp_root/subagent-driven-development/scripts/review-package"
test_file_executable "$codex_sp_root/subagent-driven-development/scripts/sdd-workspace"
test_file_exists "$codex_sp_root/requesting-code-review/SKILL.md"
test_file_exists "$codex_sp_root/requesting-code-review/code-reviewer.md"

# Runtime scripts are installed to ~/.codex/firefly/bin and must stay executable.
test_file_executable "$CODEX_HOME/firefly/bin/bootstrap-project.sh"
test_file_executable "$CODEX_HOME/firefly/bin/list-change-tasks.sh"
test_file_executable "$CODEX_HOME/firefly/bin/firefly-draw.sh"
test_file_executable "$CODEX_HOME/firefly/bin/doctor-codex.sh"
test_file_executable "$CODEX_HOME/firefly/bin/validate-openspec-cn.mjs"
cmp "$ROOT_DIR/scripts/validate-openspec-cn.mjs" "$CODEX_HOME/firefly/bin/validate-openspec-cn.mjs"
test_file_executable "$CODEX_HOME/firefly/bin/firefly"
cmp "$ROOT_DIR/scripts/firefly.sh" "$CODEX_HOME/firefly/bin/firefly"
test_file_executable "$FIREFLY_BIN_DIR/firefly"
cmp "$ROOT_DIR/scripts/firefly-global.sh" "$FIREFLY_BIN_DIR/firefly"
global_command_output="$(CLAUDE_HOME="$tmp_dir/.claude" "$FIREFLY_BIN_DIR/firefly" doctor)"
assert_contains "$global_command_output" "firefly Codex doctor passed"

doctor_output="$("$DOCTOR")"
assert_contains "$doctor_output" "🔎 firefly Codex doctor"
assert_contains "$doctor_output" "✅ OK"
assert_contains "$doctor_output" "📋 Summary"
assert_contains "$doctor_output" "firefly Codex doctor passed"
assert_contains "$doctor_output" "$OPENSPEC_ROOT/dist/core/config-prompts.js"
assert_contains "$doctor_output" "$OPENSPEC_ROOT/dist/core/templates/workflows/propose.js"
assert_contains "$doctor_output" "$CODEX_HOME/skills/openspec-propose"
assert_contains "$doctor_output" "$CODEX_HOME/skills/openspec-apply-change"
assert_contains "$doctor_output" "$CODEX_HOME/skills/openspec-sync-specs"

rm "$FIREFLY_BIN_DIR/firefly"

set +e
global_command_drift_output="$("$DOCTOR" 2>&1)"
global_command_drift_status=$?
set -e
assert_exit_code "$global_command_drift_status" "1"
assert_contains "$global_command_drift_output" "$FIREFLY_BIN_DIR/firefly"

global_command_repair_output="$("$DOCTOR" --repair)"
assert_contains "$global_command_repair_output" "$FIREFLY_BIN_DIR/firefly"
test_file_executable "$FIREFLY_BIN_DIR/firefly"
cmp "$ROOT_DIR/scripts/firefly-global.sh" "$FIREFLY_BIN_DIR/firefly"

rm "$FIREFLY_BIN_DIR/firefly"
rm "$FIREFLY_BIN_DIR/.firefly-global-command.sha256"
ln -s "$CODEX_HOME/firefly/bin/firefly" "$FIREFLY_BIN_DIR/firefly"

legacy_command_repair_output="$("$DOCTOR" --repair)"
assert_contains "$legacy_command_repair_output" "$FIREFLY_BIN_DIR/firefly"
test_file_executable "$FIREFLY_BIN_DIR/firefly"
test_path_not_exists "$FIREFLY_BIN_DIR/firefly.firefly.bak"
cmp "$ROOT_DIR/scripts/firefly-global.sh" "$FIREFLY_BIN_DIR/firefly"

expected_openspec_config="$(cat "$ROOT_DIR/assets/openspec/dist/core/config-prompts.js")"
actual_openspec_config="$(cat "$OPENSPEC_ROOT/dist/core/config-prompts.js")"
assert_contains "$actual_openspec_config" "$expected_openspec_config"
assert_contains "$expected_openspec_config" "# Project context (optional)"
assert_contains "$expected_openspec_config" "# Per-artifact rules (optional)"
assert_contains "$expected_openspec_config" "所有产出物必须用简体中文撰写。"
expected_openspec_propose="$(cat "$ROOT_DIR/assets/openspec/dist/core/templates/workflows/propose.js")"
actual_openspec_propose="$(cat "$OPENSPEC_ROOT/dist/core/templates/workflows/propose.js")"
assert_contains "$actual_openspec_propose" "$expected_openspec_propose"
expected_openspec_propose_skill="$(cat "$ROOT_DIR/assets/codex/skills/openspec-propose/SKILL.md")"
actual_openspec_propose_skill="$(cat "$CODEX_HOME/skills/openspec-propose/SKILL.md")"
assert_contains "$actual_openspec_propose_skill" "$expected_openspec_propose_skill"
assert_contains "$actual_openspec_propose_skill" 'Next command: `firefly implement <name>`'
assert_contains "$actual_openspec_propose" 'Next command: \`firefly implement <name>\`'

echo "drift" >> "$CODEX_HOME/superpowers/skills/brainstorming/SKILL.md"

set +e
drift_output="$("$DOCTOR" 2>&1)"
drift_status=$?
set -e

assert_exit_code "$drift_status" "1"
assert_contains "$drift_output" "❌ DRIFT"
assert_contains "$drift_output" "📋 Summary"

repair_output="$("$DOCTOR" --repair)"
assert_contains "$repair_output" "🛠️ Repairing drifted or missing assets"
assert_contains "$repair_output" "💾 Backed up"
assert_contains "$repair_output" "✅ Repaired"
test_path_not_exists "$CODEX_HOME/superpowers/skills/brainstorming/SKILL.md.firefly.bak"

post_repair_output="$("$DOCTOR")"
assert_contains "$post_repair_output" "✨ No drift detected"
assert_contains "$post_repair_output" "firefly Codex doctor passed"

chmod -x "$CODEX_HOME/firefly/bin/firefly-draw.sh"

set +e
mode_drift_output="$("$DOCTOR" 2>&1)"
mode_drift_status=$?
set -e

assert_exit_code "$mode_drift_status" "1"
assert_contains "$mode_drift_output" "❌ DRIFT"
assert_contains "$mode_drift_output" "$CODEX_HOME/firefly/bin/firefly-draw.sh"

mode_repair_output="$("$DOCTOR" --repair)"
assert_contains "$mode_repair_output" "$CODEX_HOME/firefly/bin/firefly-draw.sh"
test_file_executable "$CODEX_HOME/firefly/bin/firefly-draw.sh"

rm "$CODEX_HOME/firefly/bin/validate-openspec-cn.mjs"

set +e
validator_drift_output="$("$DOCTOR" 2>&1)"
validator_drift_status=$?
set -e

assert_exit_code "$validator_drift_status" "1"
assert_contains "$validator_drift_output" "validate-openspec-cn.mjs"

validator_repair_output="$("$DOCTOR" --repair)"
assert_contains "$validator_repair_output" "validate-openspec-cn.mjs"
test_file_executable "$CODEX_HOME/firefly/bin/validate-openspec-cn.mjs"
cmp "$ROOT_DIR/scripts/validate-openspec-cn.mjs" "$CODEX_HOME/firefly/bin/validate-openspec-cn.mjs"

rm "$CODEX_HOME/firefly/bin/firefly"

set +e
command_drift_output="$($DOCTOR 2>&1)"
command_drift_status=$?
set -e

assert_exit_code "$command_drift_status" "1"
assert_contains "$command_drift_output" "$CODEX_HOME/firefly/bin/firefly"

command_repair_output="$($DOCTOR --repair)"
assert_contains "$command_repair_output" "$CODEX_HOME/firefly/bin/firefly"
test_file_executable "$CODEX_HOME/firefly/bin/firefly"
cmp "$ROOT_DIR/scripts/firefly.sh" "$CODEX_HOME/firefly/bin/firefly"

rm "$CODEX_HOME/firefly/bin/doctor-codex.sh"

set +e
doctor_script_drift_output="$($DOCTOR 2>&1)"
doctor_script_drift_status=$?
set -e

assert_exit_code "$doctor_script_drift_status" "1"
assert_contains "$doctor_script_drift_output" "$CODEX_HOME/firefly/bin/doctor-codex.sh"

doctor_script_repair_output="$($DOCTOR --repair)"
assert_contains "$doctor_script_repair_output" "$CODEX_HOME/firefly/bin/doctor-codex.sh"
test_file_executable "$CODEX_HOME/firefly/bin/doctor-codex.sh"
cmp "$ROOT_DIR/scripts/doctor-codex.sh" "$CODEX_HOME/firefly/bin/doctor-codex.sh"

missing_openspec_root="$tmp_dir/missing-openspec"
rm -rf "$missing_openspec_root"

set +e
missing_openspec_repair_output="$(OPENSPEC_ROOT="$missing_openspec_root" "$DOCTOR" --repair 2>&1)"
missing_openspec_repair_status=$?
set -e

assert_exit_code "$missing_openspec_repair_status" "1"
assert_contains "$missing_openspec_repair_output" "OpenSpec package is missing or invalid"
test_path_not_exists "$missing_openspec_root/dist/core/config-prompts.js"

mismatched_openspec_root="$tmp_dir/mismatched-openspec"
mkdir -p "$mismatched_openspec_root"
printf '{"name":"@fission-ai/openspec","version":"9.9.9"}\n' > "$mismatched_openspec_root/package.json"

set +e
mismatched_openspec_repair_output="$(OPENSPEC_ROOT="$mismatched_openspec_root" "$DOCTOR" --repair 2>&1)"
mismatched_openspec_repair_status=$?
set -e

assert_exit_code "$mismatched_openspec_repair_status" "1"
assert_contains "$mismatched_openspec_repair_output" "override target 1.6.0"
test_path_not_exists "$mismatched_openspec_root/dist/core/config-prompts.js"

set +e
mismatched_openspec_install_output="$(OPENSPEC_ROOT="$mismatched_openspec_root" "$INSTALLER" 2>&1)"
mismatched_openspec_install_status=$?
set -e

assert_exit_code "$mismatched_openspec_install_status" "1"
assert_contains "$mismatched_openspec_install_output" "firefly Codex install incomplete"
test_path_not_exists "$mismatched_openspec_root/dist/core/config-prompts.js"

invalid_openspec_root="$tmp_dir/invalid-openspec"
mkdir -p "$invalid_openspec_root"
rm -rf "$CODEX_HOME/skills/firefly"

set +e
invalid_openspec_install_output="$(OPENSPEC_ROOT="$invalid_openspec_root" "$INSTALLER" 2>&1)"
invalid_openspec_install_status=$?
set -e

assert_exit_code "$invalid_openspec_install_status" "1"
assert_contains "$invalid_openspec_install_output" "OpenSpec package metadata is missing or invalid"
test_path_not_exists "$invalid_openspec_root/dist/core/config-prompts.js"
test_file_exists "$CODEX_HOME/skills/firefly/SKILL.md"

bad_root_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir" "$bad_root_dir"' EXIT

set +e
bad_root_output="$(CODEX_HOME="$bad_root_dir" "$INSTALLER" 2>&1)"
bad_root_status=$?
set -e
assert_exit_code "$bad_root_status" "1"
assert_contains "$bad_root_output" "must end with .codex"

set +e
bad_openspec_output="$(CODEX_HOME="$CODEX_HOME" OPENSPEC_ROOT=/ "$INSTALLER" 2>&1)"
bad_openspec_status=$?
set -e
assert_exit_code "$bad_openspec_status" "1"
assert_contains "$bad_openspec_output" "root path must not be /"

missing_openspec_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir" "$bad_root_dir" "$missing_openspec_dir"' EXIT
mkdir -p "$missing_openspec_dir/.codex/superpowers"

set +e
missing_openspec_install_output="$(env -u OPENSPEC_ROOT CODEX_HOME="$missing_openspec_dir/.codex" FIREFLY_BIN_DIR="$missing_openspec_dir/.local/bin" PATH="$bin_dir:$PATH" "$INSTALLER" 2>&1)"
missing_openspec_install_status=$?
set -e

assert_exit_code "$missing_openspec_install_status" "1"
assert_contains "$missing_openspec_install_output" "openspec install root not found"
assert_contains "$missing_openspec_install_output" "firefly Codex install incomplete"

echo "codex installer smoke test passed"

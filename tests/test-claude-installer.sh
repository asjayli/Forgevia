#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALLER="$ROOT_DIR/scripts/install-claude.sh"
DOCTOR="$ROOT_DIR/scripts/doctor-claude.sh"
MANIFEST="$ROOT_DIR/manifests/claude.json"

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

assert_paths_equal() {
  local expected="$1"
  local actual="$2"

  if ! diff -qr "$expected" "$actual" >/dev/null; then
    echo "expected installed source mirror to match: $expected $actual" >&2
    diff -qr "$expected" "$actual" >&2 || true
    exit 1
  fi
}

test_file_exists "$MANIFEST"
test_file_exists "$INSTALLER"
test_file_exists "$DOCTOR"

manifest_skill_sources="$(node -e 'const m=require(process.argv[1]); console.log(m.managedAssets.filter(a => a.kind === "skill-directory" && a.source.startsWith(".claude/skills/")).map(a => a.source).sort().join("\n"))' "$MANIFEST")"
scanned_skill_sources="$(find "$ROOT_DIR/.claude/skills" -mindepth 1 -maxdepth 1 -type d -printf '.claude/skills/%f\n' | sort)"
if [[ "$manifest_skill_sources" != "$scanned_skill_sources" ]]; then
  echo "Claude manifest skill assets do not match .claude/skills" >&2
  exit 1
fi

assert_contains "$(<"$MANIFEST")" '"version": "1.6.0"'
assert_contains "$(<"$MANIFEST")" '"overrideTargetVersion": "1.6.0"'
assert_contains "$(<"$INSTALLER")" 'npm install -g @fission-ai/openspec@1.6.0'

installer_help="$("$INSTALLER" --help)"
doctor_help="$("$DOCTOR" --help)"
assert_contains "$installer_help" "Install Forgevia Claude assets"
assert_contains "$installer_help" "$MANIFEST"
assert_contains "$installer_help" "installs OpenSpec 1.6.0 on every run"
assert_contains "$doctor_help" "Check Forgevia Claude managed assets"
assert_contains "$doctor_help" "$MANIFEST"
assert_contains "$doctor_help" "--repair"
assert_contains "$doctor_help" "Forgevia runtime command dispatcher"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

export CLAUDE_HOME="$tmp_dir/.claude"
bin_dir="$tmp_dir/bin"
superpowers_root="$CLAUDE_HOME/plugins/cache/superpowers/6.1.1"
export OPENSPEC_ROOT="$tmp_dir/openspec"
npm_log="$tmp_dir/npm.log"
export FAKE_NPM_ROOT="$tmp_dir/npm-global"
export FAKE_NPM_LOG="$npm_log"
mkdir -p "$CLAUDE_HOME/skills/forgevia-think" "$bin_dir"
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

set +e
deprecated_flag_output="$(PATH="$bin_dir:$PATH" "$INSTALLER" --install-openspec 2>&1)"
deprecated_flag_status=$?
set -e
if [[ "$deprecated_flag_status" != "1" ]]; then
  echo "expected deprecated --install-openspec exit code 1 but got $deprecated_flag_status" >&2
  exit 1
fi
assert_contains "$deprecated_flag_output" "unknown argument: --install-openspec"

mkdir -p "$CLAUDE_HOME/plugins"
mkdir -p "$superpowers_root/skills/brainstorming"
mkdir -p "$superpowers_root/skills/writing-plans"
mkdir -p "$superpowers_root/skills/test-driven-development"
mkdir -p "$superpowers_root/skills/subagent-driven-development"
mkdir -p "$superpowers_root/skills/requesting-code-review"
mkdir -p "$superpowers_root/skills/executing-plans"
mkdir -p "$OPENSPEC_ROOT/dist/core/templates/workflows"
printf '{"name":"@fission-ai/openspec","version":"1.6.0"}\n' > "$OPENSPEC_ROOT/package.json"
printf 'user local claude think\n' > "$CLAUDE_HOME/skills/forgevia-think/SKILL.md"
printf 'user local claude brainstorming\n' > "$superpowers_root/skills/brainstorming/SKILL.md"
printf 'user local claude tdd\n' > "$superpowers_root/skills/test-driven-development/SKILL.md"
printf 'user local claude review\n' > "$superpowers_root/skills/requesting-code-review/SKILL.md"
printf 'export function serializeConfig() { return "wrong"; }\n' > "$OPENSPEC_ROOT/dist/core/config-prompts.js"
printf 'export const propose = "wrong";\n' > "$OPENSPEC_ROOT/dist/core/templates/workflows/propose.js"
cat > "$bin_dir/openspec" <<EOF
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$bin_dir/openspec"
cat > "$CLAUDE_HOME/plugins/installed_plugins.json" <<EOF
{
  "version": 2,
  "plugins": {
    "superpowers@superpowers-marketplace": [
      {
        "scope": "user",
        "installPath": "$superpowers_root",
        "version": "6.1.1"
      }
    ]
  }
}
EOF

installer_output="$(PATH="$bin_dir:$PATH" "$INSTALLER")"
assert_contains "$installer_output" "🧱 Forgevia Claude installer"
assert_contains "$installer_output" "✅ Applied openspec override"
assert_contains "$installer_output" "✅ Applied Forgevia-managed Claude assets"
assert_contains "$installer_output" "✅ Detected Claude superpowers plugin at $superpowers_root"
assert_contains "$installer_output" "✅ Applied Forgevia-managed Claude superpowers overrides"
assert_contains "$installer_output" "💾 Backed up"
assert_contains "$installer_output" "🎉 Forgevia Claude install complete"
assert_contains "$(cat "$npm_log")" "install -g @fission-ai/openspec@1.6.0"

for mirror_path in .claude assets scripts manifests; do
  assert_paths_equal "$ROOT_DIR/$mirror_path" "$CLAUDE_HOME/forgevia/$mirror_path"
done

test_path_not_exists "$CLAUDE_HOME/skills/forgevia-think.forgevia.bak"
test_path_not_exists "$superpowers_root/skills/brainstorming/SKILL.md.forgevia.bak"
test_path_not_exists "$superpowers_root/skills/test-driven-development/SKILL.md.forgevia.bak"
test_path_not_exists "$superpowers_root/skills/requesting-code-review/SKILL.md.forgevia.bak"
test_path_not_exists "$OPENSPEC_ROOT/dist/core/config-prompts.js.forgevia.bak"
test_path_not_exists "$OPENSPEC_ROOT/dist/core/templates/workflows/propose.js.forgevia.bak"
test_file_exists "$CLAUDE_HOME/skills/forgevia-think/SKILL.md"
test_file_exists "$CLAUDE_HOME/skills/forgevia/SKILL.md"
test_file_exists "$CLAUDE_HOME/skills/openspec-propose/SKILL.md"
test_file_exists "$CLAUDE_HOME/skills/openspec-sync-specs/SKILL.md"
test_file_exists "$CLAUDE_HOME/skills/mermaid-diagram-specialist/SKILL.md"
test_file_exists "$CLAUDE_HOME/skills/playwright-interactive/SKILL.md"
test_file_exists "$CLAUDE_HOME/commands/opsx/propose.md"
test_file_exists "$superpowers_root/skills/brainstorming/SKILL.md"
test_file_exists "$superpowers_root/skills/writing-plans/SKILL.md"
test_file_exists "$superpowers_root/skills/test-driven-development/SKILL.md"
test_file_exists "$superpowers_root/skills/subagent-driven-development/SKILL.md"
test_file_exists "$superpowers_root/skills/requesting-code-review/SKILL.md"
test_file_exists "$superpowers_root/skills/requesting-code-review/code-reviewer.md"
test_file_exists "$superpowers_root/skills/executing-plans/SKILL.md"

# subagent-driven-development is overlaid as a whole directory: its runtime
# scripts and prompt templates must land alongside SKILL.md, and the scripts
# must keep their exec bit through the cp -R overlay.
sdd_root="$superpowers_root/skills/subagent-driven-development"
test_file_exists "$sdd_root/task-reviewer-prompt.md"
test_file_exists "$sdd_root/implementer-prompt.md"
test_file_executable "$sdd_root/scripts/task-brief"
test_file_executable "$sdd_root/scripts/review-package"
test_file_executable "$sdd_root/scripts/sdd-workspace"

# Runtime scripts are installed to ~/.claude/forgevia/bin and must stay executable.
test_file_executable "$CLAUDE_HOME/forgevia/bin/bootstrap-project.sh"
test_file_executable "$CLAUDE_HOME/forgevia/bin/list-change-tasks.sh"
test_file_executable "$CLAUDE_HOME/forgevia/bin/forgevia-draw.sh"
test_file_executable "$CLAUDE_HOME/forgevia/bin/doctor-claude.sh"
test_file_executable "$CLAUDE_HOME/forgevia/bin/validate-openspec-cn.mjs"
cmp "$ROOT_DIR/scripts/validate-openspec-cn.mjs" "$CLAUDE_HOME/forgevia/bin/validate-openspec-cn.mjs"
test_file_executable "$CLAUDE_HOME/forgevia/bin/forgevia"
cmp "$ROOT_DIR/scripts/forgevia.sh" "$CLAUDE_HOME/forgevia/bin/forgevia"

expected_skill="$(cat "$ROOT_DIR/.claude/skills/forgevia-think/SKILL.md")"
actual_skill="$(cat "$CLAUDE_HOME/skills/forgevia-think/SKILL.md")"
assert_contains "$actual_skill" "$expected_skill"
expected_router="$(cat "$ROOT_DIR/.claude/skills/forgevia/SKILL.md")"
actual_router="$(cat "$CLAUDE_HOME/skills/forgevia/SKILL.md")"
assert_contains "$actual_router" "$expected_router"
expected_brainstorming="$(cat "$ROOT_DIR/assets/claude/superpowers/skills/brainstorming/SKILL.md")"
actual_brainstorming="$(cat "$superpowers_root/skills/brainstorming/SKILL.md")"
assert_contains "$actual_brainstorming" "$expected_brainstorming"
expected_tdd="$(cat "$ROOT_DIR/assets/claude/superpowers/skills/test-driven-development/SKILL.md")"
actual_tdd="$(cat "$superpowers_root/skills/test-driven-development/SKILL.md")"
assert_contains "$actual_tdd" "$expected_tdd"
expected_review_template="$(cat "$ROOT_DIR/assets/claude/superpowers/skills/requesting-code-review/code-reviewer.md")"
actual_review_template="$(cat "$superpowers_root/skills/requesting-code-review/code-reviewer.md")"
assert_contains "$actual_review_template" "$expected_review_template"
expected_sdd="$(cat "$ROOT_DIR/assets/claude/superpowers/skills/subagent-driven-development/SKILL.md")"
actual_sdd="$(cat "$superpowers_root/skills/subagent-driven-development/SKILL.md")"
assert_contains "$actual_sdd" "$expected_sdd"
expected_command="$(cat "$ROOT_DIR/.claude/commands/opsx/propose.md")"
actual_command="$(cat "$CLAUDE_HOME/commands/opsx/propose.md")"
assert_contains "$actual_command" "$expected_command"
assert_contains "$(<"$MANIFEST")" '"id": "openspec-sync-specs-skill"'
expected_openspec_config="$(cat "$ROOT_DIR/assets/openspec/dist/core/config-prompts.js")"
actual_openspec_config="$(cat "$OPENSPEC_ROOT/dist/core/config-prompts.js")"
assert_contains "$actual_openspec_config" "$expected_openspec_config"
assert_contains "$expected_openspec_config" "# Project context (optional)"
assert_contains "$expected_openspec_config" "# Per-artifact rules (optional)"
assert_contains "$expected_openspec_config" "所有产出物必须用简体中文撰写。"
expected_openspec_propose="$(cat "$ROOT_DIR/assets/openspec/dist/core/templates/workflows/propose.js")"
actual_openspec_propose="$(cat "$OPENSPEC_ROOT/dist/core/templates/workflows/propose.js")"
assert_contains "$actual_openspec_propose" "$expected_openspec_propose"

doctor_output="$(PATH="$bin_dir:$PATH" "$DOCTOR")"
assert_contains "$doctor_output" "🔎 Forgevia Claude doctor"
assert_contains "$doctor_output" "✅ OK"
assert_contains "$doctor_output" "📋 Summary"
assert_contains "$doctor_output" "Forgevia Claude doctor passed"
assert_contains "$doctor_output" "$OPENSPEC_ROOT/dist/core/config-prompts.js"
assert_contains "$doctor_output" "$OPENSPEC_ROOT/dist/core/templates/workflows/propose.js"
assert_contains "$doctor_output" "$CLAUDE_HOME/skills/forgevia-think"
assert_contains "$doctor_output" "$CLAUDE_HOME/skills/forgevia"
assert_contains "$doctor_output" "$CLAUDE_HOME/commands/opsx"
assert_contains "$doctor_output" "$superpowers_root/skills/requesting-code-review"

echo "drift" >> "$superpowers_root/skills/brainstorming/SKILL.md"

set +e
drift_output="$(PATH="$bin_dir:$PATH" "$DOCTOR" 2>&1)"
drift_status=$?
set -e

if [[ "$drift_status" != "1" ]]; then
  echo "expected exit code 1 but got $drift_status" >&2
  exit 1
fi
assert_contains "$drift_output" "❌ DRIFT"
assert_contains "$drift_output" "📋 Summary"

repair_output="$(PATH="$bin_dir:$PATH" "$DOCTOR" --repair)"
assert_contains "$repair_output" "🛠️ Repairing drifted or missing assets"
assert_contains "$repair_output" "💾 Backed up"
assert_contains "$repair_output" "✅ Repaired"
test_path_not_exists "$superpowers_root/skills/brainstorming/SKILL.md.forgevia.bak"

post_repair_output="$(PATH="$bin_dir:$PATH" "$DOCTOR")"
assert_contains "$post_repair_output" "✨ No drift detected"
assert_contains "$post_repair_output" "Forgevia Claude doctor passed"

chmod -x "$CLAUDE_HOME/forgevia/bin/forgevia-draw.sh"

set +e
mode_drift_output="$(PATH="$bin_dir:$PATH" "$DOCTOR" 2>&1)"
mode_drift_status=$?
set -e

if [[ "$mode_drift_status" != "1" ]]; then
  echo "expected executable-bit drift exit code 1 but got $mode_drift_status" >&2
  exit 1
fi
assert_contains "$mode_drift_output" "❌ DRIFT"
assert_contains "$mode_drift_output" "$CLAUDE_HOME/forgevia/bin/forgevia-draw.sh"

mode_repair_output="$(PATH="$bin_dir:$PATH" "$DOCTOR" --repair)"
assert_contains "$mode_repair_output" "$CLAUDE_HOME/forgevia/bin/forgevia-draw.sh"
test_file_executable "$CLAUDE_HOME/forgevia/bin/forgevia-draw.sh"

rm "$CLAUDE_HOME/forgevia/bin/validate-openspec-cn.mjs"

set +e
validator_drift_output="$(PATH="$bin_dir:$PATH" "$DOCTOR" 2>&1)"
validator_drift_status=$?
set -e

if [[ "$validator_drift_status" != "1" ]]; then
  echo "expected validator drift exit code 1 but got $validator_drift_status" >&2
  exit 1
fi
assert_contains "$validator_drift_output" "validate-openspec-cn.mjs"

validator_repair_output="$(PATH="$bin_dir:$PATH" "$DOCTOR" --repair)"
assert_contains "$validator_repair_output" "validate-openspec-cn.mjs"
test_file_executable "$CLAUDE_HOME/forgevia/bin/validate-openspec-cn.mjs"
cmp "$ROOT_DIR/scripts/validate-openspec-cn.mjs" "$CLAUDE_HOME/forgevia/bin/validate-openspec-cn.mjs"

rm "$CLAUDE_HOME/forgevia/bin/forgevia"

set +e
command_drift_output="$(PATH="$bin_dir:$PATH" "$DOCTOR" 2>&1)"
command_drift_status=$?
set -e

if [[ "$command_drift_status" != "1" ]]; then
  echo "expected command drift exit code 1 but got $command_drift_status" >&2
  exit 1
fi
assert_contains "$command_drift_output" "$CLAUDE_HOME/forgevia/bin/forgevia"

command_repair_output="$(PATH="$bin_dir:$PATH" "$DOCTOR" --repair)"
assert_contains "$command_repair_output" "$CLAUDE_HOME/forgevia/bin/forgevia"
test_file_executable "$CLAUDE_HOME/forgevia/bin/forgevia"
cmp "$ROOT_DIR/scripts/forgevia.sh" "$CLAUDE_HOME/forgevia/bin/forgevia"

rm "$CLAUDE_HOME/forgevia/bin/doctor-claude.sh"

set +e
doctor_script_drift_output="$(PATH="$bin_dir:$PATH" "$DOCTOR" 2>&1)"
doctor_script_drift_status=$?
set -e

if [[ "$doctor_script_drift_status" != "1" ]]; then
  echo "expected doctor runtime script drift exit code 1 but got $doctor_script_drift_status" >&2
  exit 1
fi
assert_contains "$doctor_script_drift_output" "$CLAUDE_HOME/forgevia/bin/doctor-claude.sh"

doctor_script_repair_output="$(PATH="$bin_dir:$PATH" "$DOCTOR" --repair)"
assert_contains "$doctor_script_repair_output" "$CLAUDE_HOME/forgevia/bin/doctor-claude.sh"
test_file_executable "$CLAUDE_HOME/forgevia/bin/doctor-claude.sh"
cmp "$ROOT_DIR/scripts/doctor-claude.sh" "$CLAUDE_HOME/forgevia/bin/doctor-claude.sh"

missing_openspec_root="$tmp_dir/missing-openspec"
rm -rf "$missing_openspec_root"

set +e
missing_openspec_repair_output="$(OPENSPEC_ROOT="$missing_openspec_root" PATH="$bin_dir:$PATH" "$DOCTOR" --repair 2>&1)"
missing_openspec_repair_status=$?
set -e

if [[ "$missing_openspec_repair_status" != "1" ]]; then
  echo "expected missing openspec repair exit code 1 but got $missing_openspec_repair_status" >&2
  exit 1
fi
assert_contains "$missing_openspec_repair_output" "OpenSpec package is missing or invalid"
test_path_not_exists "$missing_openspec_root/dist/core/config-prompts.js"

mismatched_openspec_root="$tmp_dir/mismatched-openspec"
mkdir -p "$mismatched_openspec_root"
printf '{"name":"@fission-ai/openspec","version":"9.9.9"}\n' > "$mismatched_openspec_root/package.json"

set +e
mismatched_openspec_repair_output="$(OPENSPEC_ROOT="$mismatched_openspec_root" PATH="$bin_dir:$PATH" "$DOCTOR" --repair 2>&1)"
mismatched_openspec_repair_status=$?
set -e

if [[ "$mismatched_openspec_repair_status" != "1" ]]; then
  echo "expected mismatched openspec repair exit code 1 but got $mismatched_openspec_repair_status" >&2
  exit 1
fi
assert_contains "$mismatched_openspec_repair_output" "override target 1.6.0"
test_path_not_exists "$mismatched_openspec_root/dist/core/config-prompts.js"

set +e
mismatched_openspec_install_output="$(OPENSPEC_ROOT="$mismatched_openspec_root" PATH="$bin_dir:$PATH" "$INSTALLER" 2>&1)"
mismatched_openspec_install_status=$?
set -e

if [[ "$mismatched_openspec_install_status" != "1" ]]; then
  echo "expected mismatched openspec installer exit code 1 but got $mismatched_openspec_install_status" >&2
  exit 1
fi
assert_contains "$mismatched_openspec_install_output" "Forgevia Claude install incomplete"
test_path_not_exists "$mismatched_openspec_root/dist/core/config-prompts.js"

invalid_openspec_root="$tmp_dir/invalid-openspec"
mkdir -p "$invalid_openspec_root"
rm -rf "$CLAUDE_HOME/skills/forgevia"

set +e
invalid_openspec_install_output="$(OPENSPEC_ROOT="$invalid_openspec_root" PATH="$bin_dir:$PATH" "$INSTALLER" 2>&1)"
invalid_openspec_install_status=$?
set -e

if [[ "$invalid_openspec_install_status" != "1" ]]; then
  echo "expected invalid openspec installer exit code 1 but got $invalid_openspec_install_status" >&2
  exit 1
fi
assert_contains "$invalid_openspec_install_output" "OpenSpec package metadata is missing or invalid"
test_path_not_exists "$invalid_openspec_root/dist/core/config-prompts.js"
test_file_exists "$CLAUDE_HOME/skills/forgevia/SKILL.md"

missing_openspec_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir" "$missing_openspec_dir"' EXIT
export CLAUDE_HOME="$missing_openspec_dir/.claude"
unset OPENSPEC_ROOT
mkdir -p "$CLAUDE_HOME/plugins"
missing_openspec_superpowers_root="$CLAUDE_HOME/plugins/cache/superpowers/6.1.1"
mkdir -p "$missing_openspec_superpowers_root/skills"
cat > "$CLAUDE_HOME/plugins/installed_plugins.json" <<EOF
{
  "version": 2,
  "plugins": {
    "superpowers@superpowers-marketplace": [
      {
        "scope": "user",
        "installPath": "$missing_openspec_superpowers_root",
        "version": "6.1.1"
      }
    ]
  }
}
EOF

set +e
missing_openspec_output="$(PATH="$bin_dir:$PATH" "$INSTALLER" 2>&1)"
missing_openspec_status=$?
set -e

if [[ "$missing_openspec_status" != "1" ]]; then
  echo "expected missing openspec exit code 1 but got $missing_openspec_status" >&2
  exit 1
fi
assert_contains "$missing_openspec_output" "openspec install root not found"
assert_contains "$missing_openspec_output" "Applied Forgevia-managed Claude assets"
assert_contains "$missing_openspec_output" "Applied Forgevia-managed Claude superpowers overrides"
assert_contains "$missing_openspec_output" "Forgevia Claude install incomplete"

missing_plugin_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir" "$missing_openspec_dir" "$missing_plugin_dir"' EXIT
export CLAUDE_HOME="$missing_plugin_dir/.claude"
export OPENSPEC_ROOT="$tmp_dir/openspec"
mkdir -p "$CLAUDE_HOME/plugins"

set +e
missing_plugin_output="$(PATH="$bin_dir:$PATH" "$INSTALLER" 2>&1)"
missing_plugin_status=$?
set -e

if [[ "$missing_plugin_status" != "1" ]]; then
  echo "expected missing plugin exit code 1 but got $missing_plugin_status" >&2
  exit 1
fi
assert_contains "$missing_plugin_output" "/plugin marketplace add obra/superpowers-marketplace"
assert_contains "$missing_plugin_output" "/plugin install superpowers@superpowers-marketplace"
assert_contains "$missing_plugin_output" "choose:"
assert_contains "$missing_plugin_output" "user"
assert_contains "$missing_plugin_output" "CLAUDE_SUPERPOWERS_ROOT"

untrusted_plugin_dir="$tmp_dir/untrusted-plugin"
untrusted_plugin_home="$tmp_dir/untrusted-plugin-home/.claude"
mkdir -p "$untrusted_plugin_dir/skills/brainstorming" "$untrusted_plugin_home/plugins"
printf 'do not replace\n' > "$untrusted_plugin_dir/skills/brainstorming/SKILL.md"
cat > "$untrusted_plugin_home/plugins/installed_plugins.json" <<EOF
{
  "version": 2,
  "plugins": {
    "superpowers@superpowers-marketplace": [
      {
        "scope": "user",
        "installPath": "$untrusted_plugin_dir",
        "version": "6.1.1"
      }
    ]
  }
}
EOF

set +e
untrusted_plugin_output="$(CLAUDE_HOME="$untrusted_plugin_home" OPENSPEC_ROOT="$tmp_dir/openspec" PATH="$bin_dir:$PATH" "$INSTALLER" 2>&1)"
untrusted_plugin_status=$?
set -e

if [[ "$untrusted_plugin_status" != "1" ]]; then
  echo "expected untrusted plugin path installer exit code 1 but got $untrusted_plugin_status" >&2
  exit 1
fi
assert_contains "$untrusted_plugin_output" "must be inside"
if [[ "$(cat "$untrusted_plugin_dir/skills/brainstorming/SKILL.md")" != "do not replace" ]]; then
  echo "installer must not overlay an automatically discovered plugin outside CLAUDE_HOME" >&2
  exit 1
fi

linked_skills_home="$tmp_dir/linked-skills-home/.claude"
linked_skills_root="$linked_skills_home/plugins/cache/superpowers/6.1.1"
linked_skills_target="$tmp_dir/linked-skills-target"
mkdir -p "$linked_skills_root" "$linked_skills_target/brainstorming" "$linked_skills_home/plugins"
printf 'preserve linked skill\n' > "$linked_skills_target/brainstorming/SKILL.md"
ln -s "$linked_skills_target" "$linked_skills_root/skills"
cat > "$linked_skills_home/plugins/installed_plugins.json" <<EOF
{
  "version": 2,
  "plugins": {
    "superpowers@superpowers-marketplace": [
      {
        "scope": "user",
        "installPath": "$linked_skills_root",
        "version": "6.1.1"
      }
    ]
  }
}
EOF

set +e
linked_skills_output="$(CLAUDE_HOME="$linked_skills_home" OPENSPEC_ROOT="$tmp_dir/openspec" PATH="$bin_dir:$PATH" "$INSTALLER" 2>&1)"
linked_skills_status=$?
set -e

if [[ "$linked_skills_status" != "1" ]]; then
  echo "expected symlinked plugin skills installer exit code 1 but got $linked_skills_status" >&2
  exit 1
fi
assert_contains "$linked_skills_output" "must not contain symlinks"
if [[ "$(cat "$linked_skills_target/brainstorming/SKILL.md")" != "preserve linked skill" ]]; then
  echo "installer must not write through a symlinked plugin skills directory" >&2
  exit 1
fi

set +e
linked_skills_doctor_output="$(CLAUDE_HOME="$linked_skills_home" OPENSPEC_ROOT="$tmp_dir/openspec" PATH="$bin_dir:$PATH" "$DOCTOR" --repair 2>&1)"
linked_skills_doctor_status=$?
set -e

if [[ "$linked_skills_doctor_status" != "1" ]]; then
  echo "expected symlinked plugin skills doctor exit code 1 but got $linked_skills_doctor_status" >&2
  exit 1
fi
assert_contains "$linked_skills_doctor_output" "must not contain symlinks"
if [[ "$(cat "$linked_skills_target/brainstorming/SKILL.md")" != "preserve linked skill" ]]; then
  echo "doctor must not repair through a symlinked plugin skills directory" >&2
  exit 1
fi

bad_root_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir" "$missing_openspec_dir" "$missing_plugin_dir" "$bad_root_dir"' EXIT

set +e
bad_root_output="$(CLAUDE_HOME="$bad_root_dir" "$INSTALLER" 2>&1)"
bad_root_status=$?
set -e
if [[ "$bad_root_status" != "1" ]]; then
  echo "expected bad root exit code 1 but got $bad_root_status" >&2
  exit 1
fi
assert_contains "$bad_root_output" "must end with .claude"

set +e
bad_openspec_output="$(CLAUDE_HOME="$CLAUDE_HOME" OPENSPEC_ROOT=/ "$INSTALLER" 2>&1)"
bad_openspec_status=$?
set -e
if [[ "$bad_openspec_status" != "1" ]]; then
  echo "expected bad openspec root exit code 1 but got $bad_openspec_status" >&2
  exit 1
fi
assert_contains "$bad_openspec_output" "root path must not be /"

echo "claude installer smoke test passed"

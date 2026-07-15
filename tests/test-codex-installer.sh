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

installer_help="$("$INSTALLER" --help)"
doctor_help="$("$DOCTOR" --help)"

assert_contains "$installer_help" "Install Forgevia Codex assets"
assert_contains "$installer_help" "$MANIFEST"
assert_contains "$doctor_help" "Check Forgevia Codex managed assets"
assert_contains "$doctor_help" "$MANIFEST"
assert_contains "$doctor_help" "--repair"
assert_contains "$doctor_help" "Forgevia runtime command dispatcher"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

export CODEX_HOME="$tmp_dir/.codex"
export OPENSPEC_ROOT="$tmp_dir/openspec"
mkdir -p "$CODEX_HOME/superpowers/skills/brainstorming"
mkdir -p "$CODEX_HOME/superpowers/skills/writing-plans"
mkdir -p "$CODEX_HOME/superpowers/skills/executing-plans"
mkdir -p "$CODEX_HOME/superpowers/skills/subagent-driven-development"
mkdir -p "$CODEX_HOME/superpowers/skills/requesting-code-review"
mkdir -p "$CODEX_HOME/superpowers/skills/test-driven-development"
mkdir -p "$OPENSPEC_ROOT/dist/core"
mkdir -p "$OPENSPEC_ROOT/dist/core/templates/workflows"
printf 'user local brainstorming\n' > "$CODEX_HOME/superpowers/skills/brainstorming/SKILL.md"
printf 'user local tdd\n' > "$CODEX_HOME/superpowers/skills/test-driven-development/SKILL.md"
printf 'export function serializeConfig() { return \"wrong\"; }\n' > "$OPENSPEC_ROOT/dist/core/config-prompts.js"
printf 'export const propose = \"wrong\";\n' > "$OPENSPEC_ROOT/dist/core/templates/workflows/propose.js"

installer_output="$("$INSTALLER")"
assert_contains "$installer_output" "🧱 Forgevia Codex installer"
assert_contains "$installer_output" "✅ Applied openspec override"
assert_contains "$installer_output" "✅ Applied Forgevia-managed Codex assets"
assert_contains "$installer_output" "💾 Backed up"
assert_contains "$installer_output" "🎉 Forgevia Codex install complete"

for mirror_path in .claude assets scripts manifests; do
  assert_paths_equal "$ROOT_DIR/$mirror_path" "$CODEX_HOME/forgevia/$mirror_path"
done

test_path_not_exists "$CODEX_HOME/superpowers/skills/brainstorming/SKILL.md.forgevia.bak"
test_path_not_exists "$CODEX_HOME/superpowers/skills/test-driven-development/SKILL.md.forgevia.bak"
test_path_not_exists "$OPENSPEC_ROOT/dist/core/config-prompts.js.forgevia.bak"
test_path_not_exists "$OPENSPEC_ROOT/dist/core/templates/workflows/propose.js.forgevia.bak"
test_file_exists "$CODEX_HOME/skills/mermaid-diagram-specialist/SKILL.md"
test_file_exists "$CODEX_HOME/skills/forgevia/SKILL.md"
test_file_exists "$CODEX_HOME/skills/forgevia-init/SKILL.md"
test_file_exists "$CODEX_HOME/skills/forgevia-doctor/SKILL.md"
test_file_exists "$CODEX_HOME/skills/forgevia-repair/SKILL.md"
test_file_exists "$CODEX_HOME/skills/forgevia-implement/SKILL.md"
test_file_exists "$CODEX_HOME/skills/forgevia-archive/SKILL.md"
test_file_exists "$CODEX_HOME/skills/forgevia-tasks/SKILL.md"
test_file_exists "$CODEX_HOME/skills/forgevia-think/SKILL.md"
test_file_exists "$CODEX_HOME/skills/forgevia-propose/SKILL.md"
test_file_exists "$CODEX_HOME/skills/forgevia-review/SKILL.md"
test_file_exists "$CODEX_HOME/skills/forgevia-verify-web/SKILL.md"
test_file_exists "$CODEX_HOME/skills/forgevia-draw/SKILL.md"
test_file_exists "$CODEX_HOME/skills/openspec-propose/SKILL.md"
test_file_exists "$CODEX_HOME/skills/openspec-apply-change/SKILL.md"
test_file_exists "$CODEX_HOME/skills/openspec-archive-change/SKILL.md"
test_file_exists "$CODEX_HOME/skills/openspec-explore/SKILL.md"
test_file_exists "$CODEX_HOME/skills/openspec-sync-specs/SKILL.md"

for skill_name in openspec-propose openspec-apply-change openspec-archive-change openspec-explore openspec-sync-specs; do
  cmp "$ROOT_DIR/assets/codex/skills/$skill_name/SKILL.md" "$CODEX_HOME/skills/$skill_name/SKILL.md"
  assert_contains "$(<"$CODEX_HOME/skills/$skill_name/SKILL.md")" 'generatedBy: "1.5.0"'
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
test_file_exists "$codex_sp_root/subagent-driven-development/task-reviewer-prompt.md"
test_file_exists "$codex_sp_root/subagent-driven-development/implementer-prompt.md"
test_file_executable "$codex_sp_root/subagent-driven-development/scripts/task-brief"
test_file_executable "$codex_sp_root/subagent-driven-development/scripts/review-package"
test_file_executable "$codex_sp_root/subagent-driven-development/scripts/sdd-workspace"
test_file_exists "$codex_sp_root/requesting-code-review/SKILL.md"
test_file_exists "$codex_sp_root/requesting-code-review/code-reviewer.md"

# Runtime scripts are installed to ~/.codex/forgevia/bin and must stay executable.
test_file_executable "$CODEX_HOME/forgevia/bin/bootstrap-project.sh"
test_file_executable "$CODEX_HOME/forgevia/bin/list-change-tasks.sh"
test_file_executable "$CODEX_HOME/forgevia/bin/forgevia-draw.sh"
test_file_executable "$CODEX_HOME/forgevia/bin/doctor-codex.sh"
test_file_executable "$CODEX_HOME/forgevia/bin/validate-openspec-cn.mjs"
cmp "$ROOT_DIR/scripts/validate-openspec-cn.mjs" "$CODEX_HOME/forgevia/bin/validate-openspec-cn.mjs"
test_file_executable "$CODEX_HOME/forgevia/bin/forgevia"
cmp "$ROOT_DIR/scripts/forgevia.sh" "$CODEX_HOME/forgevia/bin/forgevia"

doctor_output="$("$DOCTOR")"
assert_contains "$doctor_output" "🔎 Forgevia Codex doctor"
assert_contains "$doctor_output" "✅ OK"
assert_contains "$doctor_output" "📋 Summary"
assert_contains "$doctor_output" "Forgevia Codex doctor passed"
assert_contains "$doctor_output" "$OPENSPEC_ROOT/dist/core/config-prompts.js"
assert_contains "$doctor_output" "$OPENSPEC_ROOT/dist/core/templates/workflows/propose.js"
assert_contains "$doctor_output" "$CODEX_HOME/skills/openspec-propose"
assert_contains "$doctor_output" "$CODEX_HOME/skills/openspec-apply-change"
assert_contains "$doctor_output" "$CODEX_HOME/skills/openspec-sync-specs"

expected_openspec_config="$(cat "$ROOT_DIR/assets/openspec/dist/core/config-prompts.js")"
actual_openspec_config="$(cat "$OPENSPEC_ROOT/dist/core/config-prompts.js")"
assert_contains "$actual_openspec_config" "$expected_openspec_config"
expected_openspec_propose="$(cat "$ROOT_DIR/assets/openspec/dist/core/templates/workflows/propose.js")"
actual_openspec_propose="$(cat "$OPENSPEC_ROOT/dist/core/templates/workflows/propose.js")"
assert_contains "$actual_openspec_propose" "$expected_openspec_propose"
expected_openspec_propose_skill="$(cat "$ROOT_DIR/assets/codex/skills/openspec-propose/SKILL.md")"
actual_openspec_propose_skill="$(cat "$CODEX_HOME/skills/openspec-propose/SKILL.md")"
assert_contains "$actual_openspec_propose_skill" "$expected_openspec_propose_skill"
assert_contains "$actual_openspec_propose_skill" "Use Forgevia Implement"
assert_contains "$actual_openspec_propose" "Use Forgevia Implement to start implementation."

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
test_path_not_exists "$CODEX_HOME/superpowers/skills/brainstorming/SKILL.md.forgevia.bak"

post_repair_output="$("$DOCTOR")"
assert_contains "$post_repair_output" "✨ No drift detected"
assert_contains "$post_repair_output" "Forgevia Codex doctor passed"

rm "$CODEX_HOME/forgevia/bin/validate-openspec-cn.mjs"

set +e
validator_drift_output="$("$DOCTOR" 2>&1)"
validator_drift_status=$?
set -e

assert_exit_code "$validator_drift_status" "1"
assert_contains "$validator_drift_output" "validate-openspec-cn.mjs"

validator_repair_output="$("$DOCTOR" --repair)"
assert_contains "$validator_repair_output" "validate-openspec-cn.mjs"
test_file_executable "$CODEX_HOME/forgevia/bin/validate-openspec-cn.mjs"
cmp "$ROOT_DIR/scripts/validate-openspec-cn.mjs" "$CODEX_HOME/forgevia/bin/validate-openspec-cn.mjs"

rm "$CODEX_HOME/forgevia/bin/forgevia"

set +e
command_drift_output="$($DOCTOR 2>&1)"
command_drift_status=$?
set -e

assert_exit_code "$command_drift_status" "1"
assert_contains "$command_drift_output" "$CODEX_HOME/forgevia/bin/forgevia"

command_repair_output="$($DOCTOR --repair)"
assert_contains "$command_repair_output" "$CODEX_HOME/forgevia/bin/forgevia"
test_file_executable "$CODEX_HOME/forgevia/bin/forgevia"
cmp "$ROOT_DIR/scripts/forgevia.sh" "$CODEX_HOME/forgevia/bin/forgevia"

echo "codex installer smoke test passed"

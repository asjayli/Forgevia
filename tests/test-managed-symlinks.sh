#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODEX_INSTALLER="$ROOT_DIR/scripts/install-codex.sh"
CODEX_DOCTOR="$ROOT_DIR/scripts/doctor-codex.sh"
CLAUDE_INSTALLER="$ROOT_DIR/scripts/install-claude.sh"
CLAUDE_DOCTOR="$ROOT_DIR/scripts/doctor-claude.sh"

assert_symlink() {
  local path="$1"

  if [[ ! -L "$path" ]]; then
    echo "expected managed path to remain a symlink: $path" >&2
    exit 1
  fi
}

assert_paths_equal() {
  local expected="$1"
  local actual="$2"

  if ! diff -qr "$expected" "$actual" >/dev/null; then
    echo "expected managed symlink target to match: $expected $actual" >&2
    exit 1
  fi
}

create_openspec_package() {
  local root="$1"

  mkdir -p "$root/dist/core/templates/workflows"
  printf '{"name":"@fission-ai/openspec","version":"1.6.0"}\n' > "$root/package.json"
  printf 'drift\n' > "$root/dist/core/config-prompts.js"
  printf 'drift\n' > "$root/dist/core/templates/workflows/propose.js"
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

bin_dir="$tmp_dir/bin"
mkdir -p "$bin_dir"
cat > "$bin_dir/npm" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  install)
    exit 0
    ;;
  root)
    printf '%s\n' "${FAKE_NPM_ROOT:?}"
    ;;
  *)
    exit 1
    ;;
esac
EOF
chmod +x "$bin_dir/npm"

codex_home="$tmp_dir/codex/.codex"
codex_openspec="$tmp_dir/codex/openspec"
global_bin_dir="$tmp_dir/.local/bin"
mkdir -p "$codex_home/superpowers"
create_openspec_package "$codex_openspec"

CODEX_HOME="$codex_home" FORGEVIA_BIN_DIR="$global_bin_dir" OPENSPEC_ROOT="$codex_openspec" FAKE_NPM_ROOT="$tmp_dir/npm-global" PATH="$bin_dir:$PATH" "$CODEX_INSTALLER" >/dev/null

codex_link_target="$tmp_dir/codex/user-managed/forgevia"
mkdir -p "$(dirname "$codex_link_target")"
mv "$codex_home/skills/forgevia" "$codex_link_target"
ln -s "$codex_link_target" "$codex_home/skills/forgevia"

CODEX_HOME="$codex_home" FORGEVIA_BIN_DIR="$global_bin_dir" OPENSPEC_ROOT="$codex_openspec" FAKE_NPM_ROOT="$tmp_dir/npm-global" PATH="$bin_dir:$PATH" "$CODEX_INSTALLER" >/dev/null
assert_symlink "$codex_home/skills/forgevia"
assert_paths_equal "$ROOT_DIR/assets/codex/skills/forgevia" "$codex_link_target"

printf 'drift\n' >> "$codex_link_target/SKILL.md"
CODEX_HOME="$codex_home" FORGEVIA_BIN_DIR="$global_bin_dir" OPENSPEC_ROOT="$codex_openspec" PATH="$bin_dir:$PATH" "$CODEX_DOCTOR" --repair >/dev/null
assert_symlink "$codex_home/skills/forgevia"
assert_paths_equal "$ROOT_DIR/assets/codex/skills/forgevia" "$codex_link_target"

claude_home="$tmp_dir/claude/.claude"
claude_openspec="$tmp_dir/claude/openspec"
claude_plugin="$claude_home/plugins/cache/superpowers/6.1.1"
mkdir -p "$claude_plugin/skills"
create_openspec_package "$claude_openspec"
cat > "$claude_home/plugins/installed_plugins.json" <<EOF
{
  "plugins": {
    "superpowers@superpowers-marketplace": [
      { "scope": "user", "installPath": "$claude_plugin" }
    ]
  }
}
EOF

CLAUDE_HOME="$claude_home" FORGEVIA_BIN_DIR="$global_bin_dir" OPENSPEC_ROOT="$claude_openspec" FAKE_NPM_ROOT="$tmp_dir/npm-global" PATH="$bin_dir:$PATH" "$CLAUDE_INSTALLER" >/dev/null

claude_link_target="$tmp_dir/claude/user-managed/forgevia"
mkdir -p "$(dirname "$claude_link_target")"
mv "$claude_home/skills/forgevia" "$claude_link_target"
ln -s "$claude_link_target" "$claude_home/skills/forgevia"

CLAUDE_HOME="$claude_home" FORGEVIA_BIN_DIR="$global_bin_dir" OPENSPEC_ROOT="$claude_openspec" FAKE_NPM_ROOT="$tmp_dir/npm-global" PATH="$bin_dir:$PATH" "$CLAUDE_INSTALLER" >/dev/null
assert_symlink "$claude_home/skills/forgevia"
assert_paths_equal "$ROOT_DIR/assets/claude/skills/forgevia" "$claude_link_target"

printf 'drift\n' >> "$claude_link_target/SKILL.md"
CLAUDE_HOME="$claude_home" FORGEVIA_BIN_DIR="$global_bin_dir" OPENSPEC_ROOT="$claude_openspec" PATH="$bin_dir:$PATH" "$CLAUDE_DOCTOR" --repair >/dev/null
assert_symlink "$claude_home/skills/forgevia"
assert_paths_equal "$ROOT_DIR/assets/claude/skills/forgevia" "$claude_link_target"

test -x "$global_bin_dir/forgevia"
test ! -L "$global_bin_dir/forgevia"
cmp "$ROOT_DIR/scripts/forgevia-global.sh" "$global_bin_dir/forgevia"
global_doctor_output="$(CODEX_HOME="$codex_home" CLAUDE_HOME="$claude_home" FORGEVIA_BIN_DIR="$global_bin_dir" OPENSPEC_ROOT="$claude_openspec" PATH="$bin_dir:$PATH" "$global_bin_dir/forgevia" doctor)"
[[ "$global_doctor_output" == *"Forgevia Codex doctor passed"* ]]
[[ "$global_doctor_output" == *"Forgevia Claude doctor passed"* ]]
global_repair_output="$(CODEX_HOME="$codex_home" CLAUDE_HOME="$claude_home" FORGEVIA_BIN_DIR="$global_bin_dir" OPENSPEC_ROOT="$claude_openspec" PATH="$bin_dir:$PATH" "$global_bin_dir/forgevia" doctor --repair)"
[[ "$global_repair_output" == *"Forgevia Codex doctor repair complete"* ]]
[[ "$global_repair_output" == *"Forgevia Claude doctor repair complete"* ]]

echo "managed symlink test passed"

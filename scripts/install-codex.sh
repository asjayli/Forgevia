#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_PATH="$ROOT_DIR/manifests/codex.json"
ASSETS_DIR="$ROOT_DIR/assets/codex"
OPENSPEC_ASSETS_DIR="$ROOT_DIR/assets/openspec"
CODEX_ROOT="${CODEX_HOME:-$HOME/.codex}"
FORGEVIA_BIN_DIR="${FORGEVIA_BIN_DIR:-$HOME/.local/bin}"
GLOBAL_COMMAND_STATE_PATH="$FORGEVIA_BIN_DIR/.forgevia-global-command.sha256"
SUPERPOWERS_INSTALL_URL="https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.codex/INSTALL.md"
OPENSPEC_ROOT="${OPENSPEC_ROOT:-}"
# Forgevia's openspec override files are snapshots taken against this upstream
# openspec version. Never overlay them onto a different upstream version —
# that would silently downgrade upstream behavior.
OPENSPEC_OVERRIDE_VERSION="1.6.0"

usage() {
  cat <<EOF
Install Forgevia Codex assets.

Usage:
  $(basename "$0") [--help]

Manifest:
  $MANIFEST_PATH

Behavior:
  - verifies the Codex root at $CODEX_ROOT
  - installs OpenSpec $OPENSPEC_OVERRIDE_VERSION on every run
  - overlays Forgevia-managed openspec customization
  - requires upstream superpowers to already exist
  - directly overlays Forgevia-managed assets into ~/.codex
  - exposes the forgevia command at ~/.local/bin/forgevia
EOF
}

log_info() {
  echo "ℹ️  $1"
}

log_step() {
  echo "🧱 $1"
}

log_success() {
  echo "✅ $1"
}

log_backup() {
  echo "💾 $1"
}

require_command() {
  local command_name="$1"
  if ! command -v "$command_name" >/dev/null 2>&1; then
    echo "missing required command: $command_name" >&2
    exit 1
  fi
}

validate_root() {
  local root_path="$1"
  local expected_suffix="$2"

  if [[ -z "$root_path" ]]; then
    echo "root path is empty" >&2
    exit 1
  fi
  if [[ "$root_path" != /* ]]; then
    echo "root path must be absolute: $root_path" >&2
    exit 1
  fi
  if [[ "$root_path" == "/" ]]; then
    echo "root path must not be /" >&2
    exit 1
  fi
  if [[ -n "$expected_suffix" && "$root_path" != *"$expected_suffix" ]]; then
    echo "root path must end with $expected_suffix: $root_path" >&2
    exit 1
  fi
}

ensure_under_root() {
  local target_path="$1"
  local root_path="$2"

  if [[ "$target_path" != "$root_path" && "$target_path" != "$root_path"/* ]]; then
    echo "target path escapes root: $target_path" >&2
    exit 1
  fi
}

copy_path() {
  local source_path="$1"
  local target_path="$2"

  mkdir -p "$(dirname "$target_path")"
  rm -rf "$target_path"
  cp -R "$source_path" "$target_path"
}

resolve_managed_target() {
  local target_path="$1"
  local resolved_path="$target_path"
  local link_target
  local depth=0

  # Preserve a user-managed final symlink while replacing its resolved target.
  while [[ -L "$resolved_path" ]]; do
    ((depth += 1))
    if [[ "$depth" -gt 40 ]]; then
      echo "too many symbolic links while resolving managed target: $target_path" >&2
      exit 1
    fi

    link_target="$(readlink "$resolved_path")"
    if [[ "$link_target" == /* ]]; then
      resolved_path="$link_target"
    else
      resolved_path="$(dirname "$resolved_path")/$link_target"
    fi
  done

  printf '%s\n' "$resolved_path"
}

backup_target_if_present() {
  local target_path="$1"
  local backup_path="${target_path}.forgevia.bak"

  if [[ ! -e "$target_path" ]]; then
    return
  fi

  rm -rf "$backup_path"
  cp -R "$target_path" "$backup_path"
  log_backup "Backed up $target_path -> $backup_path"
}

remove_stale_backup() {
  local target_path="$1"
  local backup_path="${target_path}.forgevia.bak"

  rm -rf "$backup_path"
}

sync_path() {
  local source_path="$1"
  local target_path="$2"
  local resolved_target

  resolved_target="$(resolve_managed_target "$target_path")"
  backup_target_if_present "$resolved_target"
  copy_path "$source_path" "$resolved_target"
  remove_stale_backup "$resolved_target"
}

install_openspec() {
  log_step "Installing OpenSpec $OPENSPEC_OVERRIDE_VERSION with npm"
  npm install -g @fission-ai/openspec@1.6.0
  log_success "Installed OpenSpec $OPENSPEC_OVERRIDE_VERSION from npm"
}

resolve_openspec_root() {
  if [[ -n "$OPENSPEC_ROOT" ]]; then
    validate_root "$OPENSPEC_ROOT" ""
    echo "$OPENSPEC_ROOT"
    return
  fi

  local npm_global_root
  npm_global_root="$(npm root -g)"
  local resolved="$npm_global_root/@fission-ai/openspec"
  validate_root "$resolved" "@fission-ai/openspec"
  echo "$resolved"
}

read_openspec_version() {
  local openspec_root="$1"
  local pkg="$openspec_root/package.json"
  [[ -f "$pkg" ]] || return 0
  node -e 'const p=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); process.stdout.write(p.version||"")' "$pkg" 2>/dev/null
}

is_valid_openspec_package() {
  local openspec_root="$1"
  local pkg="$openspec_root/package.json"

  [[ -f "$pkg" ]] || return 1
  node -e 'const p=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8")); process.exit(p.name === "@fission-ai/openspec" ? 0 : 1)' "$pkg" 2>/dev/null
}

openspec_version_matches() {
  local openspec_root="$1"
  local ver

  is_valid_openspec_package "$openspec_root" || return 1
  ver="$(read_openspec_version "$openspec_root")"
  [[ "$ver" == "$OPENSPEC_OVERRIDE_VERSION" ]]
}

verify_superpowers_present() {
  if [[ -d "$CODEX_ROOT/superpowers" ]]; then
    return
  fi

  cat >&2 <<EOF
superpowers is not installed under $CODEX_ROOT/superpowers

Install it first with:
Fetch and follow instructions from $SUPERPOWERS_INSTALL_URL
EOF
  exit 1
}

validate_global_command_target() {
  local command_path="$FORGEVIA_BIN_DIR/forgevia"

  validate_root "$FORGEVIA_BIN_DIR" ""
  if [[ ( -e "$command_path" || -L "$command_path" ) ]] && ! is_managed_global_command "$command_path" && ! is_legacy_runtime_link "$command_path"; then
    echo "refusing to replace existing command: $command_path" >&2
    exit 1
  fi
}

is_managed_global_command() {
  local command_path="$1"

  [[ -f "$command_path" && ! -L "$command_path" ]] || return 1
  cmp -s "$ROOT_DIR/scripts/forgevia-global.sh" "$command_path" && return 0
  [[ -f "$GLOBAL_COMMAND_STATE_PATH" ]] && [[ "$(<"$GLOBAL_COMMAND_STATE_PATH")" == "$(command_checksum "$command_path")" ]]
}

command_checksum() {
  sha256sum "$1" | awk '{print $1}'
}

write_global_command_state() {
  command_checksum "$FORGEVIA_BIN_DIR/forgevia" > "$GLOBAL_COMMAND_STATE_PATH"
}

is_legacy_runtime_link() {
  local command_path="$1"
  local target_path

  [[ -L "$command_path" ]] || return 1
  target_path="$(readlink "$command_path")"
  [[ "$target_path" == "$CODEX_ROOT/forgevia/bin/forgevia" || "$target_path" == "${CLAUDE_HOME:-$HOME/.claude}/forgevia/bin/forgevia" ]]
}

overlay_assets() {
  log_step "Overlaying Forgevia-managed assets into $CODEX_ROOT"

  sync_path "$ASSETS_DIR/skills/openspec-propose" "$CODEX_ROOT/skills/openspec-propose"
  sync_path "$ASSETS_DIR/skills/openspec-apply-change" "$CODEX_ROOT/skills/openspec-apply-change"
  sync_path "$ASSETS_DIR/skills/openspec-archive-change" "$CODEX_ROOT/skills/openspec-archive-change"
  sync_path "$ASSETS_DIR/skills/openspec-explore" "$CODEX_ROOT/skills/openspec-explore"
  sync_path "$ASSETS_DIR/skills/openspec-sync-specs" "$CODEX_ROOT/skills/openspec-sync-specs"
  sync_path "$ASSETS_DIR/skills/forgevia" "$CODEX_ROOT/skills/forgevia"
  sync_path "$ASSETS_DIR/skills/forgevia-init" "$CODEX_ROOT/skills/forgevia-init"
  sync_path "$ASSETS_DIR/skills/forgevia-doctor" "$CODEX_ROOT/skills/forgevia-doctor"
  sync_path "$ASSETS_DIR/skills/forgevia-repair" "$CODEX_ROOT/skills/forgevia-repair"
  sync_path "$ASSETS_DIR/skills/forgevia-implement" "$CODEX_ROOT/skills/forgevia-implement"
  sync_path "$ASSETS_DIR/skills/forgevia-archive" "$CODEX_ROOT/skills/forgevia-archive"
  sync_path "$ASSETS_DIR/skills/forgevia-tasks" "$CODEX_ROOT/skills/forgevia-tasks"
  sync_path "$ASSETS_DIR/skills/forgevia-think" "$CODEX_ROOT/skills/forgevia-think"
  sync_path "$ASSETS_DIR/skills/forgevia-propose" "$CODEX_ROOT/skills/forgevia-propose"
  sync_path "$ASSETS_DIR/skills/forgevia-review" "$CODEX_ROOT/skills/forgevia-review"
  sync_path "$ASSETS_DIR/skills/forgevia-verify-web" "$CODEX_ROOT/skills/forgevia-verify-web"
  sync_path "$ASSETS_DIR/skills/forgevia-draw" "$CODEX_ROOT/skills/forgevia-draw"
  sync_path "$ASSETS_DIR/skills/mermaid-diagram-specialist" "$CODEX_ROOT/skills/mermaid-diagram-specialist"
  sync_path "$ASSETS_DIR/skills/playwright-interactive" "$CODEX_ROOT/skills/playwright-interactive"
  sync_path "$ASSETS_DIR/superpowers/skills/brainstorming/SKILL.md" "$CODEX_ROOT/superpowers/skills/brainstorming/SKILL.md"
  sync_path "$ASSETS_DIR/superpowers/skills/writing-plans/SKILL.md" "$CODEX_ROOT/superpowers/skills/writing-plans/SKILL.md"
  sync_path "$ASSETS_DIR/superpowers/skills/executing-plans/SKILL.md" "$CODEX_ROOT/superpowers/skills/executing-plans/SKILL.md"
  sync_path "$ASSETS_DIR/superpowers/skills/subagent-driven-development" "$CODEX_ROOT/superpowers/skills/subagent-driven-development"
  sync_path "$ASSETS_DIR/superpowers/skills/requesting-code-review" "$CODEX_ROOT/superpowers/skills/requesting-code-review"
  sync_path "$ASSETS_DIR/superpowers/skills/test-driven-development/SKILL.md" "$CODEX_ROOT/superpowers/skills/test-driven-development/SKILL.md"
  log_success "Applied Forgevia-managed Codex assets"
}

overlay_runtime_scripts() {
  local runtime_dir="$CODEX_ROOT/forgevia/bin"
  log_step "Installing Forgevia runtime scripts into $runtime_dir"
  mkdir -p "$runtime_dir"
  sync_path "$ROOT_DIR/scripts/bootstrap-project.sh" "$runtime_dir/bootstrap-project.sh"
  sync_path "$ROOT_DIR/scripts/list-change-tasks.sh" "$runtime_dir/list-change-tasks.sh"
  sync_path "$ROOT_DIR/scripts/forgevia-draw.sh" "$runtime_dir/forgevia-draw.sh"
  sync_path "$ROOT_DIR/scripts/doctor-codex.sh" "$runtime_dir/doctor-codex.sh"
  sync_path "$ROOT_DIR/scripts/validate-openspec-cn.mjs" "$runtime_dir/validate-openspec-cn.mjs"
  sync_path "$ROOT_DIR/scripts/forgevia.sh" "$runtime_dir/forgevia"
  log_success "Installed Forgevia runtime scripts (forgevia/bootstrap/list-change-tasks/draw/doctor/validate-openspec-cn)"
}

install_global_command() {
  local command_path="$FORGEVIA_BIN_DIR/forgevia"

  log_step "Installing Forgevia command at $command_path"
  mkdir -p "$FORGEVIA_BIN_DIR"
  if [[ -e "$command_path" || -L "$command_path" ]]; then
    rm -f "$command_path"
  fi
  cp "$ROOT_DIR/scripts/forgevia-global.sh" "$command_path"
  write_global_command_state
  log_success "Installed Forgevia command: $command_path"
}

overlay_forgevia_home() {
  local home_dir="$CODEX_ROOT/forgevia"
  log_step "Mirroring Forgevia source into $home_dir (baseline for global doctor/repair)"
  sync_path "$ROOT_DIR/assets" "$home_dir/assets"
  sync_path "$ROOT_DIR/scripts" "$home_dir/scripts"
  sync_path "$ROOT_DIR/manifests" "$home_dir/manifests"
  log_success "Mirrored Forgevia source baseline"
}

overlay_openspec_assets() {
  local openspec_root
  openspec_root="$(resolve_openspec_root)"

  if [[ ! -d "$openspec_root" ]]; then
    echo "openspec install root not found: $openspec_root" >&2
    return 1
  fi

  if ! is_valid_openspec_package "$openspec_root"; then
    echo "OpenSpec package metadata is missing or invalid: $openspec_root/package.json" >&2
    return 1
  fi

  if ! openspec_version_matches "$openspec_root"; then
    local actual_version
    actual_version="$(read_openspec_version "$openspec_root")"
    log_info "openspec $actual_version detected; Forgevia openspec override targets $OPENSPEC_OVERRIDE_VERSION."
    log_info "Skipping openspec override to avoid downgrading upstream. Pin openspec to $OPENSPEC_OVERRIDE_VERSION or update Forgevia's override."
    return 1
  fi

  sync_path "$OPENSPEC_ASSETS_DIR/dist/core/config-prompts.js" "$openspec_root/dist/core/config-prompts.js"
  sync_path "$OPENSPEC_ASSETS_DIR/dist/core/templates/workflows/propose.js" "$openspec_root/dist/core/templates/workflows/propose.js"
  log_success "Applied openspec override: $openspec_root/dist/core/config-prompts.js"
  log_success "Applied openspec override: $openspec_root/dist/core/templates/workflows/propose.js"
}

main() {
  local install_incomplete="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        usage
        exit 0
        ;;
      *)
        echo "unknown argument: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done

  log_step "Forgevia Codex installer"
  validate_root "$CODEX_ROOT" ".codex"
  validate_global_command_target
  require_command cp
  require_command rm
  require_command mkdir
  require_command node
  require_command sha256sum

  require_command npm
  install_openspec

  if ! overlay_openspec_assets; then
    install_incomplete="true"
  fi

  mkdir -p "$CODEX_ROOT/skills"
  verify_superpowers_present
  log_success "Detected upstream superpowers at $CODEX_ROOT/superpowers"
  overlay_assets
  overlay_forgevia_home
  overlay_runtime_scripts
  install_global_command

  if [[ "$install_incomplete" == "true" ]]; then
    echo "Forgevia Codex install incomplete: OpenSpec overrides were not applied" >&2
    exit 1
  fi

  echo "🎉 Forgevia Codex install complete"
}

main "$@"

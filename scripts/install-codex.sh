#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_PATH="$ROOT_DIR/manifests/codex.json"
ASSETS_DIR="$ROOT_DIR/assets/codex"
OPENSPEC_ASSETS_DIR="$ROOT_DIR/assets/openspec"
CODEX_ROOT="${CODEX_HOME:-$HOME/.codex}"
SUPERPOWERS_INSTALL_URL="https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.codex/INSTALL.md"
OPENSPEC_ROOT="${OPENSPEC_ROOT:-}"
# Forgevia's openspec override files are snapshots taken against this upstream
# openspec version. Never overlay them onto a different upstream version —
# that would silently downgrade upstream behavior.
OPENSPEC_OVERRIDE_VERSION="1.5.0"

usage() {
  cat <<EOF
Install Forgevia Codex assets.

Usage:
  $(basename "$0") [--help] [--install-openspec]

Manifest:
  $MANIFEST_PATH

Behavior:
  - verifies the Codex root at $CODEX_ROOT
  - optionally installs openspec if missing
  - overlays Forgevia-managed openspec customization
  - requires upstream superpowers to already exist
  - directly overlays Forgevia-managed assets into ~/.codex
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

  backup_target_if_present "$target_path"
  copy_path "$source_path" "$target_path"
  remove_stale_backup "$target_path"
}

install_openspec_if_missing() {
  if command -v openspec >/dev/null 2>&1; then
    log_info "openspec already installed: $(command -v openspec)"
    return
  fi

  log_step "openspec not found; installing with npm"
  npm install -g @fission-ai/openspec@latest
  log_success "Installed openspec from npm"
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

overlay_forgevia_home() {
  local home_dir="$CODEX_ROOT/forgevia"
  log_step "Mirroring Forgevia source into $home_dir (baseline for global doctor/repair)"
  sync_path "$ROOT_DIR/.claude" "$home_dir/.claude"
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
  local should_install_openspec="false"
  local install_incomplete="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        usage
        exit 0
        ;;
      --install-openspec)
        should_install_openspec="true"
        shift
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
  require_command cp
  require_command rm
  require_command mkdir
  require_command node

  if [[ "$should_install_openspec" == "true" ]]; then
    require_command npm
    install_openspec_if_missing
  fi

  if command -v openspec >/dev/null 2>&1 || [[ -n "$OPENSPEC_ROOT" ]]; then
    if ! overlay_openspec_assets; then
      install_incomplete="true"
    fi
  else
    log_info "openspec not found; skipping Forgevia-managed openspec overrides"
    install_incomplete="true"
  fi

  mkdir -p "$CODEX_ROOT/skills"
  verify_superpowers_present
  log_success "Detected upstream superpowers at $CODEX_ROOT/superpowers"
  overlay_assets
  overlay_forgevia_home
  overlay_runtime_scripts

  if [[ "$install_incomplete" == "true" ]]; then
    echo "Forgevia Codex install incomplete: OpenSpec overrides were not applied" >&2
    exit 1
  fi

  echo "🎉 Forgevia Codex install complete"
}

main "$@"

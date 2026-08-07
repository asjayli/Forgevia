#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/firefly-common.sh"
MANIFEST_PATH="$ROOT_DIR/manifests/claude.json"
export FIREFLY_MANIFEST_HELPER="$ROOT_DIR/scripts/manifest-assets.mjs"
CLAUDE_ROOT="${CLAUDE_HOME:-$HOME/.claude}"
FIREFLY_BIN_DIR="${FIREFLY_BIN_DIR:-$HOME/.local/bin}"
export GLOBAL_COMMAND_STATE_PATH="$FIREFLY_BIN_DIR/.firefly-global-command.sha256"
export GLOBAL_COMMAND_SOURCE=""
export GLOBAL_COMMAND_PATH=""
CLAUDE_SUPERPOWERS_ROOT="${CLAUDE_SUPERPOWERS_ROOT:-}"
OPENSPEC_ROOT="${OPENSPEC_ROOT:-}"
# firefly's openspec override files are snapshots taken against this upstream
# openspec version. Never overlay them onto a different upstream version —
# that would silently downgrade upstream behavior.
OPENSPEC_OVERRIDE_VERSION="1.6.0"

usage() {
  cat <<EOF
Install firefly Claude assets.

Usage:
  $(basename "$0") [--help]

Manifest:
  $MANIFEST_PATH

Behavior:
  - verifies the Claude root at $CLAUDE_ROOT
  - installs OpenSpec $OPENSPEC_OVERRIDE_VERSION on every run
  - overlays firefly-managed openspec customization
  - installs firefly-managed Claude skills and commands into ~/.claude
  - exposes the firefly command at ~/.local/bin/firefly
  - overlays selected firefly-managed superpowers skill overrides into the installed Claude superpowers plugin

The managed-asset list comes from the manifest above via manifest-assets.mjs;
this script only adds behavior (version gating, checksum state, backups).
EOF
}

resolve_superpowers_root() {
  if [[ -n "$CLAUDE_SUPERPOWERS_ROOT" ]]; then
    echo "$CLAUDE_SUPERPOWERS_ROOT"
    return
  fi

  local installed_plugins_path="$CLAUDE_ROOT/plugins/installed_plugins.json"
  if [[ ! -f "$installed_plugins_path" ]]; then
    echo ""
    return
  fi

  local resolved
  resolved="$(node -e '
    const fs = require("fs");
    const path = process.argv[1];
    const data = JSON.parse(fs.readFileSync(path, "utf8"));
    const entries = data.plugins?.["superpowers@superpowers-marketplace"];
    if (Array.isArray(entries)) {
      const userEntry = entries.find((entry) => entry.scope === "user" && entry.installPath);
      const anyEntry = entries.find((entry) => entry.installPath);
      const selected = userEntry || anyEntry;
      if (selected?.installPath) process.stdout.write(selected.installPath);
    }
  ' "$installed_plugins_path")"

  if [[ -n "$resolved" ]]; then
    validate_discovered_superpowers_root "$resolved" || return 1
  fi
  echo "$resolved"
}

verify_superpowers_present() {
  local superpowers_root="$1"

  if [[ -n "$superpowers_root" && -d "$superpowers_root/skills" ]]; then
    validate_superpowers_skills_root "$superpowers_root" || exit 1
    return
  fi

  cat >&2 <<EOF
Claude superpowers plugin is not installed or could not be located.

Expected an installed plugin path from:
  $CLAUDE_ROOT/plugins/installed_plugins.json

In Claude Code, register the marketplace first:
  /plugin marketplace add obra/superpowers-marketplace

Then install the plugin from this marketplace:
  /plugin install superpowers@superpowers-marketplace

When Claude Code asks for the install scope, choose:
  user

If the plugin is already installed but stored elsewhere, set CLAUDE_SUPERPOWERS_ROOT manually.
EOF
  exit 1
}

install_openspec() {
  log_step "Installing OpenSpec $OPENSPEC_OVERRIDE_VERSION with npm"
  npm install -g @fission-ai/openspec@1.6.0
  log_success "Installed OpenSpec $OPENSPEC_OVERRIDE_VERSION from npm"
}

overlay_assets() {
  log_step "Overlaying firefly-managed assets into $CLAUDE_ROOT"

  mkdir -p "$CLAUDE_ROOT/skills" "$CLAUDE_ROOT/commands"

  local manifest_lines
  local kind source_path target_path
  manifest_lines="$(firefly_manifest_assets "skill-directory,command-directory")"
  while IFS=$'\t' read -r kind source_path target_path; do
    [[ -n "$kind" ]] || continue
    sync_path "$source_path" "$target_path"
  done <<< "$manifest_lines"

  log_success "Applied firefly-managed Claude assets"
}

overlay_runtime_scripts() {
  local runtime_dir="$CLAUDE_ROOT/firefly/bin"
  log_step "Installing firefly runtime scripts into $runtime_dir"
  mkdir -p "$runtime_dir"

  local manifest_lines
  local kind source_path target_path
  manifest_lines="$(firefly_manifest_assets "runtime-script,runtime-command")"
  while IFS=$'\t' read -r kind source_path target_path; do
    [[ -n "$kind" ]] || continue
    sync_path "$source_path" "$target_path"
  done <<< "$manifest_lines"

  log_success "Installed firefly runtime scripts (firefly/common/bootstrap/list-change-tasks/draw/doctor/validate-openspec-cn)"
}

overlay_firefly_home() {
  local home_dir="$CLAUDE_ROOT/firefly"
  log_step "Mirroring firefly source into $home_dir (baseline for global doctor/repair)"

  local manifest_lines
  local kind source_path target_path
  manifest_lines="$(firefly_manifest_assets "source-mirror")"
  while IFS=$'\t' read -r kind source_path target_path; do
    [[ -n "$kind" ]] || continue
    sync_path "$source_path" "$target_path"
  done <<< "$manifest_lines"

  log_success "Mirrored firefly source baseline"
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
    log_info "openspec $actual_version detected; firefly openspec override targets $OPENSPEC_OVERRIDE_VERSION."
    log_info "Skipping openspec override to avoid downgrading upstream. Pin openspec to $OPENSPEC_OVERRIDE_VERSION or update firefly's override."
    return 1
  fi

  local -x FIREFLY_OPENSPEC_ROOT="$openspec_root"
  local manifest_lines
  local kind source_path target_path
  manifest_lines="$(firefly_manifest_assets "openspec-override")"
  while IFS=$'\t' read -r kind source_path target_path; do
    [[ -n "$kind" ]] || continue
    sync_path "$source_path" "$target_path"
    log_success "Applied openspec override: $target_path"
  done <<< "$manifest_lines"
}

overlay_superpowers_assets() {
  local superpowers_root="$1"

  log_step "Overlaying firefly-managed superpowers overrides into $superpowers_root"

  local -x FIREFLY_SUPERPOWERS_ROOT="$superpowers_root"
  local manifest_lines
  local kind source_path target_path
  manifest_lines="$(firefly_manifest_assets "superpowers-plugin-override")"
  while IFS=$'\t' read -r kind source_path target_path; do
    [[ -n "$kind" ]] || continue
    sync_path "$source_path" "$target_path"
  done <<< "$manifest_lines"

  log_success "Applied firefly-managed Claude superpowers overrides"
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

  log_step "firefly Claude installer"
  validate_root "$CLAUDE_ROOT" ".claude"
  require_command cp
  require_command rm
  require_command mkdir
  require_command node
  require_command npm
  firefly_require_sha256
  resolve_global_command
  validate_global_command_target
  if [[ -n "$CLAUDE_SUPERPOWERS_ROOT" ]]; then
    validate_root "$CLAUDE_SUPERPOWERS_ROOT" ""
  fi

  install_openspec

  if ! overlay_openspec_assets; then
    install_incomplete="true"
  fi

  overlay_assets
  overlay_firefly_home
  overlay_runtime_scripts
  install_global_command
  local superpowers_root
  superpowers_root="$(resolve_superpowers_root)"
  verify_superpowers_present "$superpowers_root"
  log_success "Detected Claude superpowers plugin at $superpowers_root"
  overlay_superpowers_assets "$superpowers_root"

  if [[ "$install_incomplete" == "true" ]]; then
    echo "firefly Claude install incomplete: OpenSpec overrides were not applied" >&2
    exit 1
  fi

  echo "🎉 firefly Claude install complete"
}

main "$@"

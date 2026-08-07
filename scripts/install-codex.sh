#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$(dirname "${BASH_SOURCE[0]}")/firefly-common.sh"
MANIFEST_PATH="$ROOT_DIR/manifests/codex.json"
export FIREFLY_MANIFEST_HELPER="$ROOT_DIR/scripts/manifest-assets.mjs"
CODEX_ROOT="${CODEX_HOME:-$HOME/.codex}"
FIREFLY_BIN_DIR="${FIREFLY_BIN_DIR:-$HOME/.local/bin}"
export GLOBAL_COMMAND_STATE_PATH="$FIREFLY_BIN_DIR/.firefly-global-command.sha256"
export GLOBAL_COMMAND_SOURCE=""
export GLOBAL_COMMAND_PATH=""
SUPERPOWERS_INSTALL_URL="https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.codex/INSTALL.md"
OPENSPEC_ROOT="${OPENSPEC_ROOT:-}"
# firefly's openspec override files are snapshots taken against this upstream
# openspec version. Never overlay them onto a different upstream version —
# that would silently downgrade upstream behavior.
OPENSPEC_OVERRIDE_VERSION="1.6.0"

usage() {
  cat <<EOF
Install firefly Codex assets.

Usage:
  $(basename "$0") [--help]

Manifest:
  $MANIFEST_PATH

Behavior:
  - verifies the Codex root at $CODEX_ROOT
  - installs OpenSpec $OPENSPEC_OVERRIDE_VERSION on every run
  - overlays firefly-managed openspec customization
  - requires upstream superpowers to already exist
  - directly overlays firefly-managed assets into ~/.codex
  - exposes the firefly command at ~/.local/bin/firefly

The managed-asset list comes from the manifest above via manifest-assets.mjs;
this script only adds behavior (version gating, checksum state, backups).
EOF
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

install_openspec() {
  log_step "Installing OpenSpec $OPENSPEC_OVERRIDE_VERSION with npm"
  npm install -g @fission-ai/openspec@1.6.0
  log_success "Installed OpenSpec $OPENSPEC_OVERRIDE_VERSION from npm"
}

overlay_assets() {
  log_step "Overlaying firefly-managed assets into $CODEX_ROOT"

  local manifest_lines
  local kind source_path target_path
  manifest_lines="$(firefly_manifest_assets "skill-directory,command-directory,superpowers-plugin-override")"
  while IFS=$'\t' read -r kind source_path target_path; do
    [[ -n "$kind" ]] || continue
    sync_path "$source_path" "$target_path"
  done <<< "$manifest_lines"

  log_success "Applied firefly-managed Codex assets"
}

overlay_runtime_scripts() {
  local runtime_dir="$CODEX_ROOT/firefly/bin"
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
  local home_dir="$CODEX_ROOT/firefly"
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

  log_step "firefly Codex installer"
  validate_root "$CODEX_ROOT" ".codex"
  require_command cp
  require_command rm
  require_command mkdir
  require_command node
  require_command npm
  firefly_require_sha256
  resolve_global_command
  validate_global_command_target

  install_openspec

  if ! overlay_openspec_assets; then
    install_incomplete="true"
  fi

  mkdir -p "$CODEX_ROOT/skills"
  verify_superpowers_present
  log_success "Detected upstream superpowers at $CODEX_ROOT/superpowers"
  overlay_assets
  overlay_firefly_home
  overlay_runtime_scripts
  install_global_command

  if [[ "$install_incomplete" == "true" ]]; then
    echo "firefly Codex install incomplete: OpenSpec overrides were not applied" >&2
    exit 1
  fi

  echo "🎉 firefly Codex install complete"
}

main "$@"

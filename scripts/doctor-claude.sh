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
# openspec version. Repair must not overlay them onto a different upstream
# version — that would silently downgrade upstream behavior.
OPENSPEC_OVERRIDE_VERSION="1.6.0"

usage() {
  cat <<EOF
Check firefly Claude managed assets.

Usage:
  $(basename "$0") [--help] [--repair]

Manifest:
  $MANIFEST_PATH

Checks:
  - openspec config override
  - firefly-managed Claude skills and commands under ~/.claude
  - firefly runtime command dispatcher under ~/.claude/firefly/bin
  - global firefly command at ~/.local/bin/firefly
  - firefly-managed Claude superpowers overrides
  - content drift against firefly-owned copies

The managed-asset list comes from the manifest above via manifest-assets.mjs.
EOF
}

resolve_superpowers_root() {
  if [[ -n "$CLAUDE_SUPERPOWERS_ROOT" ]]; then
    validate_root "$CLAUDE_SUPERPOWERS_ROOT" ""
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

main() {
  local repair_requested="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        usage
        exit 0
        ;;
      --repair)
        repair_requested="true"
        shift
        ;;
      *)
        echo "unknown argument: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
  done

  local unhealthy=0
  local healthy=0
  local repaired=0
  local openspec_root
  local superpowers_root
  local kinds=""
  local -x FIREFLY_OPENSPEC_ROOT=""
  local -x FIREFLY_SUPERPOWERS_ROOT=""

  echo "🔎 firefly Claude doctor"
  validate_root "$CLAUDE_ROOT" ".claude"
  validate_root "$FIREFLY_BIN_DIR" ""
  require_command node
  firefly_require_sha256
  resolve_global_command
  if [[ "$repair_requested" == "true" ]]; then
    echo "🛠️ Repairing drifted or missing assets"
  fi

  openspec_root="$(resolve_openspec_root)"
  if ! is_valid_openspec_package "$openspec_root"; then
    print_status "MISS" "$openspec_root/package.json"
    log_info "OpenSpec package is missing or invalid at $openspec_root; install @fission-ai/openspec before repairing its overrides."
    unhealthy=1
  elif ! openspec_version_matches "$openspec_root"; then
    actual_version="$(read_openspec_version "$openspec_root")"
    print_status "DRIFT" "$openspec_root/package.json"
    log_info "OpenSpec $actual_version does not match override target $OPENSPEC_OVERRIDE_VERSION; its overrides remain unrepaired to avoid downgrading upstream."
    unhealthy=1
  else
    FIREFLY_OPENSPEC_ROOT="$openspec_root"
    kinds="openspec-override"
  fi

  superpowers_root="$(resolve_superpowers_root)"
  if [[ -z "$superpowers_root" ]]; then
    print_status "MISS" "$CLAUDE_ROOT/plugins/installed_plugins.json"
    log_info "Claude superpowers plugin could not be resolved. Install the plugin first or set CLAUDE_SUPERPOWERS_ROOT."
    unhealthy=1
  elif ! validate_superpowers_skills_root "$superpowers_root"; then
    print_status "DRIFT" "$superpowers_root/skills"
    log_info "Claude superpowers plugin has an unsafe or missing skills directory; skipping its override checks and repairs."
    unhealthy=1
  else
    FIREFLY_SUPERPOWERS_ROOT="$superpowers_root"
    kinds="${kinds:+$kinds,}superpowers-plugin-override"
  fi

  kinds="${kinds:+$kinds,}skill-directory,command-directory,runtime-script,runtime-command"

  local manifest_lines
  local kind source_path target_path
  manifest_lines="$(firefly_manifest_assets "$kinds")"
  while IFS=$'\t' read -r kind source_path target_path; do
    [[ -n "$kind" ]] || continue

    if compare_path "$source_path" "$target_path"; then
      ((healthy+=1))
      continue
    fi

    if [[ "$repair_requested" == "true" ]]; then
      repair_path "$source_path" "$target_path"
      ((repaired+=1))
      continue
    fi

    unhealthy=1
  done <<< "$manifest_lines"

  if compare_global_command; then
    ((healthy+=1))
  elif [[ "$repair_requested" == "true" ]] && repair_global_command; then
    ((repaired+=1))
  else
    unhealthy=1
  fi

  echo "📋 Summary"
  echo "💚 Healthy assets: $healthy"
  echo "🛠️ Repaired assets: $repaired"
  if [[ "$unhealthy" -ne 0 ]]; then
    echo "💥 Unhealthy assets detected"
  else
    echo "✨ No drift detected"
  fi

  if [[ "$unhealthy" -ne 0 ]]; then
    if [[ "$repair_requested" == "true" ]]; then
      echo "firefly Claude doctor repair incomplete; unresolved managed assets remain" >&2
    else
      echo "firefly Claude doctor found missing or drifted managed assets" >&2
    fi
    exit 1
  fi

  if [[ "$repair_requested" == "true" ]]; then
    echo "firefly Claude doctor repair complete"
    exit 0
  fi

  echo "firefly Claude doctor passed"
}

main "$@"

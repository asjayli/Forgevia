#!/usr/bin/env bash

# Forgevia global command shim
set -euo pipefail

CODEX_RUNTIME="${CODEX_HOME:-$HOME/.codex}/forgevia/bin/forgevia"
CLAUDE_RUNTIME="${CLAUDE_HOME:-$HOME/.claude}/forgevia/bin/forgevia"

runtime_exists() {
  [[ -x "$1" ]]
}

run_global_doctor() {
  local command_name="$1"
  shift
  local status=0
  local found="false"

  if runtime_exists "$CODEX_RUNTIME"; then
    "$CODEX_RUNTIME" "$command_name" "$@" || status=$?
    found="true"
  fi
  if runtime_exists "$CLAUDE_RUNTIME"; then
    "$CLAUDE_RUNTIME" "$command_name" "$@" || status=$?
    found="true"
  fi

  if [[ "$found" == "false" ]]; then
    echo "Forgevia is not installed for Codex or Claude" >&2
    return 1
  fi
  return "$status"
}

command_name="${1:-help}"
case "$command_name" in
  doctor|repair)
    shift
    run_global_doctor "$command_name" "$@"
    ;;
  *)
    if runtime_exists "$CODEX_RUNTIME"; then
      exec "$CODEX_RUNTIME" "$@"
    fi
    if runtime_exists "$CLAUDE_RUNTIME"; then
      exec "$CLAUDE_RUNTIME" "$@"
    fi
    echo "Forgevia is not installed for Codex or Claude" >&2
    exit 1
    ;;
esac

#!/usr/bin/env bash

set -euo pipefail

# Resolve the global command symlink so helper paths remain runtime-relative.
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SCRIPT_SOURCE" ]]; do
  SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"
  SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
  [[ "$SCRIPT_SOURCE" == /* ]] || SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
done
SCRIPT_DIR="$(cd -P "$(dirname "$SCRIPT_SOURCE")" && pwd)"

usage() {
  cat <<'EOF'
Usage: firefly <command> [arguments]

Commands:
  validate [--root <project-root>]  Run Chinese-compatible OpenSpec strict validation
  init [arguments]                  Initialize OpenSpec project files
  tasks [arguments]                 List active change tasks
  draw [arguments]                  Generate a firefly design diagram
  doctor                            Check firefly managed assets
  repair                            Repair firefly managed assets
EOF
}

run_doctor() {
  if [[ -x "$SCRIPT_DIR/doctor-codex.sh" ]]; then
    exec "$SCRIPT_DIR/doctor-codex.sh" "$@"
  fi
  if [[ -x "$SCRIPT_DIR/doctor-claude.sh" ]]; then
    exec "$SCRIPT_DIR/doctor-claude.sh" "$@"
  fi
  echo "firefly doctor runtime helper is missing" >&2
  exit 1
}

command_name="${1:-help}"
case "$command_name" in
  validate)
    shift
    exec node "$SCRIPT_DIR/validate-openspec-cn.mjs" "$@"
    ;;
  init)
    shift
    exec "$SCRIPT_DIR/bootstrap-project.sh" "$@"
    ;;
  tasks)
    shift
    exec "$SCRIPT_DIR/list-change-tasks.sh" "$@"
    ;;
  draw)
    shift
    exec "$SCRIPT_DIR/firefly-draw.sh" "$@"
    ;;
  doctor)
    shift
    run_doctor "$@"
    ;;
  repair)
    shift
    run_doctor --repair "$@"
    ;;
  help|--help|-h)
    usage
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac

#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<EOF
List unfinished tasks for active OpenSpec changes.

Usage:
  $(basename "$0") [--help] [project_dir]

Behavior:
  - scans openspec/changes under the target project
  - ignores archived changes
  - sorts active changes by change creation time ascending
  - prints only unfinished checklist items from tasks.md
EOF
}

project_dir="${1:-.}"

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

# Cross-platform mtime: GNU stat uses -c '%Y', BSD/macOS stat uses -f '%m'.
# Probe once with a stable target instead of sniffing `uname`.
if stat -c '%Y' / >/dev/null 2>&1; then
  stat_mtime() { stat -c '%Y' "$1"; }
else
  stat_mtime() { stat -f '%m' "$1"; }
fi

# Prefer ripgrep when available; fall back to grep so the command still works
# on machines without rg instead of silently reporting "no unfinished tasks".
list_unfinished_tasks() {
  local tasks_file="$1"
  if command -v rg >/dev/null 2>&1; then
    rg '^- \[ \] ' "$tasks_file" 2>/dev/null || true
  else
    grep -E '^- \[ \] ' "$tasks_file" 2>/dev/null || true
  fi
}

changes_root="$project_dir/openspec/changes"

if [[ ! -d "$changes_root" ]]; then
  echo "openspec/changes not found under $project_dir" >&2
  exit 1
fi

echo "📋 Active change tasks"

tmp_list="$(mktemp)"
trap 'rm -f "$tmp_list"' EXIT

find "$changes_root" -mindepth 1 -maxdepth 1 -type d ! -name archive | while read -r change_dir; do
  if [[ ! -f "$change_dir/.openspec.yaml" ]]; then
    continue
  fi

  timestamp="$(stat_mtime "$change_dir/.openspec.yaml")"
  printf '%s\t%s\n' "$timestamp" "$change_dir" >> "$tmp_list"
done

printed=0

while IFS=$'\t' read -r _timestamp change_dir; do
  tasks_file="$change_dir/tasks.md"
  if [[ ! -f "$tasks_file" ]]; then
    continue
  fi

  unfinished="$(list_unfinished_tasks "$tasks_file")"
  if [[ -z "$unfinished" ]]; then
    continue
  fi

  change_name="$(basename "$change_dir")"
  echo
  echo "🗂️ $change_name"
  echo "📄 $tasks_file"
  printf '%s\n' "$unfinished"
  printed=1
done < <(sort -n "$tmp_list")

if [[ "$printed" -eq 0 ]]; then
  echo
  echo "✨ No unfinished tasks in active changes"
fi

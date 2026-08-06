#!/usr/bin/env bash

set -euo pipefail

DEFAULT_TOOLS="codex,claude"

usage() {
  cat <<EOF
Bootstrap OpenSpec in the current project.

Usage:
  $(basename "$0") [--help] [--tools codex|claude|codex,claude] [project_dir]

Behavior:
  - checks whether OpenSpec is already initialized in the target directory
  - runs openspec init only when initialization is missing
  - rejects an explicitly empty project_dir
  - rejects project_dir values containing newline characters
  - rejects symbolic links in project_dir path components before any write
  - preflight checks openspec and selected platform output roots for symlinks
  - does not modify project source files beyond OpenSpec's own initialization
EOF
}

normalize_tools() {
  local tools="$1"

  case "$tools" in
    codex|claude|codex,claude)
      echo "$tools"
      ;;
    claude,codex)
      echo "codex,claude"
      ;;
    *)
      echo "unsupported --tools value: $tools" >&2
      echo "expected one of: codex, claude, codex,claude" >&2
      exit 1
      ;;
  esac
}

tool_selected() {
  local tools="$1"
  local tool="$2"

  [[ ",$tools," == *",$tool,"* ]]
}

# Resolve project_dir to an absolute path, reject newlines, and refuse to
# traverse any existing component that is a symbolic link. Newlines are rejected
# before the line-oriented read below so Bash 3.2 cannot mis-split the path.
assert_project_path_safe() {
  local path="$1"
  local current="/"
  local part
  local -a path_parts

  if [[ "$path" != /* ]]; then
    path="$PWD/$path"
  fi

  if [[ "$path" == *$'\n'* ]]; then
    echo "project_dir must not contain newline characters" >&2
    return 1
  fi

  IFS='/' read -r -a path_parts <<< "$path"
  for part in "${path_parts[@]}"; do
    case "$part" in
      ""|.)
        continue
        ;;
      ..)
        if [[ "$current" != "/" ]]; then
          current="${current%/*}"
          [[ -n "$current" ]] || current="/"
        fi
        continue
        ;;
    esac

    if [[ "$current" == "/" ]]; then
      current="/$part"
    else
      current="$current/$part"
    fi
    if [[ -L "$current" ]]; then
      echo "refusing symlinked project path component: $current" >&2
      return 1
    fi
  done
}

# Refuse a single symlinked initializer output path (e.g. project_dir/openspec).
assert_initializer_root_safe() {
  local path="$1"

  if [[ -L "$path" ]]; then
    echo "refusing symlinked initializer output: $path" >&2
    return 1
  fi
}

# Refuse any pre-existing symbolic link beneath an initializer output root
# (.codex/.claude). The find scan must succeed; on failure the tree is unsafe.
assert_initializer_tree_safe() {
  local root="$1"
  local scan_file
  local link

  assert_initializer_root_safe "$root"
  if [[ ! -d "$root" ]]; then
    return 0
  fi

  scan_file="$(mktemp "${TMPDIR:-/tmp}/forgevia-bootstrap-scan.XXXXXX")"
  if ! find "$root" -type l -print0 > "$scan_file"; then
    rm -f -- "$scan_file"
    echo "unable to scan initializer output safely: $root" >&2
    return 1
  fi
  if IFS= read -r -d '' link < "$scan_file"; then
    rm -f -- "$scan_file"
    echo "refusing symlinked initializer output: $link" >&2
    return 1
  fi
  rm -f -- "$scan_file"
}

# Before openspec init writes anything, confirm neither openspec itself nor the
# selected platform output roots already contain a symlink the initializer could
# follow out of project_dir.
preflight_initializer_outputs() {
  local tools="$1"
  local project_dir="$2"

  if tool_selected "$tools" "codex"; then
    assert_initializer_tree_safe "$project_dir/.codex"
  fi
  if tool_selected "$tools" "claude"; then
    assert_initializer_tree_safe "$project_dir/.claude"
  fi
}

main() {
  local tools="$DEFAULT_TOOLS"
  local project_dir="."
  local project_dir_set="false"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --help|-h)
        usage
        exit 0
        ;;
      --tools)
        if [[ $# -lt 2 ]]; then
          echo "--tools requires a value" >&2
          exit 1
        fi
        tools="$(normalize_tools "$2")"
        shift 2
        ;;
      --*)
        echo "unsupported option: $1" >&2
        exit 1
        ;;
      *)
        if [[ "$project_dir_set" == "true" ]]; then
          echo "only one project_dir may be provided" >&2
          exit 1
        fi
        if [[ -z "$1" ]]; then
          echo "project_dir must not be empty" >&2
          exit 1
        fi
        if [[ "$1" == *$'\n'* ]]; then
          echo "project_dir must not contain newline characters" >&2
          exit 1
        fi
        project_dir="$1"
        project_dir_set="true"
        shift
        ;;
    esac
  done

  if ! command -v openspec >/dev/null 2>&1; then
    echo "openspec is not installed or not on PATH" >&2
    exit 1
  fi

  assert_project_path_safe "$project_dir"
  assert_initializer_root_safe "$project_dir/openspec"

  if [[ -f "$project_dir/openspec/config.yaml" ]]; then
    echo "OpenSpec already initialized in $project_dir"
    exit 0
  fi

  # Fresh initialization: scan openspec internals too, so a pre-existing symlink
  # beneath openspec/ cannot redirect the initializer's writes out of project_dir.
  assert_initializer_tree_safe "$project_dir/openspec"
  preflight_initializer_outputs "$tools" "$project_dir"

  echo "Running openspec init --tools $tools $project_dir"
  openspec init --tools "$tools" "$project_dir"
  echo "Project bootstrap complete"
}

main "$@"

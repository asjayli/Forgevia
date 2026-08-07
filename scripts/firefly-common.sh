#!/usr/bin/env bash
# firefly shared shell helpers.
#
# Sourced by the platform install and doctor scripts to avoid duplicating
# platform-sensitive logic. The canonical example is SHA-256 computation:
# Linux defaults to `sha256sum` while macOS ships `shasum -a 256` instead.
# Centralizing the provider selection here keeps the four install/doctor
# scripts in lockstep and lets runtime copies under
# ~/.{claude,codex}/firefly/bin/ load the same helpers from an adjacent path.
#
# This file only DEFINES functions. It must not execute work or set shell
# options when sourced, so callers retain control of `set -euo pipefail`
# and process exit behavior.
#
# Globals the sourcing script must provide:
#   ROOT_DIR                  repo root (or mirrored firefly home at runtime)
#   MANIFEST_PATH             platform manifest consumed via manifest-assets.mjs
#   FIREFLY_MANIFEST_HELPER   path to scripts/manifest-assets.mjs
#   FIREFLY_BIN_DIR           install location of the global firefly command
#   GLOBAL_COMMAND_STATE_PATH checksum state file for the global command
#   OPENSPEC_OVERRIDE_VERSION upstream openspec version the overrides target
# Globals set by resolve_global_command and used by the global-command helpers:
#   GLOBAL_COMMAND_SOURCE     repo path of scripts/firefly-global.sh
#   GLOBAL_COMMAND_PATH       install path of the global firefly command

# Print the SHA-256 digest of a file path to stdout.
# Prefers `sha256sum` (Linux) and falls back to `shasum -a 256` (macOS).
# Fails loudly when neither provider is available; firefly never silently
# downgrades to a weaker hash.
firefly_sha256_file() {
  local path="$1"
  local line
  if command -v sha256sum >/dev/null 2>&1; then
    line="$(sha256sum "$path")"
  elif command -v shasum >/dev/null 2>&1; then
    line="$(shasum -a 256 "$path")"
  else
    echo "missing required command: sha256sum or shasum" >&2
    return 1
  fi
  # Both providers print "<digest>  <path>". Keep only the digest field with a
  # bash parameter expansion so the helper works in minimal-PATH sandboxes
  # (for example preflight shells that have not yet brought awk into view).
  printf '%s\n' "${line%% *}"
}

# Pre-flight check used by install/doctor entry points: refuse to run when no
# SHA-256 provider is available. Emits the same message as
# firefly_sha256_file so a missing provider stays attributable whether it
# surfaces during preflight or during checksum computation.
firefly_require_sha256() {
  if ! command -v sha256sum >/dev/null 2>&1 && ! command -v shasum >/dev/null 2>&1; then
    echo "missing required command: sha256sum or shasum" >&2
    exit 1
  fi
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

# Emit kind<TAB>source<TAB>target lines for the comma-separated manifest kinds
# in $1. Placeholder roots are forwarded from the environment/shell scope:
# callers set FIREFLY_OPENSPEC_ROOT / FIREFLY_SUPERPOWERS_ROOT when they
# request the corresponding kinds.
firefly_manifest_assets() {
  local kinds="$1"
  CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}" \
  CODEX_HOME="${CODEX_HOME:-$HOME/.codex}" \
  FIREFLY_BIN_DIR="${FIREFLY_BIN_DIR:-$HOME/.local/bin}" \
  FIREFLY_OPENSPEC_ROOT="${FIREFLY_OPENSPEC_ROOT:-}" \
  FIREFLY_SUPERPOWERS_ROOT="${FIREFLY_SUPERPOWERS_ROOT:-}" \
    node "$FIREFLY_MANIFEST_HELPER" "$MANIFEST_PATH" --kinds "$kinds"
}

# Populate GLOBAL_COMMAND_SOURCE and GLOBAL_COMMAND_PATH from the manifest's
# global-command entry. Runs in the current shell on purpose.
resolve_global_command() {
  local manifest_lines
  local kind source_path target_path
  manifest_lines="$(firefly_manifest_assets "global-command")"
  while IFS=$'\t' read -r kind source_path target_path; do
    [[ -n "$kind" && -n "$target_path" ]] || continue
    GLOBAL_COMMAND_SOURCE="$source_path"
    GLOBAL_COMMAND_PATH="$target_path"
    return 0
  done <<< "$manifest_lines"
  echo "manifest has no global-command entry: $MANIFEST_PATH" >&2
  return 1
}

# Resolve a managed target through user-managed symlinks: the final symlink is
# preserved while its resolved target gets replaced.
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
  local backup_path="${target_path}.firefly.bak"

  if [[ ! -e "$target_path" ]]; then
    return
  fi

  rm -rf "$backup_path"
  cp -R "$target_path" "$backup_path"
  log_backup "Backed up $target_path -> $backup_path"
}

remove_stale_backup() {
  local target_path="$1"
  local backup_path="${target_path}.firefly.bak"

  rm -rf "$backup_path"
}

copy_path() {
  local source_path="$1"
  local target_path="$2"

  mkdir -p "$(dirname "$target_path")"
  rm -rf "$target_path"
  cp -R "$source_path" "$target_path"
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

repair_path() {
  local source_path="$1"
  local target_path="$2"
  local resolved_target

  resolved_target="$(resolve_managed_target "$target_path")"
  backup_target_if_present "$resolved_target"
  copy_path "$source_path" "$resolved_target"
  remove_stale_backup "$resolved_target"
  log_success "Repaired $target_path"
}

print_status() {
  local status="$1"
  local path="$2"

  case "$status" in
    OK)
      echo "✅ OK    $path"
      ;;
    MISS)
      echo "⚠️  MISS  $path"
      ;;
    DRIFT)
      echo "❌ DRIFT $path"
      ;;
  esac
}

executable_permissions_match() {
  local source_path="$1"
  local target_path="$2"
  local source_file
  local target_file

  if [[ -f "$source_path" ]]; then
    [[ ! -x "$source_path" || -x "$target_path" ]]
    return
  fi

  while IFS= read -r source_file; do
    [[ -x "$source_file" ]] || continue
    target_file="$target_path/${source_file#"$source_path"/}"
    [[ -x "$target_file" ]] || return 1
  done < <(find "$source_path" -type f)
}

compare_path() {
  local source_path="$1"
  local target_path="$2"

  if [[ ! -e "$target_path" ]]; then
    print_status "MISS" "$target_path"
    return 1
  fi

  if ! executable_permissions_match "$source_path" "$target_path"; then
    print_status "DRIFT" "$target_path"
    return 1
  fi

  if [[ -d "$source_path" ]]; then
    if diff -qr "$source_path" "$target_path" >/dev/null 2>&1; then
      print_status "OK" "$target_path"
      return 0
    fi

    print_status "DRIFT" "$target_path"
    return 1
  fi

  if cmp -s "$source_path" "$target_path"; then
    print_status "OK" "$target_path"
    return 0
  fi

  print_status "DRIFT" "$target_path"
  return 1
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

is_managed_global_command() {
  local command_path="$1"

  [[ -f "$command_path" && ! -L "$command_path" ]] || return 1
  cmp -s "$GLOBAL_COMMAND_SOURCE" "$command_path" && return 0
  [[ -f "$GLOBAL_COMMAND_STATE_PATH" ]] && [[ "$(<"$GLOBAL_COMMAND_STATE_PATH")" == "$(command_checksum "$command_path")" ]]
}

command_checksum() {
  firefly_sha256_file "$1"
}

write_global_command_state() {
  command_checksum "$GLOBAL_COMMAND_PATH" > "$GLOBAL_COMMAND_STATE_PATH"
}

is_legacy_runtime_link() {
  local command_path="$1"
  local target_path

  [[ -L "$command_path" ]] || return 1
  target_path="$(readlink "$command_path")"
  [[ "$target_path" == "${CLAUDE_HOME:-$HOME/.claude}/firefly/bin/firefly" || "$target_path" == "${CODEX_HOME:-$HOME/.codex}/firefly/bin/firefly" ]]
}

validate_global_command_target() {
  local command_path="$GLOBAL_COMMAND_PATH"

  validate_root "$FIREFLY_BIN_DIR" ""
  if [[ ( -e "$command_path" || -L "$command_path" ) ]] && ! is_managed_global_command "$command_path" && ! is_legacy_runtime_link "$command_path"; then
    echo "refusing to replace existing command: $command_path" >&2
    exit 1
  fi
}

install_global_command() {
  local command_path="$GLOBAL_COMMAND_PATH"

  log_step "Installing firefly command at $command_path"
  mkdir -p "$FIREFLY_BIN_DIR"
  if [[ -e "$command_path" || -L "$command_path" ]]; then
    rm -f "$command_path"
  fi
  cp "$GLOBAL_COMMAND_SOURCE" "$command_path"
  write_global_command_state
  log_success "Installed firefly command: $command_path"
}

compare_global_command() {
  local command_path="$GLOBAL_COMMAND_PATH"

  if [[ ! -e "$command_path" && ! -L "$command_path" ]]; then
    print_status "MISS" "$command_path"
    return 1
  fi
  if [[ -L "$command_path" ]]; then
    print_status "DRIFT" "$command_path"
    return 1
  fi
  compare_path "$GLOBAL_COMMAND_SOURCE" "$command_path"
}

repair_global_command() {
  local command_path="$GLOBAL_COMMAND_PATH"

  if is_legacy_runtime_link "$command_path"; then
    rm -f "$command_path"
    mkdir -p "$FIREFLY_BIN_DIR"
    cp "$GLOBAL_COMMAND_SOURCE" "$command_path"
    write_global_command_state
    log_success "Repaired $command_path"
    return 0
  fi
  if [[ ( -e "$command_path" || -L "$command_path" ) ]] && ! is_managed_global_command "$command_path"; then
    log_info "Cannot repair global command without replacing an existing command: $command_path"
    return 1
  fi
  repair_path "$GLOBAL_COMMAND_SOURCE" "$command_path"
  write_global_command_state
}

validate_discovered_superpowers_root() {
  local root_path="$1"
  local claude_root_real
  local plugin_root_real

  validate_root "$root_path" ""
  if [[ ! -d "$root_path" ]]; then
    echo "Claude plugin install path does not exist: $root_path" >&2
    return 1
  fi

  claude_root_real="$(cd "$CLAUDE_ROOT" && pwd -P)"
  plugin_root_real="$(cd "$root_path" && pwd -P)"
  if [[ "$plugin_root_real" != "$claude_root_real/plugins" && "$plugin_root_real" != "$claude_root_real/plugins/"* ]]; then
    echo "Claude plugin install path must be inside $CLAUDE_ROOT/plugins: $root_path" >&2
    return 1
  fi

  validate_superpowers_skills_root "$root_path"
}

validate_superpowers_skills_root() {
  local root_path="$1"
  local skills_path="$root_path/skills"
  local root_real
  local skills_real

  if [[ ! -d "$skills_path" ]]; then
    echo "Claude plugin skills directory is missing: $skills_path" >&2
    return 1
  fi
  if [[ -L "$skills_path" || -n "$(find "$skills_path" -type l -print -quit)" ]]; then
    echo "Claude plugin skills directory must not contain symlinks: $skills_path" >&2
    return 1
  fi

  root_real="$(cd "$root_path" && pwd -P)"
  skills_real="$(cd "$skills_path" && pwd -P)"
  if [[ "$skills_real" != "$root_real/skills" && "$skills_real" != "$root_real/skills/"* ]]; then
    echo "Claude plugin skills directory escapes plugin root: $skills_path" >&2
    return 1
  fi
}

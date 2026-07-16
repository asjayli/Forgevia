#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_PATH="$ROOT_DIR/manifests/claude.json"
ASSETS_DIR="$ROOT_DIR/assets/claude"
CLAUDE_SUPERPOWERS_ASSETS_DIR="$ROOT_DIR/assets/claude/superpowers"
OPENSPEC_ASSETS_DIR="$ROOT_DIR/assets/openspec"
CLAUDE_ROOT="${CLAUDE_HOME:-$HOME/.claude}"
CLAUDE_SUPERPOWERS_ROOT="${CLAUDE_SUPERPOWERS_ROOT:-}"
OPENSPEC_ROOT="${OPENSPEC_ROOT:-}"
# Forgevia's openspec override files are snapshots taken against this upstream
# openspec version. Repair must not overlay them onto a different upstream
# version — that would silently downgrade upstream behavior.
OPENSPEC_OVERRIDE_VERSION="1.6.0"

usage() {
  cat <<EOF
Check Forgevia Claude managed assets.

Usage:
  $(basename "$0") [--help] [--repair]

Manifest:
  $MANIFEST_PATH

Checks:
  - openspec config override
  - Forgevia-managed Claude skills and commands under ~/.claude
  - Forgevia runtime command dispatcher under ~/.claude/forgevia/bin
  - Forgevia-managed Claude superpowers overrides
  - content drift against Forgevia-owned copies
EOF
}

log_info() {
  echo "ℹ️  $1"
}

log_success() {
  echo "✅ $1"
}

log_backup() {
  echo "💾 $1"
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

resolve_managed_target() {
  local target_path="$1"
  local resolved_path="$target_path"
  local link_target
  local depth=0

  # Preserve a user-managed final symlink while repairing its resolved target.
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

remove_stale_backup() {
  local target_path="$1"
  local backup_path="${target_path}.forgevia.bak"

  rm -rf "$backup_path"
}

repair_path() {
  local source_path="$1"
  local target_path="$2"
  local resolved_target

  resolved_target="$(resolve_managed_target "$target_path")"
  mkdir -p "$(dirname "$resolved_target")"
  backup_target_if_present "$resolved_target"
  rm -rf "$resolved_target"
  cp -R "$source_path" "$resolved_target"
  remove_stale_backup "$resolved_target"
  log_success "Repaired $target_path"
}

managed_skill_pairs() {
  local source_path
  local target_name

  for source_path in "$ASSETS_DIR/skills"/*; do
    [[ -d "$source_path" ]] || continue
    target_name="$(basename "$source_path")"
    echo "$source_path::$CLAUDE_ROOT/skills/$target_name"
  done | sort
}

managed_command_pairs() {
  if [[ ! -d "$ASSETS_DIR/commands" ]]; then
    return
  fi

  local source_path
  local target_name

  for source_path in "$ASSETS_DIR/commands"/*; do
    [[ -d "$source_path" ]] || continue
    target_name="$(basename "$source_path")"
    echo "$source_path::$CLAUDE_ROOT/commands/$target_name"
  done | sort
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
  local managed_pairs=()

  echo "🔎 Forgevia Claude doctor"
  validate_root "$CLAUDE_ROOT" ".claude"
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
    managed_pairs+=(
      "$OPENSPEC_ASSETS_DIR/dist/core/config-prompts.js::$openspec_root/dist/core/config-prompts.js"
      "$OPENSPEC_ASSETS_DIR/dist/core/templates/workflows/propose.js::$openspec_root/dist/core/templates/workflows/propose.js"
    )
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
    managed_pairs+=(
      "$CLAUDE_SUPERPOWERS_ASSETS_DIR/skills/brainstorming/SKILL.md::$superpowers_root/skills/brainstorming/SKILL.md"
      "$CLAUDE_SUPERPOWERS_ASSETS_DIR/skills/writing-plans/SKILL.md::$superpowers_root/skills/writing-plans/SKILL.md"
      "$CLAUDE_SUPERPOWERS_ASSETS_DIR/skills/test-driven-development/SKILL.md::$superpowers_root/skills/test-driven-development/SKILL.md"
      "$CLAUDE_SUPERPOWERS_ASSETS_DIR/skills/executing-plans/SKILL.md::$superpowers_root/skills/executing-plans/SKILL.md"
      "$CLAUDE_SUPERPOWERS_ASSETS_DIR/skills/subagent-driven-development::$superpowers_root/skills/subagent-driven-development"
      "$CLAUDE_SUPERPOWERS_ASSETS_DIR/skills/requesting-code-review::$superpowers_root/skills/requesting-code-review"
    )
  fi

  while IFS= read -r pair; do
    managed_pairs+=("$pair")
  done < <(managed_skill_pairs)

  while IFS= read -r pair; do
    managed_pairs+=("$pair")
  done < <(managed_command_pairs)

  managed_pairs+=(
    "$ROOT_DIR/scripts/bootstrap-project.sh::$CLAUDE_ROOT/forgevia/bin/bootstrap-project.sh"
    "$ROOT_DIR/scripts/list-change-tasks.sh::$CLAUDE_ROOT/forgevia/bin/list-change-tasks.sh"
    "$ROOT_DIR/scripts/forgevia-draw.sh::$CLAUDE_ROOT/forgevia/bin/forgevia-draw.sh"
    "$ROOT_DIR/scripts/doctor-claude.sh::$CLAUDE_ROOT/forgevia/bin/doctor-claude.sh"
    "$ROOT_DIR/scripts/validate-openspec-cn.mjs::$CLAUDE_ROOT/forgevia/bin/validate-openspec-cn.mjs"
    "$ROOT_DIR/scripts/forgevia.sh::$CLAUDE_ROOT/forgevia/bin/forgevia"
  )

  for pair in "${managed_pairs[@]}"
  do
    local source_path="${pair%%::*}"
    local target_path="${pair#*::}"

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
  done

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
      echo "Forgevia Claude doctor repair incomplete; unresolved managed assets remain" >&2
    else
      echo "Forgevia Claude doctor found missing or drifted managed assets" >&2
    fi
    exit 1
  fi

  if [[ "$repair_requested" == "true" ]]; then
    echo "Forgevia Claude doctor repair complete"
    exit 0
  fi

  echo "Forgevia Claude doctor passed"
}

main "$@"

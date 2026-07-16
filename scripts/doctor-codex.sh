#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MANIFEST_PATH="$ROOT_DIR/manifests/codex.json"
CODEX_ROOT="${CODEX_HOME:-$HOME/.codex}"
ASSETS_DIR="$ROOT_DIR/assets/codex"
OPENSPEC_ASSETS_DIR="$ROOT_DIR/assets/openspec"
OPENSPEC_ROOT="${OPENSPEC_ROOT:-}"
# Forgevia's openspec override files are snapshots taken against this upstream
# openspec version. Repair must not overlay them onto a different upstream
# version — that would silently downgrade upstream behavior.
OPENSPEC_OVERRIDE_VERSION="1.6.0"

usage() {
  cat <<EOF
Check Forgevia Codex managed assets.

Usage:
  $(basename "$0") [--help] [--repair]

Manifest:
  $MANIFEST_PATH

Checks:
  - openspec config override
  - Forgevia and OpenSpec support skills under ~/.codex/skills
  - Forgevia runtime command dispatcher under ~/.codex/forgevia/bin
  - mermaid-diagram-specialist and playwright-interactive helper skills
  - Forgevia-managed superpowers overrides
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
  local openspec_compatible="false"

  echo "🔎 Forgevia Codex doctor"
  validate_root "$CODEX_ROOT" ".codex"
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
    openspec_compatible="true"
  fi

  for pair in \
    "$OPENSPEC_ASSETS_DIR/dist/core/config-prompts.js::$openspec_root/dist/core/config-prompts.js" \
    "$OPENSPEC_ASSETS_DIR/dist/core/templates/workflows/propose.js::$openspec_root/dist/core/templates/workflows/propose.js" \
    "$ASSETS_DIR/skills/openspec-propose::$CODEX_ROOT/skills/openspec-propose" \
    "$ASSETS_DIR/skills/openspec-apply-change::$CODEX_ROOT/skills/openspec-apply-change" \
    "$ASSETS_DIR/skills/openspec-archive-change::$CODEX_ROOT/skills/openspec-archive-change" \
    "$ASSETS_DIR/skills/openspec-explore::$CODEX_ROOT/skills/openspec-explore" \
    "$ASSETS_DIR/skills/openspec-sync-specs::$CODEX_ROOT/skills/openspec-sync-specs" \
    "$ASSETS_DIR/skills/forgevia::$CODEX_ROOT/skills/forgevia" \
    "$ASSETS_DIR/skills/forgevia-init::$CODEX_ROOT/skills/forgevia-init" \
    "$ASSETS_DIR/skills/forgevia-doctor::$CODEX_ROOT/skills/forgevia-doctor" \
    "$ASSETS_DIR/skills/forgevia-repair::$CODEX_ROOT/skills/forgevia-repair" \
    "$ASSETS_DIR/skills/forgevia-implement::$CODEX_ROOT/skills/forgevia-implement" \
    "$ASSETS_DIR/skills/forgevia-archive::$CODEX_ROOT/skills/forgevia-archive" \
    "$ASSETS_DIR/skills/forgevia-tasks::$CODEX_ROOT/skills/forgevia-tasks" \
    "$ASSETS_DIR/skills/forgevia-think::$CODEX_ROOT/skills/forgevia-think" \
    "$ASSETS_DIR/skills/forgevia-propose::$CODEX_ROOT/skills/forgevia-propose" \
    "$ASSETS_DIR/skills/forgevia-review::$CODEX_ROOT/skills/forgevia-review" \
    "$ASSETS_DIR/skills/forgevia-verify-web::$CODEX_ROOT/skills/forgevia-verify-web" \
    "$ASSETS_DIR/skills/forgevia-draw::$CODEX_ROOT/skills/forgevia-draw" \
    "$ASSETS_DIR/skills/mermaid-diagram-specialist::$CODEX_ROOT/skills/mermaid-diagram-specialist" \
    "$ASSETS_DIR/skills/playwright-interactive::$CODEX_ROOT/skills/playwright-interactive" \
    "$ASSETS_DIR/superpowers/skills/brainstorming/SKILL.md::$CODEX_ROOT/superpowers/skills/brainstorming/SKILL.md" \
    "$ASSETS_DIR/superpowers/skills/writing-plans/SKILL.md::$CODEX_ROOT/superpowers/skills/writing-plans/SKILL.md" \
    "$ASSETS_DIR/superpowers/skills/executing-plans/SKILL.md::$CODEX_ROOT/superpowers/skills/executing-plans/SKILL.md" \
    "$ASSETS_DIR/superpowers/skills/subagent-driven-development::$CODEX_ROOT/superpowers/skills/subagent-driven-development" \
    "$ASSETS_DIR/superpowers/skills/requesting-code-review::$CODEX_ROOT/superpowers/skills/requesting-code-review" \
    "$ASSETS_DIR/superpowers/skills/test-driven-development/SKILL.md::$CODEX_ROOT/superpowers/skills/test-driven-development/SKILL.md" \
    "$ROOT_DIR/scripts/bootstrap-project.sh::$CODEX_ROOT/forgevia/bin/bootstrap-project.sh" \
    "$ROOT_DIR/scripts/list-change-tasks.sh::$CODEX_ROOT/forgevia/bin/list-change-tasks.sh" \
    "$ROOT_DIR/scripts/forgevia-draw.sh::$CODEX_ROOT/forgevia/bin/forgevia-draw.sh" \
    "$ROOT_DIR/scripts/doctor-codex.sh::$CODEX_ROOT/forgevia/bin/doctor-codex.sh" \
    "$ROOT_DIR/scripts/validate-openspec-cn.mjs::$CODEX_ROOT/forgevia/bin/validate-openspec-cn.mjs" \
    "$ROOT_DIR/scripts/forgevia.sh::$CODEX_ROOT/forgevia/bin/forgevia"
  do
    local source_path="${pair%%::*}"
    local target_path="${pair#*::}"

    if [[ "$target_path" == "$openspec_root"/* && "$openspec_compatible" != "true" ]]; then
      continue
    fi

    # If upstream superpowers is not installed, its override targets cannot
    # exist. Warn once and skip them instead of flooding MISS rows, mirroring
    # the Claude doctor's handling of a missing superpowers plugin.
    if [[ "$target_path" == *"/superpowers/"* ]] && [[ ! -d "$CODEX_ROOT/superpowers" ]]; then
      if [[ -z "${superpowers_warned:-}" ]]; then
        print_status "MISS" "$CODEX_ROOT/superpowers"
        log_info "Codex superpowers not found. Install upstream superpowers first; skipping its override checks."
        superpowers_warned=1
        unhealthy=1
      fi
      continue
    fi

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
      echo "Forgevia Codex doctor repair incomplete; unresolved managed assets remain" >&2
    else
      echo "Forgevia Codex doctor found missing or drifted managed assets" >&2
    fi
    exit 1
  fi

  if [[ "$repair_requested" == "true" ]]; then
    echo "Forgevia Codex doctor repair complete"
    exit 0
  fi

  echo "Forgevia Codex doctor passed"
}

main "$@"

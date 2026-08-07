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

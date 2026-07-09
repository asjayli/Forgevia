---
name: forgevia-doctor
description: Use when the user explicitly asks Forgevia to inspect the Codex environment for missing or drifted Forgevia-managed assets.
---

# Forgevia Doctor

Use this skill when the user explicitly wants a health check for the Forgevia-managed Codex environment.

## Behavior

- Run the Forgevia doctor flow.
- Report `OK`, `MISS`, and `DRIFT` states clearly.
- Do not modify files in this mode.

## Implementation

- The check is implemented by the installed runtime script `$HOME/.codex/forgevia/bin/doctor-codex.sh`; run it from any directory: `bash "$HOME/.codex/forgevia/bin/doctor-codex.sh"`.
- It compares the Forgevia source baseline mirrored under `~/.codex/forgevia/` against the installed assets under `~/.codex`, reporting `OK`/`MISS`/`DRIFT`.

---
name: firefly-doctor
description: Use when the user explicitly asks firefly to inspect the Claude environment for missing or drifted firefly-managed assets.
---

# firefly Doctor

Use this skill when the user explicitly wants a health check for the firefly-managed Claude environment.

## Behavior

- Run the firefly doctor flow.
- Report `OK`, `MISS`, and `DRIFT` states clearly.
- Do not modify files in this mode.

## Implementation

- The check is implemented by the installed runtime script `$HOME/.claude/firefly/bin/doctor-claude.sh`; run it from any directory: `bash "$HOME/.claude/firefly/bin/doctor-claude.sh"`.
- It compares the firefly source baseline mirrored under `~/.claude/firefly/` against the installed assets under `~/.claude`, reporting `OK`/`MISS`/`DRIFT`.

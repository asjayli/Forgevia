---
name: firefly-doctor
description: Use when the user explicitly asks firefly to inspect the Codex environment for missing or drifted firefly-managed assets.
---

# firefly Doctor

Use this skill when the user explicitly wants a health check for the firefly-managed Codex environment.

## Behavior

- Run the firefly doctor flow.
- Report `OK`, `MISS`, and `DRIFT` states clearly.
- Do not modify files in this mode.

## Implementation

- The check is implemented by the installed runtime script `$HOME/.codex/firefly/bin/doctor-codex.sh`; run it from any directory: `bash "$HOME/.codex/firefly/bin/doctor-codex.sh"`.
- It compares the firefly source baseline mirrored under `~/.codex/firefly/` against the installed assets under `~/.codex`, reporting `OK`/`MISS`/`DRIFT`.

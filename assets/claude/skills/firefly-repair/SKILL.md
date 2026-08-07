---
name: firefly-repair
description: Use when the user explicitly asks firefly to repair missing or drifted firefly-managed assets in the Claude environment.
---

# firefly Repair

Use this skill when the user explicitly wants firefly to repair the managed Claude environment.

## Behavior

- Run the firefly doctor flow with repair enabled.
- Repair `MISS` and `DRIFT` states from firefly-owned copies.
- Preserve backups before replacement.

## Implementation

- Repair is the installed runtime script with `--repair`: `bash "$HOME/.claude/firefly/bin/doctor-claude.sh" --repair`.
- It refuses to repair OpenSpec overrides when the upstream OpenSpec version differs from the override snapshot version, to avoid downgrading upstream.

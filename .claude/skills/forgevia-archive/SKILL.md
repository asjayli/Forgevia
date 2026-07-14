---
name: forgevia-archive
description: Use when the user explicitly asks Forgevia to archive one named, active OpenSpec change, after syncing its delta specs into the main spec set.
---

# Forgevia Archive

Use this skill only when the user explicitly names a change to archive.

## Required Input

- An explicit active change name or change directory.

## Behavior

- Verify the change exists.
- Verify the change is not already archived.
- Sync the change's delta specs into the main specs first.
- Run `"${CLAUDE_HOME:-$HOME/.claude}/forgevia/bin/forgevia" validate --root <project-root>` after syncing and before archive. Stop if it returns a non-zero status.
- Only then route to the archive flow.
- Do not auto-select or infer the target change.

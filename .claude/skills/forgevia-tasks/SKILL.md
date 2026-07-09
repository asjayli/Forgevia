---
name: forgevia-tasks
description: Use when the user explicitly asks Forgevia to list unfinished tasks across active OpenSpec changes.
---

# Forgevia Tasks

Use this skill when the user explicitly wants a read-only task overview.

## Behavior

- List active, unarchived changes by creation time ascending.
- Show only unfinished checklist items from each change's `tasks.md`.
- Do not modify any files.

## Implementation

- Backed by the installed runtime script `$HOME/.claude/forgevia/bin/list-change-tasks.sh`; run it as `bash "$HOME/.claude/forgevia/bin/list-change-tasks.sh" [project_dir]` (defaults to the current directory).

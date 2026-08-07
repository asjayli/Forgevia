---
name: firefly-init
description: Use when the user explicitly asks firefly to initialize OpenSpec in the current project or verify whether the current project is ready for the firefly workflow.
---

# firefly Init

Use this skill when the user explicitly wants firefly to initialize the current project.

## Behavior

- Check whether `openspec` is installed and available.
- Check whether the current project already has OpenSpec initialization.
- If missing, invoke firefly's project bootstrap flow to run `openspec init`.
- When preparing a repository for the Claude firefly path, prefer initializing with `--tools codex,claude` so the project can be used consistently from both firefly clients.
- Do not modify project source files beyond OpenSpec's own initialization behavior.

## Implementation

- Backed by the installed runtime script `$HOME/.claude/firefly/bin/bootstrap-project.sh`; run it as `bash "$HOME/.claude/firefly/bin/bootstrap-project.sh" [--tools codex,claude] [project_dir]`.
- It checks whether `openspec` is on PATH and whether the target project already has OpenSpec initialization, then runs `openspec init` only when missing.

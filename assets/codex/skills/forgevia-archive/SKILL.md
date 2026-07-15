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
- Treat the explicit archive command as authorization to sync the named change's delta specs and perform the local archive move; it does not authorize push, release, or history rewriting.
- Independently review the sync plan, sync result, and archive package. Require `APPROVE`, `REVISE`, or `ESCALATE` with evidence.
- Sync the change's delta specs into the main specs by default, run `"${CODEX_HOME:-$HOME/.codex}/forgevia/bin/forgevia" validate --root <project-root>`, and automatically repair an authorized `REVISE` or validation failure before review.
- After each `APPROVE`, continue directly to the next sync or archive action. Only `ESCALATE` may request user input for data-loss risk, a goal conflict, missing authorization, or a real capability failure.
- Do not auto-select or infer the target change.

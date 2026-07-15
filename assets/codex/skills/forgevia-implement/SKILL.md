---
name: forgevia-implement
description: Use when the user explicitly asks Forgevia to implement one named, active OpenSpec change using superpowers with a TDD workflow.
---

# Forgevia Implement

Use this skill only when the user explicitly names a change to implement.

## Required Input

- An explicit active change name or change directory.

## Behavior

- Verify the change with `openspec status --change "<change>" --json` and use its resolved `changeRoot`.
- Verify the change is not archived.
- Verify the change has `tasks.md`.
- Use superpowers to complete the development for the named change.
- Require an explicit `superpowers:test-driven-development` execution path throughout the implementation.
- Do not treat TDD as implicit or optional when implementing the change.
- Use an independent reviewer at dependency-ready task groups and for the complete branch. Require `APPROVE`, `REVISE`, or `ESCALATE` with evidence.
- After `APPROVE`, record task facts and automatically continue to the next dependency-ready work unit.
- On an in-scope design issue, first test failure, or authorized `REVISE`, diagnose, repair, run targeted verification, and request another independent review.
- Only `ESCALATE` requests user input for a decision or authorization that cannot be inferred, an unavailable required capability, or a repair loop with no verifiable progress.
- Keep the change active when implementation and final review complete; implementation does not authorize sync, archive, push, merge, or release.

Do not guess the change from conversation context.

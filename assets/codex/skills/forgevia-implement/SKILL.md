---
name: forgevia-implement
description: Use when the user explicitly asks Forgevia to implement one named, active OpenSpec change using superpowers with a TDD workflow.
---

# Forgevia Implement

Use this skill only when the user explicitly names a change to implement.

## Required Input

- An explicit active change name or change directory.

## Behavior

**Independent review contract:** Every reviewer receives one review package containing:

- Objective: the authorized outcome.
- Scope: the allowed repositories, changes, files, and systems.
- Constraints: the binding process, architecture, safety, and platform rules.
- Authorized effects: the writes and side effects allowed to the controller.
- Terminal condition: the state at which this workflow must stop.
- The candidate producer identity, candidate artifacts, action, or diff, verification evidence, assumptions and risks.

If a reviewer fails to start, times out, crashes, or returns an invalid verdict, reuse the unchanged review package with at most two new independent review agents. If both retries fail, return `ESCALATE` with the collected infrastructure evidence; never infer `APPROVE`. The controller validates only reviewer identity, verdict structure, and supporting evidence; it does not recursively review the verdict.

Implementation runs continuously by default. A completed task group, passing verification, a refactor, or a progress report never ends the workflow or waits for feedback. The final independent review's `APPROVE` is the completion gate.

Before returning a completion summary, confirm every completion gate:

- `tasks.md` contains no unchecked implementation item.
- No planned implementation task remains pending or in progress.
- The required complete verification has succeeded.
- The change scope has been reviewed and `git diff --check` succeeds.
- The final independent review is `APPROVE`.

Never use completion language or a final delivery format while any implementation task remains unchecked or in progress.

The final independent review runs once on the complete branch. The controller dispatches an authorized repair subagent for every `REVISE` finding, requires targeted verification, and dispatches a fresh independent reviewer. That reviewer must not have produced the candidate or any repair in the current cycle.

Repeat this repair-review loop until an `APPROVE` verdict or the no-progress `ESCALATE` boundary. The severity-gated closing rule bounds this loop: it ends on `APPROVE`, or once every Critical and Important finding has been fixed and confirmed by a fresh re-review, after at most three further review rounds; remaining Minor findings are recorded as follow-up items in the coverage ledger, not silently dropped. This closing rule does not override the no-progress `ESCALATE` boundary.

- Verify the change with `openspec status --change "<change>" --json` and use its resolved `changeRoot`.
- Verify the change is not archived.
- Verify the change has `tasks.md`.
- Use superpowers to complete the development for the named change.
- Require an explicit `superpowers:test-driven-development` execution path throughout the implementation.
- Do not treat TDD as implicit or optional when implementing the change.
- Use an independent reviewer once for the complete branch before completion. Require `APPROVE`, `REVISE`, or `ESCALATE` with evidence.
- After the final `APPROVE`, record completion and keep the change active; the complete branch is the review scope, so there is no next dependency-ready work unit to advance to.
- On an in-scope design issue, first test failure, or authorized `REVISE`, diagnose, repair, run targeted verification, and request another independent review.
- Only `ESCALATE` requests user input for a decision or authorization that cannot be inferred, an unavailable required capability, or a repair loop with no verifiable progress.
- Keep the change active when implementation and final review complete; implementation does not authorize sync, archive, push, merge, or release.

Do not guess the change from conversation context.

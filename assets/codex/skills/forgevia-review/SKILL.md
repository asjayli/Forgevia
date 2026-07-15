---
name: forgevia-review
description: Use when the user explicitly asks Forgevia to run a code review checkpoint for the current implementation work.
---

# Forgevia Review

Use this skill when the user explicitly wants a review checkpoint.

## Behavior

**Independent review contract:** Every reviewer receives one review package containing:

- Objective: the authorized outcome.
- Scope: the allowed repositories, changes, files, and systems.
- Constraints: the binding process, architecture, safety, and platform rules.
- Authorized effects: the writes and side effects allowed to the controller.
- Terminal condition: the state at which this workflow must stop.
- The candidate producer identity, candidate artifacts, action, or diff, verification evidence, assumptions and risks.

If a reviewer fails to start, times out, crashes, or returns an invalid verdict, reuse the unchanged review package with at most two new independent review agents. If both retries fail, return `ESCALATE` with the collected infrastructure evidence; never infer `APPROVE`. The controller validates only reviewer identity, verdict structure, and supporting evidence; it does not recursively review the verdict.

- Run `"${CODEX_HOME:-$HOME/.codex}/forgevia/bin/forgevia" validate --root <project-root>` before the review. Treat a non-zero result as a blocking OpenSpec finding and report its file-level output.
- Route to `requesting-code-review`.
- Use the current named change or implementation context already established by the user.
- Prefer a commit-bounded review request with explicit `BASE_SHA` and `HEAD_SHA`.
- Require findings to be reported in strict severity order, with `P0` before `P1`.
- Require the independent reviewer to return `APPROVE`, `REVISE`, or `ESCALATE` with evidence. For this standalone read-only command, return `REVISE` findings without fixing them; only `ESCALATE` requests a user decision.
- A `REVISE` verdict returns findings and stops without editing product files, `tasks.md`, or `.superpowers/sdd/progress.md`.

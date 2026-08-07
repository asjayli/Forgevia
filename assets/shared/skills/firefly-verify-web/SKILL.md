---
name: firefly-verify-web
description: Use when the user explicitly asks firefly to run browser-based verification for a web-facing change.
---

# firefly Verify Web

Use this skill when the user explicitly wants browser-based verification.

## Behavior

**Independent review contract:** Every reviewer receives one review package containing:

- Objective: the authorized outcome.
- Scope: the allowed repositories, changes, files, and systems.
- Constraints: the binding process, architecture, safety, and platform rules.
- Authorized effects: the writes and side effects allowed to the controller.
- Terminal condition: the state at which this workflow must stop.
- The candidate producer identity, candidate artifacts, action, or diff, verification evidence, assumptions and risks.

If a reviewer fails to start, times out, crashes, or returns an invalid verdict, reuse the unchanged review package with at most two new independent review agents. If both retries fail, return `ESCALATE` with the collected infrastructure evidence; never infer `APPROVE`. The controller validates only reviewer identity, verdict structure, and supporting evidence; it does not recursively review the verdict.

- Route to `playwright-interactive`.
- Use this for web behavior, UI interaction, visual verification, and browser-facing regressions.
- Produce `browser-evidence` for the coverage ledger: record the steps executed, the observed result, and an artifact path (screenshot, trace, or HAR) for each verified web behavior.
- Require the independent browser reviewer to return `APPROVE`, `REVISE`, or `ESCALATE` with evidence. For this standalone read-only command, return `REVISE` findings without editing product code; only `ESCALATE` requests a user decision.
- A `REVISE` verdict returns findings and stops without editing product files, `tasks.md`, or `.superpowers/sdd/progress.md`.

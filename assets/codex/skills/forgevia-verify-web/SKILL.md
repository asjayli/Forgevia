---
name: forgevia-verify-web
description: Use when the user explicitly asks Forgevia to run browser-based verification for a web-facing change.
---

# Forgevia Verify Web

Use this skill when the user explicitly wants browser-based verification.

## Behavior

- Route to `playwright-interactive`.
- Use this for web behavior, UI interaction, visual verification, and browser-facing regressions.
- Require the independent browser reviewer to return `APPROVE`, `REVISE`, or `ESCALATE` with evidence. For this standalone read-only command, return `REVISE` findings without editing product code; only `ESCALATE` requests a user decision.

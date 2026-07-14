---
name: forgevia-review
description: Use when the user explicitly asks Forgevia to run a code review checkpoint for the current implementation work.
---

# Forgevia Review

Use this skill when the user explicitly wants a review checkpoint.

## Behavior

- Run `"${CODEX_HOME:-$HOME/.codex}/forgevia/bin/forgevia" validate --root <project-root>` before the review. Treat a non-zero result as a blocking OpenSpec finding and report its file-level output.
- Route to `requesting-code-review`.
- Use the current named change or implementation context already established by the user.
- Prefer a commit-bounded review request with explicit `BASE_SHA` and `HEAD_SHA`.
- Require findings to be reported in strict severity order, with `P0` before `P1`.

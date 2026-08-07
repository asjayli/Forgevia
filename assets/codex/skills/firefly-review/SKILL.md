---
name: firefly-review
description: Use when the user explicitly asks firefly to run a code review checkpoint for the current implementation work.
---

# firefly Review

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

- Run `"${CODEX_HOME:-$HOME/.codex}/firefly/bin/firefly" validate --root <project-root>` before the review. Treat a non-zero result as a blocking OpenSpec finding and report its file-level output.
- Use the current named change or implementation context already established by the user.
- Generate the review package before routing to `requesting-code-review`. Use the established implementation or merge base as BASE: run `review-package BASE HEAD` when the candidate is fully committed, otherwise run `review-package BASE WORKTREE` to include staged, unstaged, and untracked files.
- Pass the printed path as `DIFF_FILE`. Route to `requesting-code-review` only after confirming that package exists and is readable.
- Require findings to be reported in strict severity order, with `P0` before `P1`.
- Require the independent reviewer to return `APPROVE`, `REVISE`, or `ESCALATE` with evidence. For this standalone read-only command, return `REVISE` findings without fixing them; only `ESCALATE` requests a user decision.
- A `REVISE` verdict returns findings and stops without editing product files, `tasks.md`, or `.superpowers/sdd/progress.md`.
- When this checkpoint is the complete-branch final review, the repair-review loop (driven by the controller, not this standalone command) ends on `APPROVE`, or once every Critical and Important finding has been fixed and confirmed by a fresh re-review, after at most three further review rounds; remaining Minor findings are recorded as follow-up items in the coverage ledger, not silently dropped. This severity-gated closing does not override the no-progress `ESCALATE` boundary.
- At the complete-branch final review, verify the verification coverage ledger: every acceptance criterion has exactly one of `machine-reverified`, `browser-evidence`, `external-evidence`, `trusted-prior`, or `unverified`; `unverified` must be 0; no machine-verifiable criterion is downgraded to `trusted-prior`; Web/UI changes that declared browser verification have `browser-evidence`; every `trusted-prior` has a reason and original evidence. Check each row against the spec, test-plan, and tasks; coverage is not self-certified by the candidate producer. A gap is a blocking finding.

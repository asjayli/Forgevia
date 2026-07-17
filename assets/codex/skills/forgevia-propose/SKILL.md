---
name: forgevia-propose
description: Use when the user explicitly asks Forgevia to turn a requirement description or a specified file into a new OpenSpec change proposal.
---

# Forgevia Propose

Use this skill when the user explicitly wants Forgevia to produce a new OpenSpec change from a requirement description or a specified file.

## Accepted Input

- A direct user description of the change to build.
- A specified file path whose contents should be treated as the requirement source.
- Both, where the file is primary and the user prompt adds clarification.

## Behavior

**Independent review contract:** Every reviewer receives one review package containing:

- Objective: the authorized outcome.
- Scope: the allowed repositories, changes, files, and systems.
- Constraints: the binding process, architecture, safety, and platform rules.
- Authorized effects: the writes and side effects allowed to the controller.
- Terminal condition: the state at which this workflow must stop.
- The candidate producer identity, candidate artifacts, action, or diff, verification evidence, assumptions and risks.

If a reviewer fails to start, times out, crashes, or returns an invalid verdict, reuse the unchanged review package with at most two new independent review agents. If both retries fail, return `ESCALATE` with the collected infrastructure evidence; never infer `APPROVE`. The controller validates only reviewer identity, verdict structure, and supporting evidence; it does not recursively review the verdict.

**Reviewer lifecycle:**

- An active reviewer is not a terminal state. A reviewer remains active while queued, running, or awaiting collection of its verdict for the current candidate.
- After dispatching a reviewer, retain control and poll internally; do not emit a final response, completion summary, or user-facing wait request while an active reviewer remains.
- `APPROVE` is valid only when every required reviewer has returned a valid verdict for the same candidate.
- On the first valid `REVISE`, invalidate reviews of that candidate, collect findings that have already returned, and do not wait for stale reviews. An invalidated reviewer is obsolete and non-blocking. Cancel it when the platform supports cancellation; otherwise ignore any late verdict, which cannot apply to a later candidate.
- A final-state check counts only reviewers that remain required for the current candidate. Before any final response, confirm that no active reviewer remains and that the command has reached its explicit terminal state.
- Repair the candidate, revalidate it, and dispatch a fresh independent review.

- Route the requirement source into `openspec-propose`.
- Allow the change name to come from the user when explicitly provided.
- Otherwise derive an appropriate kebab-case change name from the requirement source.
- Treat the provided file as requirement input, not as implementation output.
- If the requirement source cannot be recovered from the provided input, referenced files, conversation, or repository evidence, return `ESCALATE` through the three-state review protocol with the missing evidence, a recommended default, option impacts, and why work cannot continue.
- Validate the current planning package before dispatching its reviewer. If validation fails, repair only the matching planning artifact type and rerun the same validation. Dispatch an independent review only after that planning validation passes.
- Independently review the proposal/design/specs package and the tasks package. Require `APPROVE`, `REVISE`, or `ESCALATE`; automatically repair an authorized `REVISE`, revalidate, and review again.
- After all apply-required artifacts are complete, run strict OpenSpec validation for the complete change. If strict validation fails, repair the indicated proposal, design, specs, or tasks and rerun strict validation. Independently review every package changed by strict-validation repair before reporting the proposal apply-ready.
- Continue through all apply-ready planning artifacts after `APPROVE`; only `ESCALATE` may request a critical decision that cannot be inferred.
- Proposal completion does not authorize implementation, commit, sync, archive, push, merge, or release.
- When writing Chinese requirements, use one of `必须、不得、禁止、应当` in the requirement body. Keep OpenSpec structure keywords in English, including `## Requirements` and `### Requirement:`.
- After creating the change artifacts, run `"${CODEX_HOME:-$HOME/.codex}/forgevia/bin/forgevia" validate --root <project-root>`. Do not report the proposal as strictly valid if this command fails.

---
name: forgevia
description: Use when the user explicitly asks to use Forgevia to run the full OpenSpec plus superpowers plus review plus Playwright workflow instead of invoking the underlying skills manually.
---

# Forgevia

Forgevia is an explicit orchestration skill. It does not replace OpenSpec, superpowers, requesting-code-review, or playwright-interactive. It coordinates them.

## When To Use

Use Forgevia only when the user explicitly asks for it, such as:

- `use Forgevia`
- `run this through Forgevia`
- `use the Forgevia workflow`

Do not auto-trigger Forgevia just because a coding request exists.

## Preconditions

Before using Forgevia, verify:

- `openspec` is installed and available
- required `superpowers` skills are installed
- Forgevia-managed overrides are present under `~/.codex`
- `playwright-interactive` is available when the work touches web behavior

If required pieces are missing, stop and tell the user which installation or doctor step is needed.

## Workflow

Forgevia uses deterministic routing:

- A named subcommand authorizes that command's documented terminal condition.
- A Forgevia request with a requirement but no named subcommand authorizes the complete delivery workflow by default. Clarify only consequential ambiguity, then propose, implement, run browser verification when relevant, and perform the final independent review.
- A request that explicitly names multiple phases authorizes those phases in order.
- Read-only, exploratory, status, and review intent does not authorize implementation.

For a complete delivery, resolve the change name during proposal and carry the resolved change name directly into implementation. Do not require the user to repeat a controller-generated name. Do not pause, summarize, or ask for confirmation between those phases.

Complete-delivery phase order is: proposal -> implementation -> browser verification when relevant -> final independent review. Browser verification is a pre-review gate. On a browser-verification failure or `REVISE`, repair within the authorization envelope, rerun targeted verification and browser verification, and repeat until it passes or returns `ESCALATE`. Only after browser verification passes or is explicitly not applicable may the controller dispatch the final independent review.

## Autonomous Execution Contract

At entry, resolve an objective authorization envelope with these fields:

- Objective: the authorized outcome.
- Scope: the allowed repositories, changes, files, and systems.
- Constraints: the binding process, architecture, safety, and platform rules.
- Authorized effects: the writes and side effects allowed to the controller.
- Terminal condition: the state at which this workflow must stop.

Continue inside that envelope until the terminal condition is met, a real blocker requires new user input, or the user interrupts. Phase boundaries, progress reports, warnings, and ordinary recoverable failures are observations, not confirmation gates.

Implementation runs continuously by default. A completed task group, passing verification, a refactor, or a progress report never ends the workflow or waits for feedback. The final independent review's `APPROVE` is the completion gate.

**Codex continuous controller:** Until the workflow reaches every final completion gate, receives a valid `ESCALATE`, or the user explicitly stops it, the controller MUST continue execution. It MUST NOT send a `final` response after a child-agent callback, a review `REVISE`, a single wait timeout, or the end of a phase's verification.

**Codex child-agent waiting:** The single blocking-wait limit is 60 seconds. After dispatching an in-scope child agent with `spawn_agent`, repeatedly call `wait_agent` with `timeout_ms: 60000` and use `list_agents` to poll the active-agent set. When a wait times out, immediately begin the next 60-second wait while any in-scope child remains active. When a callback arrives, automatically continue with its repair, verification, or next workflow phase, then resume the wait loop for every remaining active child.

**Status reports:** Any progress report MUST state the running agents, current phase, and next gate. A status report is not task completion and MUST NOT use `final` while the continuous-controller condition remains true.

Before returning a completion summary, confirm every completion gate:

- `tasks.md` contains no unchecked implementation item.
- No planned implementation task remains pending or in progress.
- The required complete verification has succeeded.
- The change scope has been reviewed and `git diff --check` succeeds.
- The final independent review is `APPROVE`.

Never use completion language or a final delivery format while any implementation task remains unchecked or in progress.

Use an independent review agent different from the agent that produced the candidate. On Codex, dispatch that reviewer with `spawn_agent`. Every review package includes the candidate producer identity, relevant OpenSpec and candidate artifacts, action, or diff, verification evidence, assumptions and risks. Accept only these evidence-backed verdicts:

- `APPROVE`: record the reviewed result and automatically continue to the next in-scope work unit.
- `REVISE`: the controller dispatches an authorized repair subagent, requires matching verification, and dispatches a fresh independent reviewer that did not produce the candidate or repair; standalone read-only review and verify-web commands return findings instead.
- `ESCALATE`: combine the unresolved decisions, evidence, recommended default, option impacts, and reason automation cannot continue into one user request.

The controller dispatches an authorized repair subagent for every `REVISE` finding, requires targeted verification, and dispatches a fresh independent reviewer.

Repeat this repair-review loop until an `APPROVE` verdict or the no-progress `ESCALATE` boundary.

If a reviewer fails to start, times out, crashes, or returns an invalid verdict, reuse the unchanged review package with at most two new independent review agents. If both retries fail, return `ESCALATE` with the collected infrastructure evidence; never infer `APPROVE`. The controller validates only reviewer identity, verdict structure, and supporting evidence; it does not recursively review the verdict.

**Reviewer lifecycle:**

- An active reviewer is not a terminal state. A reviewer remains active while queued, running, or awaiting collection of its verdict for the current candidate.
- After dispatching a reviewer, retain control and poll internally; do not emit a final response, completion summary, or user-facing wait request while an active reviewer remains.
- `APPROVE` is valid only when every required reviewer has returned a valid verdict for the same candidate.
- On the first valid `REVISE`, invalidate reviews of that candidate, collect findings that have already returned, and do not wait for stale reviews. An invalidated reviewer is obsolete and non-blocking. Cancel it when the platform supports cancellation; otherwise ignore any late verdict, which cannot apply to a later candidate.
- A final-state check counts only reviewers that remain required for the current candidate. Before any final response, confirm that no active reviewer remains and that the command has reached its explicit terminal state.
- Repair the candidate, revalidate it, and dispatch a fresh independent review.

Only ESCALATE pauses the workflow for user input. Escalation is limited to a critical ambiguity that cannot be reasonably inferred, a required scope expansion, a conflicting higher-priority rule, an unauthorized external or irreversible effect, unavailable review capability after its retry policy, or a repair loop that no longer makes verifiable progress.

Command names fix the terminal condition and do not grant unrelated effects. A complete Forgevia delivery ends after proposal, implementation, relevant verification, and final review with the change still active; it does not authorize spec sync, commit, archive, push, merge, or release. Standalone think and propose do not authorize implementation. Implement may edit and test and update its OpenSpec task facts; it may create local checkpoint commits only when authorized effects explicitly allow commits and branch policy permits. Implement does not authorize spec sync or archive. Archive authorizes spec sync and the local archive move, but not push or release.

Reaching apply-ready is an internal phase transition during a complete delivery, not a reporting or confirmation gate. Automatically route the resolved change into implementation and continue until the complete-delivery terminal condition.

## Commands

### `Forgevia init`

Purpose:
- check the global Forgevia environment
- check whether the target repository already has OpenSpec initialization
- invoke `openspec init` only when initialization is missing
- prefer `--tools codex,claude` when the repository should support both Forgevia clients

Behavior:
- route to Forgevia's environment checks and bootstrap flow
- do not take ownership of project source files

### `Forgevia doctor`

Purpose:
- inspect the current Codex environment for missing or drifted Forgevia-managed assets

Behavior:
- use the Forgevia doctor flow
- report `OK`, `MISS`, or `DRIFT`

### `Forgevia repair`

Purpose:
- repair missing or drifted Forgevia-managed assets

Behavior:
- use the Forgevia repair flow
- preserve backups before replacement

### `Forgevia implement <change>`

This command MUST include an explicit active change name or directory.

Purpose:
- execute development for a specific unarchived OpenSpec change

Required checks:
- run `openspec status --change "<change>" --json` and use its resolved `changeRoot`
- the change is not already archived
- the change has a `tasks.md`

Behavior:
- treat the named change as the source of truth
- use superpowers to complete the development for the named change
- explicitly invoke `superpowers:test-driven-development` during implementation rather than treating TDD as implicit
- prefer `subagent-driven-development` or `executing-plans` based on the task structure
- use `requesting-code-review` once for the complete branch before completion
- diagnose and repair in-scope design issues, first test failures, and review findings before considering escalation
- after the final `APPROVE`, keep the change active; do not advance to a next dependency-ready task — the complete branch is the review scope

Do not guess the change from conversation context when this command is used.

### `Forgevia archive <change>`

This command MUST include an explicit change name or directory.

Purpose:
- archive a specific unarchived OpenSpec change

Behavior:
- verify the named change exists and is not already archived
- sync the change's delta specs into the main specs first
- independently review the sync plan, sync result, and archive package
- on `APPROVE`, route directly to the next sync or archive action without another confirmation
- do not auto-select a change

### `Forgevia tasks`

Purpose:
- list unfinished tasks across all active, unarchived changes

Behavior:
- list active changes by creation time ascending
- show only unfinished checklist items
- use this as the default read-only task overview command

### `Forgevia think`

Purpose:
- think through a requirement before implementation

Behavior:
- create or reuse `openspec/think/` for think artifacts
- restate the requirement and current understanding first
- independently review the restated understanding and boundaries
- on `APPROVE`, write the reviewed think result to a dated Markdown file under `openspec/think/` without waiting for user confirmation
- version repeated iterations of the same requirement with `-v2`, `-v3`, and so on
- use the requirement input, related notes, and `.mmd` design flow as the exploration prompt when available

### `Forgevia propose`

Purpose:
- turn a requirement description or specified file into a new OpenSpec change

Behavior:
- route to `openspec-propose`
- accept either direct user description or a specified file as requirement input
- use an explicit user-provided change name when available
- otherwise derive a kebab-case change name from the requirement source
- independently review the planning artifacts and continue until the change is apply-ready
- for standalone `Forgevia propose`, report apply-ready as the command's normal terminal condition and provide `Forgevia implement <resolved-change>` as the exact next command without asking whether to proceed
- when proposal runs inside an already-authorized complete delivery, pass `<resolved-change>` directly to implementation without emitting a proposal completion response

### `Forgevia review`

Purpose:
- force an explicit code review checkpoint

Behavior:
- route to `requesting-code-review`

### `Forgevia verify-web`

Purpose:
- force explicit browser validation for a web-facing change

Behavior:
- route to `playwright-interactive`

### `Forgevia draw`

Purpose:
- use Mermaid Diagram Specialist together with user-provided 功能/链路/接口信息 to generate a complete interaction-module sequence diagram

Behavior:
- route to `mermaid-diagram-specialist`
- prefer a Mermaid sequence diagram for the interaction module
- pass the Mermaid output to `forgevia-draw.sh`
- write a timestamped `.mmd`
- render a matching `.svg`, preferring a local Chrome/Chromium executable for `mmdc` when available
- name outputs as `YYYYMMDD-HHMMSS-功能`

## Execution Principles

### 1. Anchor on the named change

Treat the explicitly named change as the single source of truth during implementation. Derive scope, tasks, and review focus from `changeRoot` and `artifactPaths` returned by `openspec status --json`, not from conversation context.

### 2. Use the Forgevia-modified superpowers path

When implementation planning or execution is needed, prefer the Forgevia-managed variants of:

- `brainstorming`
- `writing-plans`
- `subagent-driven-development`
- `requesting-code-review`
- `executing-plans`

These variants are expected to be OpenSpec-oriented and to resolve artifact paths from `openspec status --json`.

### 3. Trigger Playwright only when relevant

If the change affects web behavior, UI, interaction flow, or visual output, require `playwright-interactive` before the final independent review.

If the change is backend-only or otherwise has no browser-facing impact, skip Playwright explicitly.

Treat a browser-verification failure or `REVISE` as a repair signal: repair within scope, rerun targeted verification and browser verification, and do not dispatch the final independent review until this gate passes. Only `ESCALATE` requests a user decision.

### 4. Trigger the final review

Use `requesting-code-review` once, for the complete branch after all required verification — the only review checkpoint during implementation. Do not silently skip it because a change looks small.

Treat review as an internal control signal: `APPROVE` completes the authorized delivery, authorized `REVISE` enters the matching repair loop and reruns affected verification before a fresh final review, and only `ESCALATE` requests a user decision. The main agent validates verdict identity, structure, authorization, and evidence itself; it does not recursively dispatch another reviewer to review the verdict.

### 5. Close the loop

When implementation is complete:

- ensure review checkpoints are satisfied
- ensure verification has run
- stop with the change active unless the user separately authorized archive

### 6. Respect project ownership boundaries

Forgevia may help detect whether a repository has been initialized with OpenSpec and may invoke `openspec init` when the user wants that help.

Forgevia does not take ownership of project source files or silently overlay project-local workflow files.

## Boundaries

- Forgevia orchestrates; it does not manually duplicate every underlying skill body.
- Forgevia should keep the user on one coherent workflow, not invent side workflows.
- If a lower-level skill is clearly the right direct tool for the current step, Forgevia should say so and use it.
- Forgevia manages global workflow environment and invocation patterns, not user project code.

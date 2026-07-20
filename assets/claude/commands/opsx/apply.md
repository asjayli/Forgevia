---
name: "OPSX: Apply"
description: Implement tasks from an OpenSpec change (Experimental)
category: Workflow
tags: [workflow, artifacts, experimental]
---

Implement tasks from an OpenSpec change.

**Store selection:** If the user names a store (a store is a standalone OpenSpec repo registered on this machine) or the work lives in one, run `openspec store list --json` to discover registered store ids, then pass `--store <id>` on the commands that read or write specs and changes (`new change`, `status`, `instructions`, `list`, `show`, `validate`, `archive`, `doctor`, `context`). Other commands do not take the flag. Hints printed by commands already carry the flag; keep it on follow-ups. Without a store, commands act on the nearest local `openspec/` root.

**Input**: Optionally specify a change name (e.g., `/opsx:apply add-auth`). If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Independent review contract:** Every task and full-branch reviewer receives the same structured fields:

- Objective: the authorized outcome.
- Scope: the allowed repositories, changes, files, and systems.
- Constraints: the binding process, architecture, safety, and platform rules.
- Authorized effects: the writes and side effects allowed to the controller.
- Terminal condition: the state at which this workflow must stop.
- The candidate producer identity, candidate artifacts, action, or diff, verification evidence, assumptions and risks.

If a reviewer fails to start, times out, crashes, or returns an invalid verdict, reuse the unchanged review package with at most two new independent review agents. If both retries fail, return `ESCALATE` with the collected infrastructure evidence; never infer `APPROVE`. The controller validates only reviewer identity, verdict structure, and supporting evidence; it does not recursively review the verdict.

## Default Continuous Execution

Implementation runs continuously by default. A completed task group, passing verification, an `APPROVE` verdict, a refactor, or a progress report never ends the workflow or waits for feedback.

Before returning a completion summary, confirm every completion gate:

- `tasks.md` contains no unchecked implementation item.
- No planned implementation task remains pending or in progress.
- The required complete verification has succeeded.
- The change scope has been reviewed and `git diff --check` succeeds.
- The final independent review is `APPROVE`.

Never use completion language or a final delivery format while any implementation task remains unchecked or in progress.

The controller dispatches an authorized repair subagent for every `REVISE` finding, requires targeted verification, and dispatches a fresh independent reviewer. That reviewer must not have produced the candidate or any repair in the current cycle.

Repeat this repair-review loop until an `APPROVE` verdict or the no-progress `ESCALATE` boundary.

**Steps**

1. **Select the change**

   If a name is provided, use it. Otherwise:
   - Infer from conversation context if the user mentioned a change
   - Auto-select if only one active change exists
   - If ambiguous, run `openspec list --json` to get available changes and use the **AskUserQuestion tool** to let the user select

   Always announce: "Using change: <name>" and how to override (e.g., `/opsx:apply <other>`).

2. **Check status to understand the schema**
   ```bash
   openspec status --change "<name>" --json
   ```
   Parse the JSON to understand:
   - `schemaName`: The workflow being used (e.g., "spec-driven")
   - `planningHome`, `changeRoot`, and `actionContext`: planning scope and edit constraints
   - Which artifact contains the tasks (typically "tasks" for spec-driven, check status for others)

3. **Get apply instructions**

   ```bash
   openspec instructions apply --change "<name>" --json
   ```

   This returns:
   - `contextFiles`: artifact ID -> array of concrete file paths (varies by schema)
   - Progress (total, complete, remaining)
   - Task list with status
   - Dynamic instruction based on current state

   **Handle states:**
   - If `state: "blocked"` (missing artifacts): show message, suggest using `/opsx:continue`
   - When apply instructions report `state: "all_done"`, resume at integration and global verification; do not congratulate, suggest archive, or report completion yet.
   - Otherwise: proceed to implementation

4. **Read context files**

   Read every file path listed under `contextFiles` from the apply instructions output.
   The files depend on the schema being used:
   - **spec-driven**: proposal, specs, design, tasks
   - Other schemas: follow the contextFiles from CLI output

5. **Show current progress**

   Display:
   - Schema being used
   - Progress: "N/M tasks complete"
   - Remaining tasks overview
   - Dynamic instruction from CLI

6. **Implement tasks (loop until done or blocked)**

   For each pending task:
   - Show which task is being worked on
   - Make the code changes required
   - Keep changes minimal and focused
   - Run the task's targeted verification
   - Follow the explicit TDD path (RED/GREEN/REFACTOR) for the task
   - On completion, mark the task complete in the tasks file (`- [ ]` → `- [x]`) and continue to the next task
   - Diagnose and repair in-scope design issues and first test failures within scope, then run targeted verification; this is not a user confirmation gate
   - On `ESCALATE`, combine the blocking evidence, recommended default, option impacts, and reason the workflow cannot continue into one user decision request.

   Only `ESCALATE` pauses for user input. Use it only for a critical ambiguity that cannot be reasonably inferred, a required scope or authorization expansion, a conflicting rule, an unavailable required capability, or a repair loop with no verifiable progress. The user may also interrupt explicitly.

7. **Run final integration verification and full-branch review**

   Complete every task. Run integration and global verification across the complete implementation. Build a commit-bounded full-branch review package covering the complete implementation range, or a WORKTREE package when commit authorization or branch policy left changes uncommitted. Dispatch a fresh full-branch reviewer that is independent from every candidate producer. Only a final `APPROVE` may produce `Implementation Complete`.

   The final repair-review loop ends on `APPROVE`, or once every Critical and Important finding has been fixed and confirmed by a fresh re-review, after at most three further review rounds; remaining Minor findings are recorded as follow-up items in the coverage ledger, not silently dropped. This severity-gated closing does not override the no-progress `ESCALATE` boundary.

   On a final authorized `REVISE`, the controller dispatches an implementation repair subagent with the findings, reruns integration and global verification, builds a fresh full-branch package, and dispatches a fresh independent full-branch reviewer. Without repair authorization, return the findings unchanged. A final `ESCALATE` is limited to the substantive boundaries in the independent review contract.

8. **On completion or escalation, show status**

   Display:
   - Tasks completed this session
   - Overall progress: "N/M tasks complete"
   - If all done and the final review approved: report completion and keep the change active
   - If escalated: report the consolidated decision request and its evidence

**Output During Implementation**

```
## Implementing: <change-name> (schema: <schema-name>)

Working on task 3/7: <task description>
[...implementation happening...]
✓ Task complete

Working on task 4/7: <task description>
[...implementation happening...]
✓ Task complete
```

**Output On Completion**

```
## Implementation Complete

**Change:** <change-name>
**Schema:** <schema-name>
**Progress:** 7/7 tasks complete ✓

### Completed This Session
- [x] Task 1
- [x] Task 2
...

All tasks and final integration review complete. The change remains active.
```

**Output On Escalation (User Decision Required)**

```
## Implementation Escalated

**Change:** <change-name>
**Schema:** <schema-name>
**Progress:** 4/7 tasks complete

### Blocking Decision
<evidence, unresolved decision, and why it cannot be inferred>

**Options:**
1. <recommended default and impact>
2. <option 2>

No further in-scope action can proceed without this decision.
```

**Guardrails**
- Keep going through tasks until done or blocked
- Always read context files before starting (from the apply instructions output)
- Infer ordinary implementation details from the objective, artifacts, and repository evidence; escalate only a consequential ambiguity with multiple materially different outcomes
- If implementation reveals issues, update authorized artifacts or code, then re-run the matching verification and independent review
- Keep code changes minimal and scoped to each task
- Update a task checkbox only after targeted verification and an independent `APPROVE`
- Diagnose the first test failure and other recoverable errors before escalation
- Only `ESCALATE` pauses for user input
- Use contextFiles from CLI output, don't assume specific file names

**Fluid Workflow Integration**

This skill supports the "actions on a change" model:

- **Can be invoked anytime**: Before all artifacts are done (if tasks exist), after partial implementation, interleaved with other actions
- **Allows artifact updates**: If implementation reveals design issues, suggest updating artifacts - not phase-locked, work fluidly

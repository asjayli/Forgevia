---
name: writing-plans
description: Use when you have a spec or requirements for a multi-step task, before touching code
---

# Writing OpenSpec Tasks Plans

## Overview

Generate a single executable `tasks.md` for a change by reading all capability specs and test plans.

**Announce at start:** "I'm using the writing-plans skill to create OpenSpec tasks.md from all capability specs."

**Context:** Run in a dedicated worktree.

**Output path:** `openspec/changes/<change-name>/tasks.md`

## Inputs You Must Read

Always read these before writing tasks:
- `openspec/changes/<change-name>/proposal.md`
- `openspec/changes/<change-name>/design.md`
- `openspec/changes/<change-name>/specs/*/spec.md`
- `openspec/changes/<change-name>/specs/*/test-plan.md`

If any capability is missing `spec.md`, stop and ask to complete brainstorming first.
If a capability is missing `test-plan.md`, either create a minimal plan or stop for clarification.

## Output Format (OpenSpec)

Follow OpenSpec `tasks.md` style (grouped checklist), but enrich each group/task with traceability and dependencies.

Required shape:

```markdown
## 1. <Task Group Name>

Depends on: <none|group numbers>

Global Constraints: [spec's project-wide requirements — version floors, dependency limits, naming/copy rules — one line each, verbatim. Every task in this group implicitly includes them.]

Interfaces:
- Consumes: [exact signatures from earlier groups]
- Produces: [exact names/types later groups rely on]

Traceability:
- Requirements: [[specs/<capability>/spec.md#<requirement-section>]]
- Tests: [[specs/<capability>/test-plan.md#<test-section>]]

- [ ] 1.1 RED: add failing test for <behavior> [[specs/...]] [[specs/.../test-plan...]]
- [ ] 1.2 RED: run targeted test and confirm failure
- [ ] 1.3 GREEN: implement minimal code for <behavior>
- [ ] 1.4 GREEN: run targeted test and confirm pass
- [ ] 1.5 REFACTOR: clean up while keeping tests green
```

## Verification Contract (required)

Every `tasks.md` must open with a Verification Contract that pins how this change is proven. Fill every field with concrete, runnable content — no placeholders.

```markdown
## Verification Contract

### Baseline Commands
- <safe command run before any code change to capture the starting state>

### Targeted Commands
- <task group number>: <command that verifies that group's deliverable>

### Final Commands
- <deduplicated union of every targeted command; the necessary full set, not a mechanical repeat>

### Browser Verification
- Required: yes | no
- Reason: <why browser evidence is or is not needed>
- Evidence: <expected artifact path or description when Required: yes>

### Non-Replayable Checks
- <external or manual criterion and the evidence that must accompany it>
```

Contract rules:

- Baseline Commands must be safe and side-effect-free: never deploy, release, mutate a database, or write to an external system.
- Targeted Commands are scoped per task group and must actually exercise that group's deliverable.
- Final Commands are the necessary union of all targeted commands — deduplicated, not repeated verbatim.
- Any Web/UI change must declare Browser Verification with `Required: yes` and name the evidence artifact.
- If there is no browser surface, explicitly write `Required: no` and state why.
- Non-Replayable Checks capture anything a command cannot re-run (external systems, manual sign-off) and the evidence required for each.

## Task Planning Rules

1. One unified `tasks.md` per change (not per capability file).
2. Create at least one task group per capability.
3. Add cross-capability groups if integration work is required.
4. Explicitly mark group dependencies (`Depends on`).
5. Every task must include bidirectional links:
   - Task -> requirement/test via `[[file.md#section]]`
   - Requirement/test -> task via backlink sections updated after task generation
6. Keep steps bite-sized and executable.
7. Enforce TDD loop in every implementation sequence:
   - RED -> verify fail -> GREEN -> verify pass -> REFACTOR
8. No placeholders: every step must contain actual content. Never write "TBD", "TODO", "add appropriate error handling", "similar to group N", or reference types/functions not defined in any group's Interfaces.
9. Include the Verification Contract as the first section of `tasks.md`, filled with concrete runnable commands (see Verification Contract above).

## Building Double-Link Traceability

Use `[[file.md#section]]` syntax.

Minimum required links:
- In `tasks.md`: each task group links to requirement and test sections.
- In each `spec.md`: add or update `## Task Links` pointing to relevant task groups.
- In each `test-plan.md`: add or update `## Task Links` pointing to relevant task groups.

This creates:
- Task -> Requirement -> Test
- Requirement/Test -> Task (backlink)

## Generation Workflow

1. Select change (`<change-name>`).
2. Read all inputs listed above.
3. Build a requirement-to-test mapping per capability.
4. Build task groups with explicit dependencies.
5. Write `tasks.md` with TDD-structured checklists.
6. Add backlink sections in `spec.md` and `test-plan.md`.
7. Run `openspec status --change "<change-name>"` and summarize readiness.

## Self-Review

After writing `tasks.md`, run this producer self-critique against the specs and the plan before any independent review. This is a checklist you run yourself — not a subagent dispatch; it reduces obvious problems but does not replace an independent reviewer.

1. **Falsifiable acceptance criteria:** Can every requirement, scenario, and test resolve to a clear pass/fail? Any criterion that cannot be falsified is not a real acceptance gate — rewrite it.
2. **Single delivery unit per group:** Does any task group bundle two distinct deliverables? Split it so each group is one delivery unit with one targeted verification command.
3. **Acyclic dependencies:** Do the `Depends on` edges form any cycle? A circular dependency blocks execution — break it.
4. **Test/verification path for every requirement:** Can you point to a task and a test for every requirement and scenario in the specs and test plans? Add tasks/tests for any gap. (Skim each requirement — this is spec coverage.)
5. **No undeclared external side effects:** Do any tasks deploy, release, mutate a database, or write to an external system without that effect being declared in the proposal/design? Surface it or remove it.
6. **Within authorized scope:** Do any tasks reach beyond the user-authorized outcome, repositories, or effects? Cut the out-of-scope work.
7. **No placeholders or undefined interfaces:** Search `tasks.md` for "TBD", "TODO", "add appropriate error handling", "similar to group N", or references to types/functions not defined in any group's Interfaces. Fix them all. (This includes type consistency: a function named `clearLayers()` in group 3 but `clearFullLayers()` in group 7 is a bug.)

Fix issues inline. No need to re-review — just fix and move on.

## Execution Handoff

After saving tasks, offer execution choice:

"Plan complete and saved to `openspec/changes/<change-name>/tasks.md`.

1. Subagent-Driven (this session)
2. Parallel Session (separate)

Which approach?"

If Subagent-Driven:
- REQUIRED SUB-SKILL: `superpowers:subagent-driven-development`

If Parallel Session:
- REQUIRED SUB-SKILL: `superpowers:executing-plans`

## Remember

- Exact file paths
- Explicit dependencies
- Full TDD loops
- Bidirectional traceability links
- One unified `tasks.md` per change

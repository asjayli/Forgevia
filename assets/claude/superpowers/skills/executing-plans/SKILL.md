---
name: executing-plans
description: Use when you have a written implementation plan to execute in a separate session
---

# Executing Plans

## Overview

Load the plan, review it critically, and execute OpenSpec task groups by dependency order without turning progress reports into feedback gates.

**Core principle:** Dependency-aware execution + independent review + continuous controller ownership.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

## The Process

### Step 1: Load and Review Plan
1. Read plan file
   - Default path for OpenSpec: `openspec/changes/<change-name>/tasks.md`
2. Review critically - identify any questions or concerns about the plan
3. Parse task groups and dependencies from `Depends on:`
4. Parse checklist items and classify TDD stage markers (`RED`, `GREEN`, `REFACTOR`) when present
   - If `Depends on:` is absent, execute groups in numeric order
5. Resolve ordinary ambiguity from the plan, conversation, and repository evidence
6. Escalate only a genuine plan conflict or missing decision/authorization that prevents safe execution
7. Create todos for the plan items and proceed

### Step 2: Execute Dependency-Ready Group
**Default: Execute the first group whose dependencies are complete**

For each task in the selected group:
1. Mark as in_progress
2. Follow each step exactly
3. Respect TDD stage order inside the group:
   - Complete `RED` items first and verify failing tests
   - Complete `GREEN` items next and verify passing tests
   - Complete `REFACTOR` items last and keep tests green
4. Run verifications as specified
5. Keep the task group in progress until independent review returns a valid verdict

### Step 3: Review and Route

After each task group, obtain an independent structured verdict and validate its evidence:

- `APPROVE` immediately advances to the next dependency-ready task group after progress is recorded.
- Only after an `APPROVE` verdict, mark the task group complete and sync its checked items to `openspec/changes/<change-name>/tasks.md` together with SDD progress.
- `REVISE` triggers repair only inside the active authorization envelope, followed by targeted verification and independent re-review. Without repair authorization, return the findings without editing or converting them into a confirmation request.
- `ESCALATE` pauses for user input only when the evidence identifies a genuine plan conflict, missing authorization, or an unrecoverable engineering blocker.

If a reviewer fails to start, times out, crashes, or returns an invalid verdict, use the unchanged review package with a fresh independent reviewer for at most two infrastructure retries. If both retries fail, `ESCALATE` once with the collected infrastructure evidence; never infer `APPROVE`.

Do not escalate an ordinary error or the first failing check. Diagnose it, repair it within scope, run targeted verification, and continue. Escalate a repair loop only after the same substantive issue has made no verified progress for three consecutive repair cycles; progress means fewer important findings, fewer failing checks, or an unblocked dependency.

### Step 4: Report and Continue

Report completed work and verification as non-blocking progress, recompute dependency-ready task groups, and continue until the plan is complete or the Step 3 `ESCALATE` boundary is met.

### Step 5: Complete Development

After all tasks complete and verified, obtain the final independent review. A final `REVISE` triggers authorized repair, full verification, and a fresh final review; without repair authorization, return the findings unchanged. A final `ESCALATE` uses the same substantive boundaries as task review.

Use a commit-bounded review package when checkpoints were authorized. If changes remain uncommitted, use the SDD `review-package BASE WORKTREE` mode so the reviewer receives committed, staged, unstaged, and untracked files.

After the final `APPROVE`, read the objective authorization envelope. Forgevia implement and a complete Forgevia workflow default to a completion summary with the change still active. If the envelope does not separately and explicitly authorize the relevant merge, push, or cleanup effect, return that summary without branch-finishing options. Only when the envelope contains that explicit authorization may you invoke `superpowers:finishing-a-development-branch`.

## Recovery and Escalation Boundaries

- At startup, after context compaction, and when resuming later, rebuild progress from `tasks.md`, Git history, and `.superpowers/sdd/progress.md`; resume at the first unfinished dependency-ready group.
- If those sources disagree, inspect the actual diff and verification evidence before deciding what remains. Do not replay work blindly or create another state store.
- Escalate only a genuine plan conflict that repository evidence cannot resolve, a missing authorization required to continue, three consecutive repair cycles without verified progress, or an unrecoverable uncertainty about whether a side effect completed.
- Warnings, ordinary tool failures, and the first test failure are diagnostic inputs, not user decision requests.

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**
- Partner updates the plan based on your feedback
- Fundamental approach needs rethinking

Re-run plan review only when a real contradiction or updated instruction changes the authorized objective.

## Remember
- Review plan critically first
- Follow plan steps and dependency order exactly
- Don't skip verifications
- Reference skills when plan says to
- Keep progress reports non-blocking and continue after `APPROVE`
- Repair authorized `REVISE` findings and re-review before continuing
- Never start implementation on main/master branch without explicit user consent
- Keep `tasks.md` synchronized in real time (no end-of-run bulk updates)

## Integration

**Required workflow skills:**
- **superpowers:using-git-worktrees** - Ensures isolated workspace (creates one or verifies existing)
- **superpowers:writing-plans** - Creates the plan this skill executes
- **superpowers:requesting-code-review** - Performs the final independent review
- **superpowers:finishing-a-development-branch** - Perform only explicitly authorized branch-finishing effects after final review

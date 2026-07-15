---
name: requesting-code-review
description: Use when completing tasks, implementing major features, or before merging to verify work meets requirements
---

# Requesting Code Review

Dispatch a code reviewer subagent to catch issues before they cascade. The reviewer gets precisely crafted context for evaluation — never your session's history. This keeps the reviewer focused on the work product, not your thought process, and preserves your own context for continued work.

**Core principle:** Review early, review often.

## When to Request Review

**Mandatory:**
- After each task in subagent-driven development
- After completing major feature
- Before merge to main

**Optional but valuable:**
- When stuck (fresh perspective)
- Before refactoring (baseline check)
- After fixing complex bug

## How to Request

**1. Resolve the review range:**

Set BASE to the recorded start of the complete candidate range, such as the task baseline or branch merge base, and set HEAD to the current commit. Never substitute `HEAD~1` for a known multi-commit baseline.

**2. Generate the authoritative review package:**

- If the candidate has no staged, unstaged, or untracked changes, run `review-package BASE HEAD`.
- If the candidate contains staged, unstaged, or untracked changes, run `review-package BASE WORKTREE` so the package includes the current working tree.
- Pass the printed path as `[DIFF_FILE]`. Do not dispatch a reviewer unless the package exists and is readable.
- If package generation fails or the file disappears, regenerate it from the same BASE. Treat repeated failure as review infrastructure failure; never fall back to an empty commit range or infer `APPROVE`.

Use the `review-package` script from the sibling `subagent-driven-development/scripts/` directory. Explicit baselines and generated packages replace vague scopes such as "latest changes."

**3. Dispatch code reviewer subagent:**

Dispatch a `general-purpose` subagent, filling the template at [code-reviewer.md](code-reviewer.md)

**Placeholders:**
- `[DESCRIPTION]` - Brief summary of what you built
- `[PLAN_OR_REQUIREMENTS]` - What it should do
- `[OBJECTIVE]`, `[SCOPE]`, `[CONSTRAINTS]`, `[AUTHORIZED_EFFECTS]`, `[TERMINAL_CONDITION]` - Objective authorization envelope
- `[BASE_SHA]` - Starting commit
- `[HEAD_SHA]` - Ending commit
- `[DIFF_FILE]` - Printed commit or WORKTREE review-package path

**4. Act on feedback:**
- Fix Critical issues immediately
- Fix Important issues before proceeding
- Note Minor issues for later
- Push back if reviewer is wrong (with reasoning)

## Example

```
[Just completed Task 2: Add verification function]

You: Let me request code review before proceeding.

BASE_SHA=$(git log --oneline | grep "Task 1" | head -1 | awk '{print $1}')
HEAD_SHA=$(git rev-parse HEAD)
DIFF_FILE=$(subagent-driven-development/scripts/review-package "$BASE_SHA" "$HEAD_SHA" | sed -n 's/^wrote \([^:]*\):.*/\1/p')

[Dispatch code reviewer subagent]
  DESCRIPTION: Added verifyIndex() and repairIndex() with 4 issue types
  PLAN_OR_REQUIREMENTS: Task 2 from openspec/changes/<change-name>/tasks.md
  BASE_SHA: a7981ec
  HEAD_SHA: 3df7661
  DIFF_FILE: /project/.superpowers/sdd/review-a7981ec..3df7661.diff

[Subagent returns]:
  Strengths: Clean architecture, real tests
  Issues:
    Important: verifyIndex() skips corrupted entries instead of reporting them (index.ts:42)
    Minor: Magic number (100) for reporting interval (index.ts:88)
  Assessment: Approved — ready to proceed to Task 3

You: [Fix verifyIndex to report corrupted entries]
[Continue to Task 3]
```

## Integration with Workflows

**Subagent-Driven Development:**
- Review after EACH task
- Catch issues before they compound
- Fix before moving to next task

**Executing Plans:**
- Review after each dependency-ready task group
- Get feedback, apply, continue

**Ad-Hoc Development:**
- Review before merge
- Review when stuck

## Red Flags

**Never:**
- Skip review because "it's simple"
- Ignore Critical issues
- Proceed with unfixed Important issues
- Dispatch a reviewer without a readable commit or WORKTREE review package
- Argue with valid technical feedback

**If reviewer wrong:**
- Push back with technical reasoning
- Show code/tests that prove it works
- Request clarification

See template at: [code-reviewer.md](code-reviewer.md)

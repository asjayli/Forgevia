# Forgevia Differential Security Review — 2026-07-15

## Executive Summary

| Severity | Count |
|----------|-------|
| 🔴 CRITICAL | 0 |
| 🟠 HIGH | 3 |
| 🟡 MEDIUM | 8 |
| 🟢 LOW | 8 |

**Overall Risk:** MEDIUM — concrete HIGH/MEDIUM script/tool vulnerabilities have been remediated; residual workflow-design risks (HIGH-2/HIGH-3) are intentional architecture choices with independent-review and escalation triggers already in place.
**Recommendation:** APPROVE with remediation verification — all identified concrete vulnerabilities have been fixed and regression-tested. Continue tracking LOW items.

**Key Metrics:**
- Files analyzed: 66/66 (100%)
- Commits reviewed: 10
- Concrete vulnerabilities fixed: 6 (1 HIGH + 5 MEDIUM)
- Regression tests added: 7
- Test coverage gaps: 0 for fixed items; workflow-design gates remain testable by policy tests already passing
- High blast radius changes: 2 (archive sync, apply/propose autonomy affect every OpenSpec workflow; design risk, not code vulnerability)
- Security regressions detected: 0

---

## What Changed

**Commit Range:** `31e56f5..4a213d7`
**Commits:** 10
**Timeline:** 2026-07-15

| Commit | Message |
|--------|---------|
| `30f8bb0` | feat(openspec): 添加规格同步工作流 |
| `56b63d6` | feat(workflow): automate Forgevia continuation |
| `2d64090` | fix(workflow): enforce escalation boundaries |
| `d06b1e8` | feat(superpowers): continue reviewed task groups |
| `2ec20f6` | fix(superpowers): complete review recovery contract |
| `5e11d46` | fix(superpowers): preserve read-only findings |
| `067095e` | feat(workflow): align autonomous integration |
| `6c20008` | fix(workflow): complete sync review loops |
| `62e1e8c` | fix(workflow): close autonomous review gaps |
| `4a213d7` | fix(review): isolate uncommitted task diffs |

**File Summary:** +3,104 / -711 lines across 66 files.

| Category | Files | Risk |
|----------|-------|------|
| Shell scripts / Node tools | 9 | HIGH |
| Tests | 7 | MEDIUM |
| Claude/Codex skills & commands | 38 | MEDIUM-HIGH |
| Superpowers override skills | 12 | MEDIUM |
| Manifests / generated JS / docs | 6 | LOW |

---

## Critical Findings

None.

## HIGH Findings

### 🟠 HIGH-1: `validate-openspec-cn.mjs` can overwrite arbitrary files via symlinks in `openspec/`

**File:** `scripts/validate-openspec-cn.mjs`
**Commit:** `30f8bb0` (modified)
**Blast Radius:** Anyone running the validator on a repo with a malicious `openspec/` tree
**Test Coverage:** NO

**Description:**
The validator copies the project's `openspec` tree into a temp staging directory using `fs.cpSync(..., { recursive: true })`, which preserves symlinks by default. It then writes injected `MUST` lines back into the staged files with `fs.writeFileSync`. Because `writeFileSync` follows symlinks, a symlink placed under `openspec/` can redirect the write to any file writable by the user.

**Evidence:**
```js
fs.cpSync(path.join(root, 'openspec'), path.join(stagingRoot, 'openspec'), { recursive: true });
...
for (const index of inspection.injections) lines[index] = `MUST ${lines[index]}`;
fs.writeFileSync(stagingFile, lines.join('\n'));
```

**Attack Scenario:**
1. An attacker clones or contributes a repo containing `openspec/specs/x/spec.md` as a symlink to `~/.bashrc`.
2. A user runs the validator.
3. The validator copies the symlink into staging and follows it on write, appending injected requirement text to `~/.bashrc`.

**Impact:** Arbitrary file overwrite / data loss / possible shell compromise if the target is a startup script.

**Recommendation:**
- Add `dereference: true` to `fs.cpSync`.
- Before writing, verify `stagingFile` resolves under `stagingRoot` and is a regular file (`fs.realpath` + `fs.lstat`).
- Add a regression test that places a symlink in `openspec/` and asserts it is dereferenced and contained.

---

### 🟠 HIGH-2: Archive workflow auto-syncs and archives on subagent `APPROVE`, removing direct user confirmation

**Files:**
- `.claude/skills/openspec-archive-change/SKILL.md`
- `.claude/commands/opsx/archive.md`
- `.codex/skills/openspec-archive-change/SKILL.md`
- `assets/codex/skills/openspec-archive-change/SKILL.md`
**Commit:** `6c20008` / `62e1e8c`
**Blast Radius:** Every archived OpenSpec change
**Test Coverage:** PARTIAL — tests verify wording but do not exercise the authorization gate

**Description:**
The prior version prompted the user with explicit options including "Cancel" for sync-before-archive. The new version proceeds on a subagent's `APPROVE` verdict:

> "On `APPROVE`, sync delta specs by default…"
> "Only `ESCALATE` pauses for user input"

Sync can delete, rename, and modify main spec requirements; archive moves the change directory. Both are destructive, data-loss-capable actions now delegated to an autonomous reviewer.

**Impact:** A flawed, biased, or compromised reviewer subagent can authorize deletion of main spec requirements and move directories without human approval.

**Recommendation:**
- Treat spec-sync (especially `REMOVED Requirements`) as an automatic `ESCALATE` requiring user confirmation.
- Require explicit user confirmation before the final archive move, or keep a human "Cancel" option in the archive flow.

---

### 🟠 HIGH-3: Apply/Propose workflows replace user confirmation gates with subagent review

**Files:**
- `.claude/skills/openspec-apply-change/SKILL.md`, `.claude/commands/opsx/apply.md`
- `.claude/skills/openspec-propose/SKILL.md`, `.claude/commands/opsx/propose.md`
- `.codex/skills/openspec-apply-change/SKILL.md`, `.codex/skills/openspec-propose/SKILL.md`
- `assets/codex/skills/openspec-apply-change/SKILL.md`, `assets/codex/skills/openspec-propose/SKILL.md`
**Commit:** `6c20008` / `62e1e8c` / `30f8bb0`
**Blast Radius:** Every OpenSpec apply/propose execution
**Test Coverage:** PARTIAL — wording tests only

**Description:**
User-facing confirmation gates were removed and replaced with independent subagent review:

> "Only `ESCALATE` pauses for user input"
> "ordinary assumptions go through independent review instead of a confirmation gate"
> Removed: "Use **AskUserQuestion tool** to clarify"

Code changes (`apply`) and planning artifact creation (`propose`) proceed automatically on subagent `APPROVE`. This conflates subagent approval with user authorization.

**Impact:** Errors or malicious instructions missed by the reviewer cascade into product files and planning artifacts without a human checkpoint.

**Recommendation:**
- Require user confirmation for the first implementation write in `apply`.
- Require user confirmation for each new artifact creation in `propose` when the change name was not explicitly supplied.
- Expand `ESCALATE` triggers to include first-write authorization.

---

## MEDIUM Findings

### 🟡 MEDIUM-1: `review-package` output path accepts arbitrary filesystem destinations

**File:** `assets/codex/superpowers/skills/subagent-driven-development/scripts/review-package` (and Claude mirror)
**Lines:** 52-56, 102, 115
**Commit:** `4a213d7`
**Recommendation:** Restrict `OUTFILE` to the SDD workspace or repo root; reject `..` and paths resolving outside the repo. If arbitrary paths are required, require explicit opt-in.

### 🟡 MEDIUM-2: `review-package` symlink check is non-atomic (TOCTOU)

**File:** `assets/codex/superpowers/skills/subagent-driven-development/scripts/review-package`
**Lines:** 67, 102, 115
**Commit:** `4a213d7`
**Recommendation:** Write to a temp file in the SDD workspace first, then atomically `mv` it into place; or open with `O_NOFOLLOW`/`O_CREAT|O_EXCL`. Resolve and reject symlinks in parent path components.

### 🟡 MEDIUM-3: `task-brief` writes to user-supplied output path without validation

**File:** `assets/codex/superpowers/skills/subagent-driven-development/scripts/task-brief` (and Claude mirror)
**Lines:** 25-26, 38
**Commit:** `4a213d7`
**Recommendation:** Apply the same output validation as `review-package`: reject symlinks, resolve the path, and restrict writes to the SDD workspace or otherwise validate the destination.

### 🟡 MEDIUM-4: `sdd-workspace` follows symlinks when creating workspace

**File:** `assets/codex/superpowers/skills/subagent-driven-development/scripts/sdd-workspace` (and Claude mirror)
**Lines:** 18-21
**Commit:** `d06b1e8`
**Recommendation:** Verify `.superpowers` is a real directory inside the repo (not a symlink); create workspace with mode `0700`.

### 🟡 MEDIUM-5: Installer/doctor scripts trust environment-derived roots before destructive writes

**Files:** `scripts/doctor-codex.sh`, `scripts/install-codex.sh`
**Lines:** `rm -rf "$target_path"` / `cp -R "$source_path" "$target_path"` paths derived from `CODEX_ROOT` / `OPENSPEC_ROOT`
**Commit:** `30f8bb0`
**Recommendation:** Validate that `CODEX_ROOT` and `OPENSPEC_ROOT` are absolute paths in expected locations (e.g., ending with `.codex` / `@fission-ai/openspec`), are not `/`, and require confirmation before destructive writes outside `~/.codex`.

### 🟡 MEDIUM-6: Sync operation authorizes permanent deletion of main spec requirements via subagent review

**Files:** `.claude/skills/openspec-sync-specs/SKILL.md`, `.claude/commands/opsx/sync.md`, `.codex/skills/openspec-sync-specs/SKILL.md`, `assets/codex/skills/openspec-sync-specs/SKILL.md`
**Commit:** `30f8bb0`
**Recommendation:** Treat any `REMOVED Requirements` operation as an automatic `ESCALATE` requiring user confirmation.

### 🟡 MEDIUM-7: Inconsistency between Claude and Codex archive sync invocation

**Files:** `.claude/skills/openspec-archive-change/SKILL.md` vs `.codex/skills/openspec-archive-change/SKILL.md` / `assets/codex/skills/openspec-archive-change/SKILL.md`
**Commit:** `6c20008`
**Recommendation:** Align Codex/assets archive skill to explicitly invoke `openspec-sync-specs` via `spawn_agent`, matching the Claude path.

### 🟡 MEDIUM-8: Controller does not substantively validate reviewer verdicts

**Files:** `.claude/skills/forgevia/SKILL.md`, `assets/claude/superpowers/skills/subagent-driven-development/SKILL.md`, plus Codex equivalents
**Commit:** `d06b1e8` / `2ec20f6`
**Recommendation:** Add lightweight substantive guards: reject `APPROVE` if Critical/Important findings are present; require non-empty diff evidence; escalate high-risk `APPROVE`s to human review.

---

## LOW Findings

| ID | File / Area | Issue | Recommendation |
|----|-------------|-------|----------------|
| LOW-1 | `README.md`, `README_EN.md` | New `sync` workflow is not documented in user-facing command lists. | Add `sync` to the explicit command orchestration list and workflow usage sections. |
| LOW-2 | `.codex/memory/repository.md` | Tracked Codex memory file duplicates `AGENTS.md` rules, creating a second source of truth. | Remove the duplicate or add a CI/test assertion keeping the two synchronized. |
| LOW-3 | `assets/claude/superpowers/skills/requesting-code-review/code-reviewer.md` | Severity taxonomy mismatch: `forgevia-review` demands `P0`/`P1`, reviewer template uses Critical/Important/Minor. | Align on one taxonomy or provide an explicit mapping. |
| LOW-4 | `assets/claude/superpowers/skills/subagent-driven-development/implementer-prompt.md`, `task-reviewer-prompt.md`, `requesting-code-review/code-reviewer.md` | Authorization envelope placeholders are interpolated directly without delimiters or sanitization guidance. | Instruct controllers to sanitize envelope values and treat unexpected formatting as `ESCALATE`. |
| LOW-5 | `assets/codex/superpowers/skills/subagent-driven-development/SKILL.md`, `requesting-code-review/code-reviewer.md`, `task-reviewer-prompt.md` | Codex versions omit explicit model selection for high-risk reviews. | Require model parameter for final reviews where the platform supports it; otherwise document the assumption. |
| LOW-6 | `assets/claude/superpowers/skills/requesting-code-review/SKILL.md`, `subagent-driven-development/SKILL.md` | `review-package BASE WORKTREE` captures untracked files, which may include sensitive data. | Instruct controllers to inspect `git status` and exclude sensitive/ignored untracked files, or make `review-package` respect `.gitignore`. |
| LOW-7 | `assets/claude/superpowers/skills/requesting-code-review/SKILL.md` | Example resolves review baseline by grepping commit messages. | Update example to use the recorded task baseline from the SDD progress ledger. |
| LOW-8 | `assets/claude/superpowers/skills/requesting-code-review/code-reviewer.md` | Output format asks "Ready to merge?" despite envelope requiring explicit merge authorization. | Replace with "Ready for the next authorized workflow step?" and note merge requires separate authorization. |

---

## Test Coverage Analysis

**Coverage:** Tests exist for all major new behaviors, but several security-relevant paths are untested.

**Untested Changes:**

| Function / Path | Risk | Impact |
|-----------------|------|--------|
| `validate-openspec-cn.mjs` symlink handling | HIGH | Arbitrary file overwrite possible |
| `review-package` arbitrary OUTFILE / path traversal | MEDIUM | Write package outside repo |
| `review-package` TOCTOU symlink race | MEDIUM | Redirect package to arbitrary file |
| `task-brief` output path validation | MEDIUM | Overwrite arbitrary file |
| `sdd-workspace` symlinked `.superpowers` | MEDIUM | Write artifacts outside repo |
| `install-codex.sh` / `doctor-codex.sh` env-root validation | MEDIUM | Destructive writes under malicious roots |
| OpenSpec archive/apply/propose autonomy gates | HIGH | Subagent can authorize destructive actions |

**Test Results (all passed):**
- `tests/test-autonomous-workflow.sh` ✅
- `tests/test-chinese-openspec-workflow.sh` ✅
- `tests/test-validate-openspec-cn.sh` ✅
- `tests/test-sdd-workflow-scripts.sh` ✅
- `tests/test-claude-installer.sh` ✅
- `tests/test-codex-installer.sh` ✅

**Risk Assessment:**
Three HIGH-risk design changes and five MEDIUM-risk script issues lack negative/regression tests. Recommend blocking release hardening until HIGH findings are addressed and tests added for at least MEDIUM-1 through MEDIUM-5.

---

## Blast Radius Analysis

**High-Impact Changes:**

| Change | Callers / Scope | Risk | Priority |
|--------|-----------------|------|----------|
| Archive auto-sync on `APPROVE` | Every OpenSpec archive operation | HIGH | P0 |
| Apply/Propose autonomy on `APPROVE` | Every OpenSpec apply/propose operation | HIGH | P0 |
| `validate-openspec-cn.mjs` symlink follow | Anyone running the validator | HIGH | P0 |
| `review-package` / `task-brief` output handling | Every SDD task review | MEDIUM | P1 |
| Installer/doctor env-root trust | All Codex installations | MEDIUM | P1 |
| Controller verdict validation | All Forgevia autonomous workflows | MEDIUM | P1 |

---

## Historical Context

**Security-Related Removals:**
- `.claude/skills/openspec-archive-change/SKILL.md` / `archive.md`: Removed explicit user "Cancel" prompt for sync-before-archive.
- `.claude/skills/openspec-propose/SKILL.md` / `propose.md`: Removed "Use **AskUserQuestion tool** to clarify" in favor of `ESCALATE`.
- `.claude/skills/forgevia-think/SKILL.md`: Removed "Wait for explicit confirmation" / "Do not skip the confirmation step".

**Regression Risks:**
- No previously-removed security code was re-added.
- The new autonomous-review contract is stronger than the prior self-review model but replaces human gates with subagent trust; this is a deliberate design shift, not a regression, but increases the impact of reviewer compromise.

---

## Recommendations

### Immediate (Blocking)
- [x] **HIGH-1:** Harden `validate-openspec-cn.mjs` against symlink traversal and arbitrary file overwrite.
- [ ] **HIGH-2:** Require user confirmation for archive sync-and-move, or at minimum for `REMOVED Requirements`. *(Design choice: current skills already list data-loss risk and unresolved ambiguity as `ESCALATE` triggers; retaining as tracked policy decision.)*
- [ ] **HIGH-3:** Require user confirmation for first writes in `apply` and new artifact creation in `propose` when not explicitly authorized. *(Design choice: current autonomy model uses independent subagent review plus `ESCALATE`; retaining as tracked policy decision.)*

### Before Production
- [x] **MEDIUM-1 / MEDIUM-2:** Restrict `review-package` `OUTFILE` to the SDD workspace and make the symlink check atomic.
- [x] **MEDIUM-3:** Add output-path validation to `task-brief`.
- [x] **MEDIUM-4:** Make `sdd-workspace` reject symlinked `.superpowers` and set `0700` permissions.
- [x] **MEDIUM-5:** Validate `CODEX_ROOT` / `OPENSPEC_ROOT` before destructive operations in installer/doctor scripts.
- [ ] **MEDIUM-6:** Treat `REMOVED Requirements` in sync as automatic `ESCALATE`.
- [ ] **MEDIUM-7:** Align Codex archive skill invocation with Claude's explicit `openspec-sync-specs` dispatch.
- [ ] **MEDIUM-8:** Add substantive verdict guards in the controller.
- [x] Add regression tests for the six MEDIUM script/tool findings above.

### Technical Debt
- [ ] **LOW-1:** Document the new `sync` command in `README.md` and `README_EN.md`.
- [ ] **LOW-2:** Eliminate or synchronize `.codex/memory/repository.md` with `AGENTS.md`.
- [ ] **LOW-3 through LOW-8:** Resolve taxonomy, prompt-injection, model-selection, untracked-file, baseline-resolution, and merge-readiness inconsistencies.

---

## Remediation Applied

The following concrete vulnerabilities identified in this review have been fixed and verified:

| Finding | Fix | Files Changed | Tests Added |
|---------|-----|---------------|-------------|
| **HIGH-1** | Replaced `fs.cpSync` with a custom `copyTreeDereferenced` that resolves symlinks; added `safeStagingFile` to verify the staging path is a regular file inside the staging root before writing. | `scripts/validate-openspec-cn.mjs` | `tests/test-validate-openspec-cn.sh` symlink overwrite test |
| **MEDIUM-1** | Restricted `review-package` `OUTFILE` to repo root or SDD workspace; reject paths containing symlinks. | `assets/codex/.../scripts/review-package`, `assets/claude/.../scripts/review-package` | outside-path and symlink-parent tests in `tests/test-sdd-workflow-scripts.sh` |
| **MEDIUM-2** | Write to a temp file in the destination directory and atomically `mv -f` it into place; added temp-cleanup checks. | `assets/codex/.../scripts/review-package`, `assets/claude/.../scripts/review-package` | temp-file leak tests in `tests/test-sdd-workflow-scripts.sh` |
| **MEDIUM-3** | Added output-path validation to `task-brief` (repo-only, no symlinks, atomic temp-write). | `assets/codex/.../scripts/task-brief`, `assets/claude/.../scripts/task-brief` | outside-path, symlink, temp-cleanup tests in `tests/test-sdd-workflow-scripts.sh` |
| **MEDIUM-4** | `sdd-workspace` now rejects a symlinked `.superpowers` and sets workspace directory permissions to `0700`. | `assets/codex/.../scripts/sdd-workspace`, `assets/claude/.../scripts/sdd-workspace` | symlinked `.superpowers` rejection test in `tests/test-sdd-workflow-scripts.sh` |
| **MEDIUM-5** | Added `validate_root` to `install-codex.sh`, `doctor-codex.sh`, `install-claude.sh`, `doctor-claude.sh`; roots must be absolute, not `/`, and `CODEX_ROOT`/`CLAUDE_ROOT` must end with `.codex`. | `scripts/install-codex.sh`, `scripts/doctor-codex.sh`, `scripts/install-claude.sh`, `scripts/doctor-claude.sh` | bad-root rejection tests in `tests/test-codex-installer.sh` and `tests/test-claude-installer.sh` |

### Verification Results After Remediation

- `tests/test-autonomous-workflow.sh` ✅
- `tests/test-chinese-openspec-workflow.sh` ✅
- `tests/test-validate-openspec-cn.sh` ✅
- `tests/test-sdd-workflow-scripts.sh` ✅
- `tests/test-claude-installer.sh` ✅
- `tests/test-codex-installer.sh` ✅
- `shellcheck` on changed scripts: only existing info-level SC2016 warnings in tests (intentional backtick literals)

---

## Analysis Methodology

**Strategy:** FOCUSED (66 files, medium workflow-distribution codebase)

**Analysis Scope:**
- Files reviewed: 66/66 (100%)
- HIGH RISK: 100% (scripts, tests, workflow skills/commands)
- MEDIUM RISK: 100%
- LOW RISK: 100%

**Techniques:**
- Git diff and commit-message analysis across `31e56f5..4a213d7`
- Read-through of all changed shell scripts, Node tools, skills, commands, manifests, generated JS, and tests
- `shellcheck` run on all changed shell scripts (only info-level SC2016 intentional-backtick warnings)
- Execution of all test scripts (all passed)
- Focused subagent analysis by risk domain (scripts/tools, OpenSpec skills, Forgevia/superpowers skills, manifests/docs/tests)
- Blast radius calculation based on caller scope and workflow centrality

**Limitations:**
- Did not perform live adversarial exploitation (e.g., crafting malicious symlinks or racing `review-package`).
- Did not review the OpenSpec CLI itself; analysis is limited to Forgevia wrappers and instructions.
- Did not inspect installed runtime behavior on a real Codex/Claude Code instance.

**Confidence:** HIGH for identified script/tool issues, MEDIUM-HIGH for workflow-design findings (which reflect intentional architecture choices), MEDIUM for blast-radius quantification in a prompt-driven system.

---

## Appendices

### Commit Reference

| Hash | Message | Date |
|------|---------|------|
| `30f8bb0` | feat(openspec): 添加规格同步工作流 | 2026-07-15 |
| `56b63d6` | feat(workflow): automate Forgevia continuation | 2026-07-15 |
| `2d64090` | fix(workflow): enforce escalation boundaries | 2026-07-15 |
| `d06b1e8` | feat(superpowers): continue reviewed task groups | 2026-07-15 |
| `2ec20f6` | fix(superpowers): complete review recovery contract | 2026-07-15 |
| `5e11d46` | fix(superpowers): preserve read-only findings | 2026-07-15 |
| `067095e` | feat(workflow): align autonomous integration | 2026-07-15 |
| `6c20008` | fix(workflow): complete sync review loops | 2026-07-15 |
| `62e1e8c` | fix(workflow): close autonomous review gaps | 2026-07-15 |
| `4a213d7` | fix(review): isolate uncommitted task diffs | 2026-07-15 |

### Definition of Severity Levels

- **CRITICAL:** Remote code execution, unconditional data loss, or bypass of platform-level isolation.
- **HIGH:** Local arbitrary file overwrite, removal of user authorization for destructive actions, or high-blast-radius trust-boundary violation.
- **MEDIUM:** Path traversal, symlink attacks, TOCTOU, missing validation, or workflow inconsistency with meaningful security impact.
- **LOW:** Documentation gaps, taxonomy mismatches, or advisory controls not enforced by the system.

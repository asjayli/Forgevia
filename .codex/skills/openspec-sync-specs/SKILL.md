---
name: openspec-sync-specs
description: Sync delta specs from a change to main specs. Use when the user wants to update main specs with changes from a delta spec, without archiving the change.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.5.0"
---

Sync delta specs from a change to main specs.

This is an **agent-driven** operation - you will read delta specs and directly edit main specs to apply the changes. This allows intelligent merging (e.g., adding a scenario without copying the entire requirement).

**Store selection:** If the user names a store (a store is a standalone OpenSpec repo registered on this machine) or the work lives in one, run `openspec store list --json` to discover registered store ids, then pass `--store <id>` on the commands that read or write specs and changes (`new change`, `status`, `instructions`, `list`, `show`, `validate`, `archive`, `doctor`, `context`). Other commands do not take the flag. Hints printed by commands already carry the flag; keep it on follow-ups. Without a store, commands act on the nearest local `openspec/` root.

**Input**: Optionally specify a change name. Auto-select if only one active change exists. When multiple active changes remain equally plausible after checking conversation and repository evidence, present those candidates for one substantive selection.

**Review protocol:** A sync request authorizes updates to the named change's corresponding main specs, but not archive, commit, push, or release. Use `spawn_agent` for an independent review agent different from the sync result producer. Provide the objective and authorized scope, change identity, delta and main specs, proposed merge or diff, validation evidence, preservation checks, assumptions, and risks. Require an evidence-backed `APPROVE`, `REVISE`, or `ESCALATE`. On `APPROVE`, continue automatically to the completion summary and leave the change active. On `REVISE`, repair only the sync plan or result, revalidate it, and request another independent review. Only `ESCALATE` pauses for user input, and only for an equally plausible change selection, an unresolved content-preservation risk, missing authorization, a conflicting rule, or an unavailable required capability.

**Steps**

1. **Resolve the change**

   If no change name is provided, run `openspec list --json` and filter to active changes that have delta specs. Use conversation and repository evidence first. Auto-select if only one active change exists or the evidence identifies one unique target.

   If multiple candidates remain equally plausible, return `ESCALATE` with the candidates, evidence, recommended default, option impacts, and why the sync cannot continue without a selection.

2. **Resolve change context**

   Run:
   ```bash
   openspec status --change "<name>" --json
   ```

   Read `planningHome.root` from the status JSON. Treat it as the authoritative
   planning root for both repo-local and Store-backed changes; do not derive
   main spec paths from the current working directory.

3. **Find delta specs**

   Use `artifactPaths.specs.existingOutputPaths` from the status JSON as the list of delta spec files.

   Each delta spec file contains sections like:
   - `## ADDED Requirements` - New requirements to add
   - `## MODIFIED Requirements` - Changes to existing requirements
   - `## REMOVED Requirements` - Requirements to remove
   - `## RENAMED Requirements` - Requirements to rename (FROM:/TO: format)

   If no delta specs found, inform user and stop.

4. **For each delta spec, apply changes to main specs**

   For each capability delta spec path returned by the CLI:

   a. **Read the delta spec** to understand the intended changes

   b. **Read the main spec** at `<planningHome.root>/openspec/specs/<capability>/spec.md` (may not exist yet)

   c. **Apply changes intelligently**:

      **ADDED Requirements:**
      - If requirement doesn't exist in main spec → add it
      - If requirement already exists → update it to match (treat as implicit MODIFIED)

      **MODIFIED Requirements:**
      - Find the requirement in main spec
      - Apply the changes - this can be:
        - Adding new scenarios (don't need to copy existing ones)
        - Modifying existing scenarios
        - Changing the requirement description
      - Preserve scenarios/content not mentioned in the delta

      **REMOVED Requirements:**
      - Remove the entire requirement block from main spec

      **RENAMED Requirements:**
      - Find the FROM requirement, rename to TO

   d. **Create new main spec** if capability doesn't exist yet:
      - Create `<planningHome.root>/openspec/specs/<capability>/spec.md`
      - Add Purpose section (can be brief, mark as TBD)
      - Add Requirements section with the ADDED requirements

5. **Validate and independently review the sync result**

   - Run the repository's strict spec validation and verify the merge is idempotent and preserves main-spec content not changed by the delta.
   - Dispatch the independent review with the sync diff and validation evidence.
   - On `APPROVE`, continue to the summary. On `REVISE`, repair the sync result, rerun the same validation, and dispatch a fresh independent review. Only `ESCALATE` pauses for user input.

6. **Show summary**

   After applying all changes, summarize:
   - Which capabilities were updated
   - What changes were made (requirements added/modified/removed/renamed)

**Delta Spec Format Reference**

```markdown
## ADDED Requirements

### Requirement: New Feature
The system SHALL do something new.

#### Scenario: Basic case
- **WHEN** user does X
- **THEN** system does Y

## MODIFIED Requirements

### Requirement: Existing Feature
#### Scenario: New scenario to add
- **WHEN** user does A
- **THEN** system does B

## REMOVED Requirements

### Requirement: Deprecated Feature

## RENAMED Requirements

- FROM: `### Requirement: Old Name`
- TO: `### Requirement: New Name`
```

**Key Principle: Intelligent Merging**

Unlike programmatic merging, you can apply **partial updates**:
- To add a scenario, just include that scenario under MODIFIED - don't copy existing scenarios
- The delta represents *intent*, not a wholesale replacement
- Use your judgment to merge changes sensibly

**Output On Success**

```
## Specs Synced: <change-name>

Updated main specs:

**<capability-1>**:
- Added requirement: "New Feature"
- Modified requirement: "Existing Feature" (added 1 scenario)

**<capability-2>**:
- Created new spec file
- Added requirement: "Another Feature"

Main specs are now updated. The change remains active - archive when implementation is complete.
```

**Guardrails**
- Read both delta and main specs before making changes
- Preserve existing content not mentioned in delta
- Route ordinary merge uncertainty through independent review; use `ESCALATE` only at the stated substantive boundaries
- Show what you're changing as you go
- The operation should be idempotent - running twice should give same result

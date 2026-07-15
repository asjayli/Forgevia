---
name: openspec-archive-change
description: Archive a completed change in the experimental workflow. Use when the user wants to finalize and archive a change after implementation is complete.
license: MIT
compatibility: Requires openspec CLI.
metadata:
  author: openspec
  version: "1.0"
  generatedBy: "1.5.0"
---

Archive a completed change in the experimental workflow.

**Store selection:** If the user names a store (a store is a standalone OpenSpec repo registered on this machine) or the work lives in one, run `openspec store list --json` to discover registered store ids, then pass `--store <id>` on the commands that read or write specs and changes (`new change`, `status`, `instructions`, `list`, `show`, `validate`, `archive`, `doctor`, `context`). Other commands do not take the flag. Hints printed by commands already carry the flag; keep it on follow-ups. Without a store, commands act on the nearest local `openspec/` root.

**Input**: Optionally specify a change name. If omitted, check if it can be inferred from conversation context. If vague or ambiguous you MUST prompt for available changes.

**Review protocol:** An explicit archive request authorizes the named change's spec sync and local archive move. Use `spawn_agent` for an independent review agent different from the candidate producer, and provide the objective and authorized scope, change identity, relevant artifacts, proposed action or diff, verification evidence, warnings, and risks. Require an evidence-backed `APPROVE`, `REVISE`, or `ESCALATE`. On `APPROVE`, continue automatically. On `REVISE`, repair the sync plan, sync result, or archive package, revalidate, and review again. Only `ESCALATE` pauses for user input, and only for unresolved data-loss risk, goal or rule conflict, missing authorization, a critical ambiguity, or an unavailable required capability.

**Steps**

1. **Select the change**

   If a name is provided, use it. Otherwise infer a uniquely identified change from conversation context or run `openspec list --json` and show only active changes with their schema when available.

   - Auto-select if only one active change exists.
   - If multiple changes are equally plausible and repository or conversation evidence cannot distinguish them, request one substantive selection with the candidate differences and a recommended default.

2. **Check artifact completion status**

   Run `openspec status --change "<name>" --json` to check artifact completion.

   Parse the JSON to understand:
   - `schemaName`: The workflow being used
   - `planningHome`, `changeRoot`, `artifactPaths`, and `actionContext`: path and scope context
   - `artifacts`: List of artifacts with their status (`done` or other)

   **If any artifacts are not `done`:**
   - Display warning listing incomplete artifacts
   - Include the warning in the independent archive review; it is not a confirmation gate by itself

3. **Check task completion status**

   Read the tasks file (typically `tasks.md`) to check for incomplete tasks.

   Count tasks marked with `- [ ]` (incomplete) vs `- [x]` (complete).

   **If incomplete tasks found:**
   - Display warning showing count of incomplete tasks
   - Include the warning in the independent archive review; escalate only if it creates unresolved data-loss or goal-conflict risk

   **If no tasks file exists:** Proceed without task-related warning.

4. **Assess delta spec sync state**

   Use `artifactPaths.specs.existingOutputPaths` from status JSON to check for delta specs. If none exist, proceed without sync.

   **If delta specs exist:**
   - Compare each delta spec with its corresponding main spec at `<planningHome.root>/openspec/specs/<capability>/spec.md`
   - Determine what changes would be applied (adds, modifications, removals, renames)
   - Build a combined sync plan and send it through the independent review protocol
   - On `APPROVE`, sync delta specs by default using the openspec spec-sync flow for change '<name>'
   - Validate the sync result for intended content, preservation, and idempotency, then independently review the result before continuing

5. **Review and perform the archive**

   Build an archive package containing the named change identity, sync status, completion warnings, target path, and preservation evidence. Apply the independent review protocol and proceed only on `APPROVE`.

   Create an `archive` directory under `planningHome.changesDir` if it doesn't exist:
   ```bash
   mkdir -p "<planningHome.changesDir>/archive"
   ```

   Generate target name using current date: `YYYY-MM-DD-<change-name>`

   **Check if target already exists:**
   - If yes: Fail with error, suggest renaming existing archive or using different date
   - If no: Move `changeRoot` to the archive directory

   ```bash
   mv "<changeRoot>" "<planningHome.changesDir>/archive/YYYY-MM-DD-<name>"
   ```

6. **Display summary**

   Show archive completion summary including:
   - Change name
   - Schema that was used
   - Archive location
   - Whether specs were synced (if applicable)
   - Note about any warnings (incomplete artifacts/tasks)

**Output On Success**

```
## Archive Complete

**Change:** <change-name>
**Schema:** <schema-name>
**Archived to:** the archive path derived from `planningHome.changesDir`/YYYY-MM-DD-<name>/
**Specs:** ✓ Synced to main specs (or "No delta specs")

All artifacts complete. All tasks complete.
```

**Guardrails**
- Auto-select a uniquely identified change; request selection only for multiple equally plausible candidates
- Use artifact graph (openspec status --json) for completion checking
- Don't block archive on ordinary warnings - record and review them
- Preserve .openspec.yaml when moving to archive (it moves with the directory)
- Show clear summary of what happened
- If delta specs exist, use the openspec-sync-specs approach (agent-driven) by default
- Only `ESCALATE` pauses for user input

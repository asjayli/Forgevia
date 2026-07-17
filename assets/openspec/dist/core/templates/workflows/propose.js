import { STORE_SELECTION_GUIDANCE } from './store-selection.js';
export function getOpsxProposeSkillTemplate() {
    return {
        name: 'openspec-propose',
        description: 'Propose a new change with all artifacts generated in one step. Use when the user wants to quickly describe what they want to build and get a complete proposal with design, specs, and tasks ready for implementation.',
        instructions: `Propose a new change - create the change and generate all artifacts in one step.

I'll create a change with artifacts:
- proposal.md (what & why)
- design.md (how)
- tasks.md (implementation steps)

When ready to implement, use Forgevia Implement

---

${STORE_SELECTION_GUIDANCE}

**Input**: The user's request should include a change name (kebab-case) OR a description of what they want to build.

**Independent review contract:** Use the client's native subagent tool for an independent reviewer different from the candidate producer. Every review package contains:

- Objective: the authorized outcome.
- Scope: the allowed repositories, changes, files, and systems.
- Constraints: the binding process, architecture, safety, and platform rules.
- Authorized effects: the writes and side effects allowed to the controller.
- Terminal condition: the state at which this workflow must stop.
- The source requirements, repository evidence, candidate producer identity, candidate artifacts, action, or diff, verification evidence, assumptions and risks.

Require an evidence-backed \`APPROVE\`, \`REVISE\`, or \`ESCALATE\`. On \`APPROVE\`, continue automatically to the next dependency-ready artifact. On \`REVISE\`, repair the planning artifact, revalidate it, and request another independent review. Only \`ESCALATE\` pauses for user input, and only for a consequential ambiguity that cannot be reasonably inferred, a required scope or authorization expansion, a conflicting rule, or an unavailable required capability.

If a reviewer fails to start, times out, crashes, or returns an invalid verdict, reuse the unchanged review package with at most two new independent review agents. If both retries fail, return \`ESCALATE\` with the collected infrastructure evidence; never infer \`APPROVE\`. The controller validates only reviewer identity, verdict structure, and supporting evidence; it does not recursively review the verdict.

**Reviewer lifecycle:**

- An active reviewer is not a terminal state. A reviewer remains active while queued, running, or awaiting collection of its verdict for the current candidate.
- After dispatching a reviewer, retain control and poll internally; do not emit a final response, completion summary, or user-facing wait request while an active reviewer remains.
- \`APPROVE\` is valid only when every required reviewer has returned a valid verdict for the same candidate.
- On the first valid \`REVISE\`, invalidate reviews of that candidate, collect findings that have already returned, and do not wait for stale reviews. An invalidated reviewer is obsolete and non-blocking. Cancel it when the platform supports cancellation; otherwise ignore any late verdict, which cannot apply to a later candidate.
- A final-state check counts only reviewers that remain required for the current candidate. Before any final response, confirm that no active reviewer remains and that the command has reached its explicit terminal state.
- Repair the candidate, revalidate it, and dispatch a fresh independent review.

**Steps**

1. **If no clear input provided, ask what they want to build**

   Use the **AskUserQuestion tool** (open-ended, no preset options) to ask:
   > "What change do you want to work on? Describe what you want to build or fix."

   From their description, derive a kebab-case name (e.g., "add user authentication" → \`add-user-auth\`).

   **IMPORTANT**: Do NOT proceed without understanding what the user wants to build.

2. **Create the change directory**
   \`\`\`bash
   openspec new change "<name>"
   \`\`\`
   This creates a scaffolded change in the planning home resolved by the CLI with \`.openspec.yaml\`.

3. **Get the artifact build order**
   \`\`\`bash
   openspec status --change "<name>" --json
   \`\`\`
   Parse the JSON to get:
   - \`applyRequires\`: array of artifact IDs needed before implementation (e.g., \`["tasks"]\`)
   - \`artifacts\`: list of all artifacts with their status and dependencies
   - \`planningHome\`, \`changeRoot\`, \`artifactPaths\`, and \`actionContext\`: path and scope context. Use these instead of assuming repo-local paths.

4. **Create artifacts in sequence until apply-ready**

   Use the **TodoWrite tool** to track progress through the artifacts.

   Loop through artifacts in dependency order (artifacts with no pending dependencies first):

   a. **For each artifact that is \`ready\` (dependencies satisfied)**:
      - Get instructions:
        \`\`\`bash
        openspec instructions <artifact-id> --change "<name>" --json
        \`\`\`
      - The instructions JSON includes:
        - \`context\`: Project background (constraints for you - do NOT include in output)
        - \`rules\`: Artifact-specific rules (constraints for you - do NOT include in output)
        - \`template\`: The structure to use for your output file
        - \`instruction\`: Schema-specific guidance for this artifact type
        - \`resolvedOutputPath\`: Resolved path or pattern to write the artifact
        - \`dependencies\`: Completed artifacts to read for context
      - Read any completed dependency files for context
      - Create the artifact file using \`template\` as the structure and write it to \`resolvedOutputPath\`
      - Apply \`context\` and \`rules\` as constraints - but do NOT copy them into the file
      - Validate the current planning package before dispatching its reviewer. If validation fails, repair only the matching planning artifact type and rerun the same validation. Dispatch an independent review only after that planning validation passes.
      - Independently review the proposal/design/specs package before tasks, and independently review the tasks package before declaring the change apply-ready
      - Show brief progress: "Created <artifact-id>"

   b. **Continue until all \`applyRequires\` artifacts are complete**
      - After creating each artifact, re-run \`openspec status --change "<name>" --json\`
      - Check if every artifact ID in \`applyRequires\` has \`status: "done"\` in the artifacts array
      - Stop when all \`applyRequires\` artifacts are done

   c. **If an artifact requires user input** (unclear context):
      - Infer reasonable details from the objective, dependencies, and repository evidence
      - If multiple materially different outcomes remain, return \`ESCALATE\` through the review protocol with evidence and a recommended default

5. **Run final strict validation**

   After all apply-required artifacts are complete, run \`openspec validate "<name>" --strict --no-interactive\` for the complete change, preserving \`--store <id>\` when applicable. If strict validation fails, repair the indicated proposal, design, specs, or tasks and rerun strict validation. Independently review every package changed by strict-validation repair before reporting the proposal apply-ready.

6. **Show final status**
   \`\`\`bash
   openspec status --change "<name>"
   \`\`\`

**Output**

After completing all artifacts, summarize:
- Change name and location
- List of artifacts created with brief descriptions
- What's ready: "All artifacts created! Ready for implementation."
- Prompt: "Use Forgevia Implement to start implementation."

**Artifact Creation Guidelines**

- Follow the \`instruction\` field from \`openspec instructions\` for each artifact type
- The schema defines what each artifact should contain - follow it
- Read dependency artifacts for context before creating new ones
- Use \`template\` as the structure for your output file - fill in its sections
- **IMPORTANT**: \`context\` and \`rules\` are constraints for YOU, not content for the file
  - Do NOT copy \`<context>\`, \`<rules>\`, \`<project_context>\` blocks into the artifact
  - These guide what you write, but should never appear in the output

**Guardrails**
- Create ALL artifacts needed for implementation (as defined by schema's \`apply.requires\`)
- Always read dependency artifacts before creating a new one
- If context is critically unclear, use \`ESCALATE\`; ordinary assumptions go through independent review instead of a confirmation gate
- If a change with that name already exists, inspect its objective and status; continue it when it is the unique match, otherwise use \`ESCALATE\` for the substantive identity conflict
- Verify each artifact file exists after writing before proceeding to next
- Proposal completion does not authorize implementation, commit, sync, archive, push, merge, or release`,
        license: 'MIT',
        compatibility: 'Requires openspec CLI.',
        metadata: { author: 'openspec', version: '1.0' },
    };
}
export function getOpsxProposeCommandTemplate() {
    return {
        name: 'OPSX: Propose',
        description: 'Propose a new change - create it and generate all artifacts in one step',
        category: 'Workflow',
        tags: ['workflow', 'artifacts', 'experimental'],
        content: `Propose a new change - create the change and generate all artifacts in one step.

I'll create a change with artifacts:
- proposal.md (what & why)
- design.md (how)
- tasks.md (implementation steps)

When ready to implement, use Forgevia Implement

---

${STORE_SELECTION_GUIDANCE}

**Input**: The argument after \`/opsx:propose\` is the change name (kebab-case), OR a description of what the user wants to build.

**Independent review contract:** Use the client's native subagent tool for an independent reviewer different from the candidate producer. Every review package contains:

- Objective: the authorized outcome.
- Scope: the allowed repositories, changes, files, and systems.
- Constraints: the binding process, architecture, safety, and platform rules.
- Authorized effects: the writes and side effects allowed to the controller.
- Terminal condition: the state at which this workflow must stop.
- The source requirements, repository evidence, candidate producer identity, candidate artifacts, action, or diff, verification evidence, assumptions and risks.

Require an evidence-backed \`APPROVE\`, \`REVISE\`, or \`ESCALATE\`. On \`APPROVE\`, continue automatically to the next dependency-ready artifact. On \`REVISE\`, repair the planning artifact, revalidate it, and request another independent review. Only \`ESCALATE\` pauses for user input, and only for a consequential ambiguity that cannot be reasonably inferred, a required scope or authorization expansion, a conflicting rule, or an unavailable required capability.

If a reviewer fails to start, times out, crashes, or returns an invalid verdict, reuse the unchanged review package with at most two new independent review agents. If both retries fail, return \`ESCALATE\` with the collected infrastructure evidence; never infer \`APPROVE\`. The controller validates only reviewer identity, verdict structure, and supporting evidence; it does not recursively review the verdict.

**Reviewer lifecycle:**

- An active reviewer is not a terminal state. A reviewer remains active while queued, running, or awaiting collection of its verdict for the current candidate.
- After dispatching a reviewer, retain control and poll internally; do not emit a final response, completion summary, or user-facing wait request while an active reviewer remains.
- \`APPROVE\` is valid only when every required reviewer has returned a valid verdict for the same candidate.
- On the first valid \`REVISE\`, invalidate reviews of that candidate, collect findings that have already returned, and do not wait for stale reviews. An invalidated reviewer is obsolete and non-blocking. Cancel it when the platform supports cancellation; otherwise ignore any late verdict, which cannot apply to a later candidate.
- A final-state check counts only reviewers that remain required for the current candidate. Before any final response, confirm that no active reviewer remains and that the command has reached its explicit terminal state.
- Repair the candidate, revalidate it, and dispatch a fresh independent review.

**Steps**

1. **If no input provided, ask what they want to build**

   Use the **AskUserQuestion tool** (open-ended, no preset options) to ask:
   > "What change do you want to work on? Describe what you want to build or fix."

   From their description, derive a kebab-case name (e.g., "add user authentication" → \`add-user-auth\`).

   **IMPORTANT**: Do NOT proceed without understanding what the user wants to build.

2. **Create the change directory**
   \`\`\`bash
   openspec new change "<name>"
   \`\`\`
   This creates a scaffolded change in the planning home resolved by the CLI with \`.openspec.yaml\`.

3. **Get the artifact build order**
   \`\`\`bash
   openspec status --change "<name>" --json
   \`\`\`
   Parse the JSON to get:
   - \`applyRequires\`: array of artifact IDs needed before implementation (e.g., \`["tasks"]\`)
   - \`artifacts\`: list of all artifacts with their status and dependencies
   - \`planningHome\`, \`changeRoot\`, \`artifactPaths\`, and \`actionContext\`: path and scope context. Use these instead of assuming repo-local paths.

4. **Create artifacts in sequence until apply-ready**

   Use the **TodoWrite tool** to track progress through the artifacts.

   Loop through artifacts in dependency order (artifacts with no pending dependencies first):

   a. **For each artifact that is \`ready\` (dependencies satisfied)**:
      - Get instructions:
        \`\`\`bash
        openspec instructions <artifact-id> --change "<name>" --json
        \`\`\`
      - The instructions JSON includes:
        - \`context\`: Project background (constraints for you - do NOT include in output)
        - \`rules\`: Artifact-specific rules (constraints for you - do NOT include in output)
        - \`template\`: The structure to use for your output file
        - \`instruction\`: Schema-specific guidance for this artifact type
        - \`resolvedOutputPath\`: Resolved path or pattern to write the artifact
        - \`dependencies\`: Completed artifacts to read for context
      - Read any completed dependency files for context
      - Create the artifact file using \`template\` as the structure and write it to \`resolvedOutputPath\`
      - Apply \`context\` and \`rules\` as constraints - but do NOT copy them into the file
      - Validate the current planning package before dispatching its reviewer. If validation fails, repair only the matching planning artifact type and rerun the same validation. Dispatch an independent review only after that planning validation passes.
      - Independently review the proposal/design/specs package before tasks, and independently review the tasks package before declaring the change apply-ready
      - Show brief progress: "Created <artifact-id>"

   b. **Continue until all \`applyRequires\` artifacts are complete**
      - After creating each artifact, re-run \`openspec status --change "<name>" --json\`
      - Check if every artifact ID in \`applyRequires\` has \`status: "done"\` in the artifacts array
      - Stop when all \`applyRequires\` artifacts are done

   c. **If an artifact requires user input** (unclear context):
      - Infer reasonable details from the objective, dependencies, and repository evidence
      - If multiple materially different outcomes remain, return \`ESCALATE\` through the review protocol with evidence and a recommended default

5. **Run final strict validation**

   After all apply-required artifacts are complete, run \`openspec validate "<name>" --strict --no-interactive\` for the complete change, preserving \`--store <id>\` when applicable. If strict validation fails, repair the indicated proposal, design, specs, or tasks and rerun strict validation. Independently review every package changed by strict-validation repair before reporting the proposal apply-ready.

6. **Show final status**
   \`\`\`bash
   openspec status --change "<name>"
   \`\`\`

**Output**

After completing all artifacts, summarize:
- Change name and location
- List of artifacts created with brief descriptions
- What's ready: "All artifacts created! Ready for implementation."
- Prompt: "Use Forgevia Implement to start implementation."

**Artifact Creation Guidelines**

- Follow the \`instruction\` field from \`openspec instructions\` for each artifact type
- The schema defines what each artifact should contain - follow it
- Read dependency artifacts for context before creating new ones
- Use \`template\` as the structure for your output file - fill in its sections
- **IMPORTANT**: \`context\` and \`rules\` are constraints for YOU, not content for the file
  - Do NOT copy \`<context>\`, \`<rules>\`, \`<project_context>\` blocks into the artifact
  - These guide what you write, but should never appear in the output

**Guardrails**
- Create ALL artifacts needed for implementation (as defined by schema's \`apply.requires\`)
- Always read dependency artifacts before creating a new one
- If context is critically unclear, use \`ESCALATE\`; ordinary assumptions go through independent review instead of a confirmation gate
- If a change with that name already exists, inspect its objective and status; continue it when it is the unique match, otherwise use \`ESCALATE\` for the substantive identity conflict
- Verify each artifact file exists after writing before proceeding to next
- Proposal completion does not authorize implementation, commit, sync, archive, push, merge, or release`
    };
}
//# sourceMappingURL=propose.js.map

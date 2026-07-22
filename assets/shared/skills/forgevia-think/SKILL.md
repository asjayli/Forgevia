---
name: forgevia-think
description: Use when the user explicitly asks Forgevia to think through a requirement before proposal or implementation, especially when the request is still vague, evolving, or backed by diagrams or requirement documents.
license: MIT
compatibility: Works best in repositories that use Forgevia-style change artifacts under openspec/.
metadata:
  author: forgevia
  version: "1.0"
---

Use this skill when the user explicitly wants Forgevia to think through a requirement before proposal or implementation.

**IMPORTANT: Think is for clarification, not implementation.** You may read files, inspect the repository, and write think artifacts, but you must NOT implement product code as part of this step.

## Accepted Input

- A vague idea, problem statement, feature, flow, or interface description
- A more detailed written request
- A `.mmd` diagram generated from Forgevia draw
- A full requirement document

More detailed input usually produces a more precise think result.

## Behavior

**Independent review contract:** Every reviewer receives one review package containing:

- Objective: the authorized outcome.
- Scope: the allowed repositories, changes, files, and systems.
- Constraints: the binding process, architecture, safety, and platform rules.
- Authorized effects: the writes and side effects allowed to the controller.
- Terminal condition: the state at which this workflow must stop.
- The candidate producer identity, candidate artifacts, action, or diff, verification evidence, assumptions and risks.

If a reviewer fails to start, times out, crashes, or returns an invalid verdict, reuse the unchanged review package with at most two new independent review agents. If both retries fail, return `ESCALATE` with the collected infrastructure evidence; never infer `APPROVE`. The controller validates only reviewer identity, verdict structure, and supporting evidence; it does not recursively review the verdict.

1. **Treat the user's input as raw source material**
   - Use the requirement text, attached notes, `.mmd` design flow, and supporting documents when available.

2. **Check requirement completeness (greenfield only)**
   - For a greenfield requirement, walk these categories and surface a question only when an answer is missing AND it changes the design:

     | Category | Ask only when missing and design-affecting |
     |---|---|
     | Target platform | web, mobile, desktop, CLI, multi-platform |
     | Tech stack | framework, language, runtime |
     | Design direction | visual style, interaction constraints |
     | External integrations | identity, data, payments, storage, deployment |
     | Scope boundaries | this phase, deferred, explicitly excluded |
     | Users and scenarios | primary users, key flows |
     | Performance constraints | traffic, latency, offline, real-time |
     | Data model | core entities and relationships |

   - Do not re-ask anything the prompt, project files, or memory already answer.
   - For existing projects, answer from code and existing specs first; ask at most the forks that truly affect the plan.
   - Leave micro implementation details to design/tasks; do not confirm them at the requirement stage.
   - Request at most one decision per round for a material ambiguity.

3. **Read project memory (read-only)**
   - Discover and read only: `<project>/.codex/memory/`, `<project>/.claude/memory/`, and memory indices the host already exposes publicly.
   - Do not create these directories when absent; do not scan global unrelated memory.
   - Do not write memory back during think or propose.
   - For each adopted fact, record its source, why it applies, and the decision it affects (see Context Provenance in the output template).
   - A conflicting older memory must not silently override explicit user input.

4. **Create the think artifact directory when missing**
   - Ensure `openspec/think/` exists before writing any artifact.

5. **Restate the requirement first**
   - Rewrite the user's request in clearer terms.
   - Explain your current understanding.
   - Surface scope boundaries, assumptions, risks, and open questions.

6. **Run an independent review**
   - Give a reviewer that did not produce the restatement the original request, repository evidence, proposed scope, assumptions, risks, and terminal condition.
   - Require an evidence-backed `APPROVE`, `REVISE`, or `ESCALATE` verdict.
   - On `APPROVE`, write the think artifact without waiting for user confirmation.
   - On `REVISE`, update the restatement and request another independent review.
   - On `ESCALATE`, ask once for the critical decision that cannot be inferred, including evidence, a recommendation, and option impacts.

7. **Write the reviewed think artifact**
   - Save the independently approved result as Markdown under `openspec/think/`.
   - Use the file name format `YYYY-MM-DD-<requirement-description>.md`.
   - If the same dated requirement already exists, create the next version as `YYYY-MM-DD-<requirement-description>-v2.md`, then `-v3.md`, and so on.
   - Do not overwrite an earlier iteration of the same requirement.

8. **Recommend the next step**
   - If the objective ends at think, return the reviewed artifact and stop.
   - If the original objective includes later Forgevia phases, continue to proposal after `APPROVE` without a stage confirmation.
   - If the user is still exploring, keep thinking instead of forcing structure too early.

## Think Output Template

```markdown
# YYYY-MM-DD <Requirement Title>

## Original Request

[The user's raw requirement, idea, or problem statement]

## Restated Understanding

[Forgevia's clearer restatement of the requirement]

## Context Provenance

| Fact | Source | Why Applicable | Decision Impact |
|------|--------|----------------|-----------------|

## Scope And Boundaries

- [What is in scope]
- [What is out of scope]

## Risks And Open Questions

- [Risk, dependency, assumption, or unresolved question]

## Next Step Recommendation

[Recommended next action after independent review]
```

## Guardrails

- Do not implement application code during think
- Do not use a user confirmation as a stage gate
- Only `ESCALATE` may request user input, and only for a critical ambiguity, scope or authorization expansion, rule conflict, or unavailable required capability
- Do not overwrite an earlier think artifact for the same requirement
- Do use `.mmd` diagrams and requirement documents as supporting context when provided

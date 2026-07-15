---
name: forgevia-propose
description: Use when the user explicitly asks Forgevia to turn a requirement description or a specified file into a new OpenSpec change proposal.
---

# Forgevia Propose

Use this skill when the user explicitly wants Forgevia to produce a new OpenSpec change from a requirement description or a specified file.

## Accepted Input

- A direct user description of the change to build.
- A specified file path whose contents should be treated as the requirement source.
- Both, where the file is primary and the user prompt adds clarification.

## Behavior

- Route the requirement source into `openspec-propose`.
- Allow the change name to come from the user when explicitly provided.
- Otherwise derive an appropriate kebab-case change name from the requirement source.
- Treat the provided file as requirement input, not as implementation output.
- If the requirement source cannot be recovered from the provided input, referenced files, conversation, or repository evidence, return `ESCALATE` through the three-state review protocol with the missing evidence, a recommended default, option impacts, and why work cannot continue.
- Independently review the proposal/design/specs package and the tasks package. Require `APPROVE`, `REVISE`, or `ESCALATE`; automatically repair an authorized `REVISE`, revalidate, and review again.
- Continue through all apply-ready planning artifacts after `APPROVE`; only `ESCALATE` may request a critical decision that cannot be inferred.
- Proposal completion does not authorize implementation, commit, sync, archive, push, merge, or release.
- When writing Chinese requirements, use one of `必须、不得、禁止、应当` in the requirement body. Keep OpenSpec structure keywords in English, including `## Requirements` and `### Requirement:`.
- After creating the change artifacts, run `"${CLAUDE_HOME:-$HOME/.claude}/forgevia/bin/forgevia" validate --root <project-root>`. Do not report the proposal as strictly valid if this command fails.

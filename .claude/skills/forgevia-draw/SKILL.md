---
name: forgevia-draw
description: Use when the user explicitly asks Forgevia to generate a Mermaid interaction sequence diagram from a named feature, flow, or interface description.
---

# Forgevia Draw

Use this skill when the user explicitly asks Forgevia to draw an interaction sequence for a feature, flow, or interface.

## Required Input

- A feature, flow, or interface description from the user.

## Behavior

- Route content generation to `mermaid-diagram-specialist`.
- Prefer a complete interaction-module sequence diagram.
- Request concise Chinese notes for key methods and critical intermediate steps.
- Optimize for fast understanding, not maximum annotation density.
- Hand the Mermaid output to the installed runtime script `$HOME/.claude/forgevia/bin/forgevia-draw.sh` (pipe Mermaid source via stdin).
- Write a timestamped `.mmd` and a matching `.svg` under `./forgevia-drawings/` by default (override the output directory with a second argument).
- Prefer a local Chrome/Chromium executable for `mmdc` when available.
- Name outputs as `YYYYMMDD-HHMMSS-功能`.

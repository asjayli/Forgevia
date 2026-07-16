<div align="center">

# Forgevia

### A workflow bundle for Codex, Claude`s agent coding delivery

[中文](README.md) | English

</div>

Forge your agent workflow into steel.

Forgevia is an opinionated workflow bundle for agent coding.

## Scope

### What Forgevia does

- Integrates OpenSpec, superpowers, code review, and browser validation into one coherent workflow from requirement to archive.
- Manages global managed assets via `init` / `doctor` / `repair`: skills, commands, and managed override files layered on upstreams.
- Provides explicit command orchestration: `draw` / `think` / `propose` / `implement` / `tasks` / `review` / `verify-web` / `archive`, plus the standalone `openspec-sync-specs` skill.

### What Forgevia does not do

- Does not replace OpenSpec, superpowers, or playwright-interactive — it only orchestrates; the underlying capabilities still come from them.
- Does not take over your project source: it only invokes `openspec init` when missing and never edits business code.
- Does not auto-trigger: it works only when the user explicitly asks; it will not step in just because a coding request exists.
- Pins OpenSpec to the verified `1.6.0` release; other upstream dependencies retain their own installation flows. The installer skips overlays protectively on version mismatch instead of downgrading upstream.

## Install For Codex

Tell Codex:

```text
Fetch and follow instructions from https://raw.githubusercontent.com/asjayli/Forgevia/refs/heads/main/INSTALL.codex.md
```

## Install For Claude

Tell Claude:

```text
Fetch and follow instructions from https://raw.githubusercontent.com/asjayli/Forgevia/refs/heads/main/INSTALL.claude.md
```

## Skills

- `forgevia`: General entry for the Forgevia workflow.
- `forgevia-init`: Prepare the current project for the Forgevia workflow.
- `forgevia-think`: Clarify and shape a requirement before implementation.
- `forgevia-propose`: Turn a requirement description or file into a new change proposal.
- `forgevia-implement`: Implement one named active change with a structured workflow.
- `forgevia-tasks`: List unfinished tasks across active changes.
- `forgevia-review`: Run a focused review checkpoint for current work.
- `forgevia-verify-web`: Verify web-facing behavior in a browser.
- `forgevia-draw`: Generate interaction sequence diagrams for a feature, flow, or interface.
- `openspec-sync-specs`: Sync one change's delta specs to main specs while keeping the change active and unarchived.
- `forgevia-archive`: Archive one completed active change.
- `forgevia-doctor`: Inspect whether the Forgevia environment is healthy.
- `forgevia-repair`: Repair missing or drifted Forgevia-managed assets.

## How it works

### Full workflow

`forgevia` is the top-level entry. You tell Forgevia which action to run, and it keeps the work on one consistent path from idea to completion.

After a command starts, Forgevia automatically performs routine steps, independent review, authorized fixes, and re-verification within that command's objective and scope, without step-by-step confirmation. It pauses only for material ambiguity, missing authorization, unauthorized external side effects, or a blocker that cannot converge. It does not enter an unrequested later phase or archive, push, or release automatically.

1. `Forgevia init`
   Use this when starting in a new repository. It checks whether the project is ready for the Forgevia workflow and creates the required project-side workflow files only when they are missing. If the repository should work from both Codex and Claude, initialize the project with `codex,claude`.
2. `Forgevia doctor`
   Use this to inspect the global environment. It reports whether the installed Forgevia assets are healthy, missing, or out of sync.
3. `Forgevia repair`
   Use this when `doctor` finds problems. It restores missing or drifted Forgevia-managed files so the workflow can run consistently again.
4. `Forgevia draw`
   Use this when the team needs a visual design aid before implementation. It can generate sequence diagrams, UML-style diagrams, and swimlane diagrams for a specific feature, interface, or flow. The generated `.mmd` file can be used as reference input for the later thinking and planning steps, and Forgevia also renders an SVG vector diagram that can be opened in Chrome and used as a visual reference during development. When a feature, interface, or flow changes, update the design diagram, `.mmd`, and SVG promptly so the visual design stays aligned with implementation.
5. `Forgevia think`
   Use this before building to clarify the request. You can start with a rough idea, provide a more detailed description, attach the `.mmd` flow produced by `draw`, or supply a full requirements document. In general, the more concrete the input is, the more precise the resulting analysis and direction will be. Forgevia first produces a restatement and scope for an independent review; after approval, it writes the result directly to a Markdown file under `openspec/think/` without waiting for user confirmation. Filenames start with the current date, and repeated iterations of the same requirement continue as `v2`, `v3`, and so on.
6. `Forgevia propose`
   Use this to generate a new change from a requirement or an input file. You can feed in the result you are happy with after `think`, or skip that step and provide a request that you already consider complete and ready. That choice is up to you. The output is a named implementation unit with clear scope, documentation, and executable task breakdown.
7. `Forgevia tasks`
   Use this when you want a read-only view of unfinished work. It lists pending tasks across active changes and helps decide what to do next.
8. `Forgevia implement <change>`
   Use this to execute one named active change. It drives development through a structured task flow, keeps progress aligned with the change definition, and expects disciplined test-first execution rather than ad-hoc coding.
9. `Forgevia review`
   Use this at review checkpoints. It requests a focused review of the current work, preferably against a clear commit range, and reports findings in strict severity order so the highest-risk issues are handled first.
10. `Forgevia verify-web`
   Use this when the change affects web pages, browser behavior, UI interaction, or visual output. It validates the user-facing result in a real browser before completion.
11. `openspec-sync-specs <change>`
   Use this to merge one change's delta specs into main specs without archiving it. It authorizes spec synchronization only, not archive, commit, push, or release.
12. `Forgevia archive <change>`
   Use this after implementation, review, and verification are complete. It closes the finished change, syncs its final documentation, and keeps the project history clean.

### Simple workflow

`draw -> think -> propose -> implement -> review -> verify-web (if needed) -> openspec-sync-specs (when early synchronization is needed) -> archive`

Forgevia turns requirement shaping, structured implementation, review, validation, and closure into one consistent delivery workflow.

### Chinese OpenSpec Strict Validation

Forgevia provides Chinese-compatible OpenSpec strict validation through `forgevia validate` for requirements whose body uses the Chinese normative terms `必须`, `不得`, `禁止`, or `应当`, without changing source specs. It checks those terms, injects `MUST` only in a temporary copy, and then runs native strict validation:

```bash
"${CODEX_HOME:-$HOME/.codex}/forgevia/bin/forgevia" validate --root <project-root>
```

For Claude installations, use `${CLAUDE_HOME:-$HOME/.claude}/forgevia/bin/forgevia`. Adding the relevant `forgevia/bin` directory to PATH enables `forgevia validate --root <project-root>`. The command dispatcher also supports `init`, `tasks`, `draw`, `doctor`, and `repair`. The adapter validates main specs and active changes, supports only the `spec-driven` schema, and does not support Chinese section or heading keywords: keep `## Requirements`, `### Requirement:`, and `#### Scenario:` in English.

## Third-Party Assets & Licensing

- `playwright-interactive`: sourced from upstream, Apache License 2.0 (© Microsoft Corporation). Forgevia redistributes it with its original `LICENSE.txt` and `NOTICE.txt` retained.
- `mermaid-diagram-specialist`: a Forgevia-original skill.
- `superpowers` and `OpenSpec`: installed as upstream dependencies; Forgevia only overlays managed customization files on top of them. See `INSTALL.claude.md` / `INSTALL.codex.md`.

## Upstream Dependencies

Forgevia layers managed customizations on the following upstreams. The gap between the snapshot version and the latest upstream release determines whether adaptation is needed.

| Upstream | Purpose | Forgevia baseline | Latest upstream | URL |
|----------|---------|-------------------|-----------------|-----|
| OpenSpec (`@fission-ai/openspec`) | spec-driven change workflow CLI | override targets and pins `1.6.0` | `1.6.0` | https://www.npmjs.com/package/@fission-ai/openspec |
| superpowers (`obra/superpowers`) | brainstorming / TDD / planning / review skill framework | test baseline `6.1.1` | `6.1.1` | https://github.com/obra/superpowers |
| playwright-interactive | browser interaction verification skill | vendored (untracked) | — | see `LICENSE.txt` / `NOTICE.txt` inside the skill (Apache-2.0, © Microsoft Corporation) |
| mermaid-cli (`mmdc`) | runtime dependency for `forgevia-draw` SVG rendering | runtime tool | — | https://github.com/mermaid-js/mermaid-cli |
| ripgrep (`rg`) | runtime dependency for `forgevia-tasks` scanning (optional, falls back to grep) | runtime tool | — | https://github.com/BurntSushi/ripgrep |

> Note: Forgevia's OpenSpec override is a content snapshot taken against `1.6.0`, and the installer pins that version. When the local OpenSpec version differs from the snapshot, the installer and doctor skip the overlay protectively to avoid downgrading upstream. Upgrade the override snapshot, installation version, and `overrideTargetVersion` in `manifests/*.json` together.

# Forgevia For Codex

Forgevia installs an opinionated Codex workflow around OpenSpec, superpowers, requesting-code-review, and playwright-interactive.

This repository is GitHub-first. The Codex path assumes:

- `openspec` is installed or can be installed globally with npm
- `superpowers` is installed from its upstream Codex install guide
- Forgevia ships and manages its own curated copies of the workflow files it owns
- `~/.codex` is the primary managed global target

Claude has a separate install path documented in `INSTALL.claude.md`.

## Current Scope

The Codex installer manages:

- Forgevia and OpenSpec support skills under `~/.codex/skills`
- the helper skills required by the Forgevia flow (`mermaid-diagram-specialist`, `playwright-interactive`)
- Forgevia-managed overrides for selected installed superpowers skills:
  - `brainstorming`
  - `writing-plans`
  - `test-driven-development`
  - `subagent-driven-development`
  - `requesting-code-review`
  - `executing-plans`
- Forgevia-managed overrides for the upstream OpenSpec npm package internals (`config-prompts.js`, `propose.js`)
- the platform-neutral `forgevia` command is installed at `~/.local/bin/forgevia`

`playwright-interactive` is vendored into this repository (Apache-2.0, © Microsoft Corporation; see its `LICENSE.txt` / `NOTICE.txt`). `mermaid-diagram-specialist` is a Forgevia-original skill.

## Prerequisites

- `node` and `npm` are available
- `node` and `npm` are available; the installer always installs OpenSpec `1.6.0`, replacing any local version
- `superpowers` is installed under `~/.codex/superpowers` from the upstream guide:

> Fetch and follow instructions from https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.codex/INSTALL.md

Every installation runs `npm install -g @fission-ai/openspec@1.6.0` before
applying Forgevia assets, replacing any locally installed OpenSpec version.

## Install

```bash
git clone https://github.com/asjayli/Forgevia.git
cd Forgevia
bash scripts/install-codex.sh
```

## Managed State

After installation:

- `openspec` is available on `PATH`
- `forgevia` is available on `PATH` through `~/.local/bin/forgevia`
- Forgevia-managed Codex skill files are installed under `~/.codex/skills`
- selected superpowers skill files are replaced with Forgevia-managed copies under `~/.codex/superpowers`
- Forgevia-managed OpenSpec overrides are applied to the installed OpenSpec package

### Symbolic Links

You may use symbolic links to place `~/.codex` or any managed subdirectory on another volume. Forgevia follows those links and synchronizes the resolved target without replacing the user-defined link; `doctor --repair` follows the same behavior.

The installer replaces only its marked Forgevia global command. It refuses to
replace another command or a link owned by the user or another installation.

### OpenSpec Override Version Note

Forgevia's OpenSpec override files are snapshots taken against OpenSpec `1.6.0` (recorded in `manifests/codex.json` as `overrideTargetVersion`). The installer and doctor refuse to overlay them onto a different upstream version, to avoid silently downgrading upstream behavior. When OpenSpec advances, update the override snapshot and the fixed version together.

## Verify Managed State

```bash
./scripts/doctor-codex.sh
```

Reports `OK`, `MISS`, or `DRIFT` for each managed asset. Run with `--repair` to restore drifted or missing assets:

```bash
./scripts/doctor-codex.sh --repair
```

## Bootstrap A Project

```bash
./scripts/bootstrap-project.sh --tools codex /path/to/project
```

Checks whether OpenSpec is already initialized and runs `openspec init` only when missing. It does not take ownership of project source files.

## Notes

- This is a Codex-specific install path and does not modify `~/.claude`.
- This installer expects upstream `superpowers` to already be installed.

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

`playwright-interactive` is vendored into this repository (Apache-2.0, © Microsoft Corporation; see its `LICENSE.txt` / `NOTICE.txt`). `mermaid-diagram-specialist` is a Forgevia-original skill.

## Prerequisites

- `node` and `npm` are available
- `openspec` is installed, or installable with `npm install -g @fission-ai/openspec@latest` (or pass `--install-openspec`)
- `superpowers` is installed under `~/.codex/superpowers` from the upstream guide:

> Fetch and follow instructions from https://raw.githubusercontent.com/obra/superpowers/refs/heads/main/.codex/INSTALL.md

## Install

```bash
git clone https://github.com/asjayli/Forgevia.git
cd Forgevia
bash scripts/install-codex.sh
```

If you also want the installer to bootstrap `openspec` when missing:

```bash
bash scripts/install-codex.sh --install-openspec
```

## Managed State

After installation:

- `openspec` is available on `PATH`
- Forgevia-managed Codex skill files are installed under `~/.codex/skills`
- selected superpowers skill files are replaced with Forgevia-managed copies under `~/.codex/superpowers`
- Forgevia-managed OpenSpec overrides are applied to the installed OpenSpec package

### OpenSpec Override Version Note

Forgevia's OpenSpec override files are snapshots taken against a specific upstream OpenSpec version (currently `1.4.1`, recorded in `manifests/codex.json` as `overrideTargetVersion`). The installer and doctor refuse to overlay them onto a different upstream version, to avoid silently downgrading upstream behavior. When OpenSpec advances past this version, update Forgevia's override snapshot together with the target version.

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

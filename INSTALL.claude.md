# firefly For Claude

firefly supports a Claude installation path that mirrors the firefly skill layout used on Codex while staying compatible with Claude's skill and plugin structure.

The Claude installer manages:

- firefly and OpenSpec support skills under `~/.claude/skills`
- the `opsx` command set under `~/.claude/commands`
- the full firefly Claude skill set
- firefly-managed overrides for selected installed Claude superpowers skills:
  - `brainstorming`
  - `writing-plans`
  - `test-driven-development`
  - `subagent-driven-development`
  - `requesting-code-review`
  - `executing-plans`

This path installs firefly-managed Claude skills and commands into `~/.claude` and overlays selected skill overrides into the installed Claude superpowers plugin.

## Prerequisites

- `node` and `npm` must be available; the installer always installs OpenSpec `1.6.0`, replacing any local version
- the Claude superpowers plugin must already be installed

Every installation runs `npm install -g @fission-ai/openspec@1.6.0` before applying firefly assets, replacing any locally installed OpenSpec version.

In Claude Code, register the marketplace first:

```text
/plugin marketplace add obra/superpowers-marketplace
```

Then install the plugin from this marketplace:

```text
/plugin install superpowers@superpowers-marketplace
```

When Claude Code prompts for the install scope, choose `user`.

## Current Scope

The current Claude implementation installs:

- OpenSpec support skills:
  - `openspec-explore`
  - `openspec-propose`
  - `openspec-apply-change`
  - `openspec-archive-change`
- firefly skills:
  - `firefly`
  - `firefly-init`
  - `firefly-doctor`
  - `firefly-repair`
  - `firefly-think`
  - `firefly-propose`
  - `firefly-implement`
  - `firefly-tasks`
  - `firefly-review`
  - `firefly-verify-web`
  - `firefly-draw`
  - `firefly-archive`
- Helper skills required by the firefly flow:
  - `mermaid-diagram-specialist`
  - `playwright-interactive`
- `~/.claude/commands/opsx`
- selected overrides into the installed Claude superpowers plugin
- the platform-neutral `firefly` command is installed at `~/.local/bin/firefly`

Current behavior of the Claude firefly layer:

- keeps the same firefly command surface as Codex
- routes proposal, implementation, review, verification, drawing, and archive requests through the same firefly skill boundaries
- keeps `firefly-think` on the same artifact, independent-review, and versioning rules
- installs the support skills those firefly commands depend on

Current behavior of the Claude superpowers overrides:

- binds brainstorming and planning to `openspec/changes/<change>/...`
- keeps `test-driven-development` aligned with the firefly-managed TDD skill text
- keeps execution aligned to `openspec/changes/<change>/tasks.md`
- keeps code review aligned to explicit commit ranges and `P0`/`P1`/`P2` ordering

## Install

Tell Claude:

```text
Install openspec and the Claude superpowers plugin first. Then clone https://github.com/asjayli/firefly and run bash scripts/install-claude.sh from the repository root.
```

Or run it directly yourself:

```bash
git clone https://github.com/asjayli/firefly.git
cd firefly
bash scripts/install-claude.sh
```

## Target State

After installation:

- the firefly and OpenSpec support skill directories exist under `~/.claude/skills/`
- `~/.claude/commands/opsx` exists
- selected Claude superpowers skill files are replaced with firefly-managed copies
- Claude can discover and use the firefly command set globally
- `firefly` is available on `PATH` through `~/.local/bin/firefly`
- project bootstrap can initialize OpenSpec with `--tools codex,claude` when the repository should support both firefly clients

### Symbolic Links

You may use symbolic links to place `~/.claude` or any managed subdirectory on another volume. firefly follows those links and synchronizes the resolved target without replacing the user-defined link; `doctor --repair` follows the same behavior.

The installer replaces only its marked firefly global command. It refuses to
replace another command or a link owned by the user or another installation.

## Notes

- This is a Claude-specific install path and does not modify `~/.codex`
- This installer expects the Claude superpowers plugin to already be installed

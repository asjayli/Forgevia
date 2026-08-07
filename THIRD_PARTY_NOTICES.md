# Third-Party Notices

firefly redistributes or layers managed overrides on the following third-party
components. Each component retains its own license; the root `LICENSE`
(MIT) applies to firefly's original work only and does not replace or
remove any third-party license or notice.

## Redistributed (vendored) components

### playwright-interactive

- **Source:** vendored skill assets derived from Microsoft's
  [playwright-cli](https://github.com/microsoft/playwright-cli) repository.
- **License:** Apache License 2.0 — Copyright (c) Microsoft Corporation.
- **Location:** `assets/codex/skills/playwright-interactive/` and
  `assets/claude/skills/playwright-interactive/`.
- **Notices:** the upstream `LICENSE.txt` and `NOTICE.txt` are retained
  unmodified inside each vendored directory.
- **Modifications:** as recorded in the vendored `NOTICE.txt` — repackaged
  the Playwright icon assets for a `js_repl`-focused skill and wrote new
  skill instructions for persistent browser debugging. firefly redistributes
  the skill without further modification.

## Upstream dependencies with firefly-managed overrides

firefly does not vendor these components; users install them from upstream,
and firefly layers managed override files on top (see `manifests/codex.json`
and `manifests/claude.json`).

### OpenSpec (`@fission-ai/openspec`)

- **Source:** https://www.npmjs.com/package/@fission-ai/openspec
- **License:** MIT.
- **Baseline:** pinned to `1.6.0` (`overrideTargetVersion` in both manifests).
- **Modifications:** firefly installs managed override files
  (`assets/openspec/dist/core/config-prompts.js` and
  `assets/openspec/dist/core/templates/workflows/propose.js`) over the
  upstream installation. Installers protectively skip the override when the
  installed OpenSpec version does not match `1.6.0`.

### superpowers (`obra/superpowers`)

- **Source:** https://github.com/obra/superpowers
- **License:** MIT.
- **Baseline:** test baseline `6.1.1`.
- **Modifications:** firefly maintains overlay copies of selected skills
  (brainstorming, writing-plans, subagent-driven-development, executing-plans,
  requesting-code-review, test-driven-development) under
  `assets/{codex,claude}/superpowers/skills/`. These overlays are installed on
  top of the upstream superpowers installation and never overwrite unmanaged
  upstream assets.

## Runtime tools (user-installed, not redistributed)

### mermaid-cli (`mmdc`)

- **Source:** https://github.com/mermaid-js/mermaid-cli
- **License:** MIT.
- **Use:** runtime rendering dependency of the `firefly-draw` skill.

### ripgrep (`rg`)

- **Source:** https://github.com/BurntSushi/ripgrep
- **License:** MIT OR Unlicense.
- **Use:** optional task-scanning accelerator for `firefly-tasks`; falls back
  to `grep` when absent.

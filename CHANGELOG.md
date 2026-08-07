# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-08-07

First formal release of firefly as a versioned, licensed distribution.

### Added

- Release metadata: `VERSION`, `CHANGELOG.md`, `LICENSE` (MIT), and
  `THIRD_PARTY_NOTICES.md`, plus `fireflyVersion` in both platform manifests
  and `scripts/check-release-metadata.sh` to keep them consistent.
- Portable SHA-256 resolution across installers and doctor scripts
  (`sha256sum` or `shasum -a 256`, no weak-hash fallback).
- Shared platform asset sources (`assets/shared/`) rendered to both platforms
  by `scripts/sync-platform-assets.mjs`, with a drift gate (`--check`) and
  byte-identical superpowers overlays.
- Requirement completeness checks and memory provenance records in planning.
- Pre-flight self-critique and a Verification Contract (baseline, targeted,
  and final commands) for `tasks.md`.
- Baseline pre-flight classification during implementation
  (clean / in-scope-red / unrelated-red / user-worktree-red).
- Evidence-backed verification coverage ledger with a hard gate on
  `unverified = 0` for final reports.
- Automated complete-delivery routing and a global `firefly` command.
- Bootstrap hardening for project paths and init output pre-flight.

### Changed

- Review strategy: development is separated from review; independent review
  runs once at the complete-branch final stage with severity-gated rounds
  (Critical + Important cleared, then at most 3 closing rounds; remaining
  Minor findings are recorded in the coverage ledger).
- Renamed the project and assets to firefly and restored executable bits.
- Installers pin the verified OpenSpec `1.6.0` installation and protectively
  skip overrides on version mismatch.

### Fixed

- Enforced continuous child-agent control and reviewer lifecycle in the
  autonomous workflow.
- Hardened managed asset paths, preserved user-managed symlinks, separated
  client state from the distribution, and aligned the Codex source mirror.

[0.1.0]: https://github.com/asjayli/forgevia

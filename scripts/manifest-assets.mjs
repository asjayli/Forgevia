#!/usr/bin/env node
// firefly manifest asset lister.
//
// Reads a platform manifest (manifests/claude.json or manifests/codex.json)
// and prints its managed assets as TAB-separated lines for shell consumption:
//
//   kind<TAB>source<TAB>target
//
// Resolution rules:
//   - `source` is repo-relative in the manifest and resolves against the repo
//     root (the parent of the manifest's manifests/ directory).
//   - `target` placeholders resolve from the environment:
//       ~/.claude                  -> $CLAUDE_HOME (default $HOME/.claude)
//       ~/.codex                   -> $CODEX_HOME (default $HOME/.codex)
//       ~/.local/bin               -> $FIREFLY_BIN_DIR (default $HOME/.local/bin)
//       <openspec-root>            -> $FIREFLY_OPENSPEC_ROOT (required)
//       <claude-superpowers-root>  -> $FIREFLY_SUPERPOWERS_ROOT (required)
//   - `source-mirror` entries carry a `paths` array and expand to one line per
//     mirrored path: <repo-root>/<path> -> <target>/<path>.
//
// Usage: manifest-assets.mjs <manifest-path> [--kinds kind1,kind2,...]
//
// Entries are emitted in manifest file order; --kinds only filters.

import fs from 'node:fs';
import path from 'node:path';

// Exit quietly when the consumer closes the pipe early (e.g. `| head`).
process.stdout.on('error', (error) => {
  if (error.code === 'EPIPE') process.exit(0);
  throw error;
});

function fail(message) {
  console.error(`manifest-assets: ${message}`);
  process.exit(1);
}

function parseArgs(argv) {
  const args = { kinds: null, manifest: null };
  const rest = [...argv];
  while (rest.length > 0) {
    const arg = rest.shift();
    if (arg === '--kinds') {
      const value = rest.shift();
      if (value === undefined) fail('--kinds requires a comma-separated value');
      args.kinds = new Set(value.split(',').filter(Boolean));
    } else if (arg === '--help' || arg === '-h') {
      console.log('usage: manifest-assets.mjs <manifest-path> [--kinds kind1,kind2,...]');
      process.exit(0);
    } else if (arg.startsWith('--')) {
      fail(`unknown option: ${arg}`);
    } else if (args.manifest === null) {
      args.manifest = arg;
    } else {
      fail(`unexpected argument: ${arg}`);
    }
  }
  if (args.manifest === null) fail('missing manifest path');
  return args;
}

function homePath() {
  const home = process.env.HOME;
  if (!home) fail('HOME is not set');
  return home;
}

function expandTarget(original) {
  let target = original;
  if (target.includes('<openspec-root>')) {
    const root = process.env.FIREFLY_OPENSPEC_ROOT;
    if (!root) fail('FIREFLY_OPENSPEC_ROOT is required to resolve <openspec-root> targets');
    target = target.split('<openspec-root>').join(root);
  }
  if (target.includes('<claude-superpowers-root>')) {
    const root = process.env.FIREFLY_SUPERPOWERS_ROOT;
    if (!root) fail('FIREFLY_SUPERPOWERS_ROOT is required to resolve <claude-superpowers-root> targets');
    target = target.split('<claude-superpowers-root>').join(root);
  }
  const homeRoots = [
    ['~/.claude', process.env.CLAUDE_HOME],
    ['~/.codex', process.env.CODEX_HOME],
    ['~/.local/bin', process.env.FIREFLY_BIN_DIR],
  ];
  for (const [prefix, override] of homeRoots) {
    if (target === prefix || target.startsWith(`${prefix}/`)) {
      const base = override || path.join(homePath(), prefix.slice(2));
      return base + target.slice(prefix.length);
    }
  }
  if (target.startsWith('~/')) return path.join(homePath(), target.slice(2));
  return target;
}

function emit(kind, source, target) {
  for (const field of [kind, source, target]) {
    if (/[\t\n]/.test(field)) fail(`refusing to emit field containing TAB or newline: ${field}`);
  }
  process.stdout.write(`${kind}\t${source}\t${target}\n`);
}

function main() {
  const args = parseArgs(process.argv.slice(2));
  const manifestPath = path.resolve(args.manifest);
  const repoRoot = path.dirname(path.dirname(manifestPath));

  let manifest;
  try {
    manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));
  } catch (error) {
    fail(`cannot read manifest ${manifestPath}: ${error.message}`);
  }
  if (!Number.isInteger(manifest.version) || !Array.isArray(manifest.managedAssets)) {
    fail(`manifest ${manifestPath} is missing an integer version or a managedAssets array`);
  }

  for (const entry of manifest.managedAssets) {
    if (!entry || typeof entry.id !== 'string' || typeof entry.kind !== 'string' || typeof entry.target !== 'string') {
      fail(`manifest ${manifestPath} has a managedAssets entry without id/kind/target`);
    }
    if (args.kinds && !args.kinds.has(entry.kind)) continue;

    if (entry.kind === 'source-mirror') {
      if (!Array.isArray(entry.paths) || entry.paths.length === 0) {
        fail(`source-mirror entry ${entry.id} needs a non-empty paths array`);
      }
      const targetBase = expandTarget(entry.target);
      for (const rel of entry.paths) {
        emit(entry.kind, path.join(repoRoot, rel), path.join(targetBase, rel));
      }
      continue;
    }

    if (typeof entry.source !== 'string') {
      fail(`entry ${entry.id} is missing a source`);
    }
    emit(entry.kind, path.resolve(repoRoot, entry.source), expandTarget(entry.target));
  }
}

main();

#!/usr/bin/env node
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawnSync } from 'node:child_process';

const ENGLISH_MODAL_PATTERN = /\b(?:SHALL|MUST)\b/;
const CHINESE_MODAL_PATTERN = /必须|不得|禁止|应当/;
const REQUIREMENT_HEADER_PATTERN = /^###\s+Requirement:\s*(.+)\s*$/i;
const SCENARIO_HEADER_PATTERN = /^####\s+/;
const METADATA_PATTERN = /^\*\*[^*]+\*\*:/;
const UNSUPPORTED_CHINESE_STRUCTURE = [
  { pattern: /^##\s+需求\s*$/, name: '## 需求' },
  { pattern: /^###\s+需求\s*:/, name: '### 需求:' },
  { pattern: /^####\s+场景\s*:/, name: '#### 场景:' },
];

function parseRoot(args) {
  const rootIndex = args.indexOf('--root');
  if (rootIndex === -1) return process.cwd();
  if (!args[rootIndex + 1]) throw new Error('--root requires a project directory');
  return path.resolve(args[rootIndex + 1]);
}

function specFiles(directory) {
  if (!fs.existsSync(directory)) return [];
  return fs.readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const filePath = path.join(directory, entry.name);
    if (entry.isDirectory()) return specFiles(filePath);
    return entry.name === 'spec.md' ? [filePath] : [];
  });
}

function sectionEnd(lines, start) {
  for (let index = start + 1; index < lines.length; index += 1) {
    if (/^##\s+/.test(lines[index])) return index;
  }
  return lines.length;
}

function sectionRanges(lines, mainSpec) {
  if (mainSpec) {
    const start = lines.findIndex(line => /^##\s+Requirements\s*$/i.test(line));
    return start < 0 ? [] : [{ start, end: sectionEnd(lines, start) }];
  }
  const ranges = [];
  for (let index = 0; index < lines.length; index += 1) {
    if (/^##\s+(?:ADDED|MODIFIED)\s+Requirements\s*$/i.test(lines[index])) {
      ranges.push({ start: index, end: sectionEnd(lines, index) });
    }
  }
  return ranges;
}

function findRequirementBody(lines, headerIndex, end) {
  const body = [];
  for (let index = headerIndex + 1; index < end; index += 1) {
    const text = lines[index].trim();
    if (SCENARIO_HEADER_PATTERN.test(text) || REQUIREMENT_HEADER_PATTERN.test(text)) break;
    if (!text || METADATA_PATTERN.test(text)) continue;
    body.push({ index, text });
  }
  return body;
}

function findUnsupportedStructure(lines) {
  for (const { pattern, name } of UNSUPPORTED_CHINESE_STRUCTURE) {
    const index = lines.findIndex(line => pattern.test(line));
    if (index >= 0) return { index, name };
  }
  return undefined;
}

function inspectSpec(root, filePath, mainSpec) {
  const relativePath = path.relative(root, filePath);
  const lines = fs.readFileSync(filePath, 'utf8').split(/\r?\n/);
  const unsupported = findUnsupportedStructure(lines);
  if (unsupported) {
    return {
      issues: [`${relativePath}:${unsupported.index + 1} 不支持中文结构标题 ${unsupported.name}；请保留 OpenSpec 英文结构标题`],
      injections: [],
    };
  }

  const issues = [];
  const injections = [];
  for (const { start, end } of sectionRanges(lines, mainSpec)) {
    for (let index = start + 1; index < end; index += 1) {
      if (!REQUIREMENT_HEADER_PATTERN.test(lines[index])) continue;
      const body = findRequirementBody(lines, index, end);
      if (body.length === 0) {
        issues.push(`${relativePath}:${index + 1} Requirement 缺少需求正文`);
        continue;
      }
      const englishModal = body.find(entry => ENGLISH_MODAL_PATTERN.test(entry.text));
      const chineseModal = body.find(entry => CHINESE_MODAL_PATTERN.test(entry.text));
      const hasEnglishModal = Boolean(englishModal);
      const hasChineseModal = Boolean(chineseModal);
      if (!hasEnglishModal && !hasChineseModal) {
        issues.push(`${relativePath}:${body[0].index + 1} Requirement 缺少强制词（SHALL、MUST、必须、不得、禁止或应当）`);
        continue;
      }
      if (!hasEnglishModal && chineseModal) injections.push(chineseModal.index);
    }
  }
  return { issues, injections };
}

function parseSchema(config) {
  const lines = config.replace(/^\uFEFF/, '').split(/\r?\n/);
  const schemaIndex = lines.findIndex(line => /^schema\s*:/.test(line));
  if (schemaIndex < 0) return undefined;

  const scalar = lines[schemaIndex].replace(/^schema\s*:\s*/, '');
  const normalizedScalar = scalar.replace(/^(?:(?:!!|!|&)[^\s]+\s*)+/, '').trim();
  if (/^[>|][+-]?\d*\s*(?:#.*)?$/.test(normalizedScalar)) {
    const blockLines = [];
    for (let index = schemaIndex + 1; index < lines.length; index += 1) {
      const line = lines[index];
      if (line.trim() && !/^\s+/.test(line)) break;
      if (line.trim()) blockLines.push(line.trim());
    }
    return blockLines.join(' ').trim();
  }

  const doubleQuoted = normalizedScalar.match(/^"((?:\\.|[^"])*)"\s*(?:#.*)?$/);
  if (doubleQuoted) return JSON.parse(`"${doubleQuoted[1]}"`);
  const singleQuoted = normalizedScalar.match(/^'((?:''|[^'])*)'\s*(?:#.*)?$/);
  if (singleQuoted) return singleQuoted[1].replace(/''/g, "'");
  return normalizedScalar.replace(/\s+#.*$/, '').trim();
}

function requireSpecDriven(root) {
  const configPath = path.join(root, 'openspec', 'config.yaml');
  if (!fs.existsSync(configPath)) throw new Error(`未找到 OpenSpec 配置：${configPath}`);
  const schema = parseSchema(fs.readFileSync(configPath, 'utf8'));
  if (schema !== 'spec-driven') {
    throw new Error(`中文严格校验适配器仅支持 spec-driven schema，当前为：${schema ?? '未配置'}`);
  }
}

function activeChangeFiles(root) {
  const changesDir = path.join(root, 'openspec', 'changes');
  if (!fs.existsSync(changesDir)) return [];
  return fs.readdirSync(changesDir, { withFileTypes: true }).flatMap(entry => {
    if (!entry.isDirectory() || entry.name === 'archive' || entry.name.startsWith('.')) return [];
    const changeDir = path.join(changesDir, entry.name);
    if (!fs.existsSync(path.join(changeDir, 'proposal.md'))) return [];
    return specFiles(path.join(changeDir, 'specs'));
  });
}

function collectInspections(root) {
  const mainFiles = specFiles(path.join(root, 'openspec', 'specs'));
  const changeFiles = activeChangeFiles(root);
  return [
    ...mainFiles.map(filePath => ({ filePath, mainSpec: true })),
    ...changeFiles.map(filePath => ({ filePath, mainSpec: false })),
  ].map(entry => ({ ...entry, ...inspectSpec(root, entry.filePath, entry.mainSpec) }));
}

function isPathInside(child, parent) {
  const relative = path.relative(parent, child);
  return relative !== '' && !relative.startsWith('..') && !path.isAbsolute(relative);
}

function copyTreeDereferenced(src, dst) {
  const srcStat = fs.lstatSync(src);
  if (srcStat.isSymbolicLink()) {
    const resolved = fs.realpathSync(src);
    return copyTreeDereferenced(resolved, dst);
  }
  if (srcStat.isDirectory()) {
    fs.mkdirSync(dst, { recursive: true });
    for (const entry of fs.readdirSync(src, { withFileTypes: true })) {
      copyTreeDereferenced(path.join(src, entry.name), path.join(dst, entry.name));
    }
    return;
  }
  if (srcStat.isFile()) {
    fs.mkdirSync(path.dirname(dst), { recursive: true });
    fs.copyFileSync(src, dst);
    return;
  }
  throw new Error(`unsupported file type at ${src}`);
}

function safeStagingFile(stagingRoot, root, filePath) {
  const stagingFile = path.join(stagingRoot, path.relative(root, filePath));
  const realStagingFile = fs.realpathSync(stagingFile);
  const realStagingRoot = fs.realpathSync(stagingRoot);
  if (!isPathInside(realStagingFile, realStagingRoot)) {
    throw new Error(`staging file escapes staging root: ${realStagingFile}`);
  }
  const stat = fs.lstatSync(realStagingFile);
  if (!stat.isFile() || stat.isSymbolicLink()) {
    throw new Error(`staging path is not a regular file: ${realStagingFile}`);
  }
  return realStagingFile;
}

function injectNativeModals(stagingRoot, root, inspections) {
  for (const inspection of inspections) {
    if (inspection.injections.length === 0) continue;
    const stagingFile = safeStagingFile(stagingRoot, root, inspection.filePath);
    const lines = fs.readFileSync(stagingFile, 'utf8').split(/\r?\n/);
    for (const index of inspection.injections) lines[index] = `MUST ${lines[index]}`;
    fs.writeFileSync(stagingFile, lines.join('\n'));
  }
}

function runNativeValidation(stagingRoot) {
  let status = 0;
  for (const args of [
    ['validate', '--specs', '--strict', '--no-interactive'],
    ['validate', '--changes', '--strict', '--no-interactive'],
  ]) {
    const result = spawnSync('openspec', args, { cwd: stagingRoot, stdio: 'inherit' });
    if (result.error) {
      console.error(`无法执行 openspec：${result.error.message}`);
      status = 1;
    } else if (result.status !== 0) {
      status = result.status ?? 1;
    }
  }
  return status;
}

function main() {
  const root = parseRoot(process.argv.slice(2));
  requireSpecDriven(root);
  const inspections = collectInspections(root);
  const issues = inspections.flatMap(inspection => inspection.issues);
  if (issues.length > 0) {
    console.error(issues.join('\n'));
    return 1;
  }

  const stagingRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'forgevia-openspec-cn-'));
  try {
    copyTreeDereferenced(path.join(root, 'openspec'), path.join(stagingRoot, 'openspec'));
    injectNativeModals(stagingRoot, root, inspections);
    return runNativeValidation(stagingRoot);
  } finally {
    fs.rmSync(stagingRoot, { recursive: true, force: true });
  }
}

try {
  process.exitCode = main();
} catch (error) {
  console.error(error instanceof Error ? error.message : String(error));
  process.exitCode = 1;
}

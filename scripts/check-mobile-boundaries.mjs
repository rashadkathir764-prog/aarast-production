import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const SCHEMA_VERSION = 1;
const SOURCE_REVISION = 'feafe3db0053d6c66d5f46b56ff9a512861dfbad';
const PROJECT_PACKAGE_PREFIX = 'package:aarast_mobile/';
const RECORD_KINDS = new Set(['core-to-feature', 'direct-cross-feature']);
const ERROR_KINDS = new Set([
  'unresolved-local-target',
  'cross-area-part',
  'invalid-part-contract',
]);
const RECORD_FIELDS = [
  'count',
  'kind',
  'source',
  'sourceArea',
  'target',
  'targetArea',
];

function isIdentifierStart(character) {
  return character !== undefined && /[A-Za-z_$]/.test(character);
}

function isIdentifierPart(character) {
  return character !== undefined && /[A-Za-z0-9_$]/.test(character);
}

function readDartString(sourceText, start, rawPrefix = false) {
  const quoteIndex = rawPrefix ? start + 1 : start;
  const quote = sourceText[quoteIndex];
  const triple = sourceText.slice(quoteIndex, quoteIndex + 3) === quote.repeat(3);
  const delimiterLength = triple ? 3 : 1;
  let index = quoteIndex + delimiterLength;
  let value = '';

  while (index < sourceText.length) {
    if (triple && sourceText.slice(index, index + 3) === quote.repeat(3)) {
      return { value, end: index + 3 };
    }
    if (!triple && sourceText[index] === quote) {
      return { value, end: index + 1 };
    }
    if (!rawPrefix && sourceText[index] === '\\' && index + 1 < sourceText.length) {
      const escaped = sourceText[index + 1];
      const decoded = {
        n: '\n',
        r: '\r',
        t: '\t',
      }[escaped];
      value += decoded ?? escaped;
      index += 2;
      continue;
    }
    value += sourceText[index];
    index += 1;
  }

  return { value, end: sourceText.length };
}

function tokenizeDart(sourceText) {
  const tokens = [];
  let index = 0;
  let braceDepth = 0;
  let bracketDepth = 0;
  let parenthesisDepth = 0;

  while (index < sourceText.length) {
    const character = sourceText[index];
    const next = sourceText[index + 1];

    if (/\s/.test(character)) {
      index += 1;
      continue;
    }
    if (character === '/' && next === '/') {
      index += 2;
      while (index < sourceText.length && !/[\r\n]/.test(sourceText[index])) {
        index += 1;
      }
      continue;
    }
    if (character === '/' && next === '*') {
      let commentDepth = 1;
      index += 2;
      while (index < sourceText.length && commentDepth > 0) {
        if (sourceText[index] === '/' && sourceText[index + 1] === '*') {
          commentDepth += 1;
          index += 2;
        } else if (sourceText[index] === '*' && sourceText[index + 1] === '/') {
          commentDepth -= 1;
          index += 2;
        } else {
          index += 1;
        }
      }
      continue;
    }

    const topLevel = braceDepth === 0
      && bracketDepth === 0
      && parenthesisDepth === 0;
    const rawString = (character === 'r' || character === 'R')
      && (next === "'" || next === '"');
    if (character === "'" || character === '"' || rawString) {
      const parsed = readDartString(sourceText, index, rawString);
      tokens.push({ type: 'string', value: parsed.value, topLevel });
      index = parsed.end;
      continue;
    }
    if (isIdentifierStart(character)) {
      const start = index;
      index += 1;
      while (isIdentifierPart(sourceText[index])) index += 1;
      tokens.push({
        type: 'identifier',
        value: sourceText.slice(start, index),
        topLevel,
      });
      continue;
    }

    tokens.push({ type: 'punctuation', value: character, topLevel });
    if (character === '{') braceDepth += 1;
    else if (character === '}') braceDepth = Math.max(0, braceDepth - 1);
    else if (character === '[') bracketDepth += 1;
    else if (character === ']') bracketDepth = Math.max(0, bracketDepth - 1);
    else if (character === '(') parenthesisDepth += 1;
    else if (character === ')') parenthesisDepth = Math.max(0, parenthesisDepth - 1);
    index += 1;
  }

  return tokens;
}

function nameFromTokens(tokens) {
  return tokens
    .filter((token) => token.type === 'identifier' || token.value === '.')
    .map((token) => token.value)
    .join('');
}

export function parseDartDirectives(sourceText) {
  const tokens = tokenizeDart(String(sourceText));
  const directives = [];

  for (let index = 0; index < tokens.length; index += 1) {
    const token = tokens[index];
    if (
      !token.topLevel
      || token.type !== 'identifier'
      || !['import', 'export', 'part'].includes(token.value)
    ) {
      continue;
    }

    let end = index + 1;
    while (end < tokens.length && tokens[end].value !== ';') end += 1;
    if (end >= tokens.length) continue;
    const body = tokens.slice(index + 1, end);

    if (token.value === 'import' || token.value === 'export') {
      const uris = body
        .filter((candidate) => candidate.type === 'string')
        .map((candidate) => candidate.value);
      if (uris.length > 0) directives.push({ kind: token.value, uris });
    } else if (body[0]?.type === 'identifier' && body[0].value === 'of') {
      const uri = body.slice(1).find((candidate) => candidate.type === 'string');
      if (uri) {
        directives.push({ kind: 'part-of', uris: [uri.value] });
      } else {
        directives.push({
          kind: 'part-of',
          uris: [],
          name: nameFromTokens(body.slice(1)),
        });
      }
    } else {
      const uri = body.find((candidate) => candidate.type === 'string');
      if (uri) directives.push({ kind: 'part', uris: [uri.value] });
    }
    index = end;
  }

  return directives;
}

function normalizeSlashes(value) {
  return value.replace(/\\/g, '/');
}

function isInside(root, target) {
  const relative = path.relative(root, target);
  return relative === ''
    || (!relative.startsWith(`..${path.sep}`) && relative !== '..' && !path.isAbsolute(relative));
}

function repositoryPath(absolutePath, repoRoot) {
  if (!isInside(repoRoot, absolutePath)) {
    return `mobile/lib/<outside>/${path.basename(absolutePath)}`;
  }
  return normalizeSlashes(path.relative(repoRoot, absolutePath));
}

function resolveDartTarget(sourceFile, specifier, mobileLib) {
  if (specifier.startsWith(PROJECT_PACKAGE_PREFIX)) {
    return path.resolve(mobileLib, specifier.slice(PROJECT_PACKAGE_PREFIX.length));
  }
  if (/^[A-Za-z][A-Za-z0-9+.-]*:/.test(specifier)) return null;
  return path.resolve(path.dirname(sourceFile), specifier);
}

function existingMobileFile(target, mobileLib) {
  if (!isInside(mobileLib, target)) return false;
  try {
    return fs.statSync(target).isFile();
  } catch {
    return false;
  }
}

function areaForPath(repositoryFile) {
  const segments = repositoryFile.split('/');
  const libIndex = segments[0] === 'mobile' && segments[1] === 'lib' ? 2 : 0;
  const first = segments[libIndex] || '<unknown>';
  if (first === 'core') return 'core';
  if (first === 'features' && segments[libIndex + 1]) {
    return `features/${segments[libIndex + 1]}`;
  }
  return first;
}

function recordKind(sourceArea, targetArea) {
  if (sourceArea === 'core' && targetArea.startsWith('features/')) {
    return 'core-to-feature';
  }
  if (
    sourceArea.startsWith('features/')
    && targetArea.startsWith('features/')
    && sourceArea !== targetArea
  ) {
    return 'direct-cross-feature';
  }
  return null;
}

function recordKey(item) {
  return [
    item.source,
    item.target,
    item.sourceArea,
    item.targetArea,
    item.kind,
  ].join('|');
}

function errorKey(item) {
  return [item.source, item.target, item.kind].join('|');
}

function compareKeys(left, right, key) {
  const leftKey = key(left);
  const rightKey = key(right);
  return leftKey < rightKey ? -1 : leftKey > rightKey ? 1 : 0;
}

function listDartFiles(root) {
  const files = [];
  function visit(directory) {
    const entries = fs.readdirSync(directory, { withFileTypes: true })
      .sort((left, right) => left.name.localeCompare(right.name, 'en'));
    for (const entry of entries) {
      const target = path.join(directory, entry.name);
      if (entry.isDirectory()) visit(target);
      else if (entry.isFile() && entry.name.endsWith('.dart')) files.push(target);
    }
  }
  visit(root);
  return files.sort((left, right) => normalizeSlashes(left).localeCompare(
    normalizeSlashes(right),
    'en',
  ));
}

export function scanMobileBoundaries({ mobileLib }) {
  const resolvedMobileLib = path.resolve(mobileLib);
  const repoRoot = path.resolve(resolvedMobileLib, '..', '..');
  const records = new Map();
  const errors = new Map();
  const partEdges = [];
  const partOfEdges = [];
  const nameStyleParts = [];

  function addError(item) {
    if (!ERROR_KINDS.has(item.kind)) return;
    errors.set(errorKey(item), item);
  }

  for (const sourceFile of listDartFiles(resolvedMobileLib)) {
    const source = repositoryPath(sourceFile, repoRoot);
    const sourceArea = areaForPath(source);
    const directives = parseDartDirectives(fs.readFileSync(sourceFile, 'utf8'));

    for (const directive of directives) {
      if (directive.kind === 'part-of' && directive.uris.length === 0) {
        nameStyleParts.push({
          sourceFile,
          source,
          name: directive.name || '<invalid-name-style-part-of>',
        });
        continue;
      }

      for (const specifier of directive.uris) {
        const targetFile = resolveDartTarget(sourceFile, specifier, resolvedMobileLib);
        if (targetFile === null) continue;
        const target = repositoryPath(targetFile, repoRoot);
        if (!existingMobileFile(targetFile, resolvedMobileLib)) {
          addError({ source, target, kind: 'unresolved-local-target' });
          continue;
        }

        if (directive.kind === 'part') {
          partEdges.push({ sourceFile, targetFile, source, target });
          continue;
        }
        if (directive.kind === 'part-of') {
          partOfEdges.push({ sourceFile, targetFile, source, target });
          continue;
        }

        const targetArea = areaForPath(target);
        const kind = recordKind(sourceArea, targetArea);
        if (!kind) continue;
        const item = { source, target, sourceArea, targetArea, kind, count: 1 };
        const key = recordKey(item);
        const current = records.get(key);
        if (current) current.count += 1;
        else records.set(key, item);
      }
    }
  }

  const relationships = new Map();
  for (const edge of partEdges) {
    const key = `${edge.sourceFile}\0${edge.targetFile}`;
    const relationship = relationships.get(key) || {
      libraryFile: edge.sourceFile,
      childFile: edge.targetFile,
      part: false,
      partOf: false,
    };
    relationship.part = true;
    relationships.set(key, relationship);
  }
  for (const edge of partOfEdges) {
    const key = `${edge.targetFile}\0${edge.sourceFile}`;
    const relationship = relationships.get(key) || {
      libraryFile: edge.targetFile,
      childFile: edge.sourceFile,
      part: false,
      partOf: false,
    };
    relationship.partOf = true;
    relationships.set(key, relationship);
  }

  const nameStyleCoveredByPart = new Set();
  const sortedRelationships = [...relationships.values()].sort((left, right) => {
    const leftKey = `${left.libraryFile}\0${left.childFile}`;
    const rightKey = `${right.libraryFile}\0${right.childFile}`;
    return leftKey < rightKey ? -1 : leftKey > rightKey ? 1 : 0;
  });
  for (const relationship of sortedRelationships) {
    const library = repositoryPath(relationship.libraryFile, repoRoot);
    const child = repositoryPath(relationship.childFile, repoRoot);
    if (areaForPath(library) !== areaForPath(child)) {
      addError({ source: library, target: child, kind: 'cross-area-part' });
      continue;
    }
    if (!relationship.part || !relationship.partOf) {
      if (relationship.part && !relationship.partOf) {
        nameStyleCoveredByPart.add(relationship.childFile);
        addError({ source: library, target: child, kind: 'invalid-part-contract' });
      } else {
        addError({ source: child, target: library, kind: 'invalid-part-contract' });
      }
    }
  }

  for (const item of nameStyleParts) {
    if (nameStyleCoveredByPart.has(item.sourceFile)) continue;
    addError({
      source: item.source,
      target: item.name,
      kind: 'invalid-part-contract',
    });
  }

  return {
    records: [...records.values()].sort((left, right) => compareKeys(left, right, recordKey)),
    errors: [...errors.values()].sort((left, right) => compareKeys(left, right, errorKey)),
  };
}

export function compareMobileBaseline(current, baseline) {
  const currentRecords = Array.isArray(current) ? current : current.records;
  const baselineRecords = Array.isArray(baseline) ? baseline : baseline.records;
  const allowed = new Map(baselineRecords.map((item) => [recordKey(item), item.count]));
  const additions = currentRecords
    .filter((item) => !allowed.has(recordKey(item)) || item.count > allowed.get(recordKey(item)))
    .sort((left, right) => compareKeys(left, right, recordKey));
  return { ok: additions.length === 0, additions };
}

function sameArray(left, right) {
  return left.length === right.length && left.every((value, index) => value === right[index]);
}

function sensitiveString(value) {
  return path.posix.isAbsolute(value)
    || path.win32.isAbsolute(value)
    || /[A-Za-z][A-Za-z0-9+.-]*:\/\//.test(value)
    || /(?:DATABASE_URL|JWT_SECRET|PASSWORD|SECRET|TOKEN)\s*=/i.test(value)
    || /BEGIN (?:RSA |OPENSSH )?PRIVATE KEY/i.test(value);
}

function assertNoSensitiveStrings(value, visited = new Set()) {
  if (typeof value === 'string') {
    if (sensitiveString(value)) {
      throw new Error('mobile baseline contains an absolute path or secret');
    }
    return;
  }
  if (!value || typeof value !== 'object' || visited.has(value)) return;
  visited.add(value);
  for (const [key, child] of Object.entries(value)) {
    assertNoSensitiveStrings(key, visited);
    assertNoSensitiveStrings(child, visited);
  }
}

function canonicalMobileFile(value) {
  return typeof value === 'string'
    && /^mobile\/lib\/.+\.dart$/.test(value)
    && !value.includes('\\')
    && !value.split('/').some((segment) => segment === '.' || segment === '..')
    && !path.posix.isAbsolute(value)
    && !path.win32.isAbsolute(value);
}

function validateRecord(item) {
  if (!item || typeof item !== 'object' || Array.isArray(item)) {
    throw new Error('mobile baseline contains an invalid record');
  }
  if (!sameArray(Object.keys(item).sort(), RECORD_FIELDS)) {
    throw new Error('mobile baseline record shape is invalid');
  }
  if (!canonicalMobileFile(item.source) || !canonicalMobileFile(item.target)) {
    throw new Error('mobile baseline contains a non-canonical path');
  }
  if (item.sourceArea !== areaForPath(item.source) || item.targetArea !== areaForPath(item.target)) {
    throw new Error('mobile baseline contains an invalid area');
  }
  if (!RECORD_KINDS.has(item.kind) || item.kind !== recordKind(item.sourceArea, item.targetArea)) {
    throw new Error('mobile baseline contains an invalid kind');
  }
  if (!Number.isInteger(item.count) || item.count <= 0) {
    throw new Error('mobile baseline counts must be positive integers');
  }
}

function validateBaseline(value) {
  if (!value || value.schemaVersion !== SCHEMA_VERSION) {
    throw new Error('mobile baseline schemaVersion must be 1');
  }
  if (!sameArray(Object.keys(value).sort(), ['records', 'schemaVersion', 'sourceRevision'])) {
    throw new Error('mobile baseline shape is invalid');
  }
  if (value.sourceRevision !== SOURCE_REVISION) {
    throw new Error('mobile baseline sourceRevision is invalid');
  }
  if (!Array.isArray(value.records)) {
    throw new Error('mobile baseline records must be an array');
  }
  assertNoSensitiveStrings(value);
  for (const item of value.records) validateRecord(item);
  const keys = value.records.map(recordKey);
  if (!sameArray(keys, [...keys].sort()) || new Set(keys).size !== keys.length) {
    throw new Error('mobile baseline keys must be sorted and unique');
  }
  return value;
}

function sortedRecords(records) {
  return [...records].sort((left, right) => compareKeys(left, right, recordKey));
}

function strictViolation(item) {
  const targetFeature = item.targetArea.startsWith('features/')
    ? item.targetArea.slice('features/'.length)
    : null;
  const isFeatureApi = targetFeature !== null
    && item.target === `mobile/lib/features/${targetFeature}/${targetFeature}_api.dart`;
  if (item.kind === 'direct-cross-feature') return !isFeatureApi;
  if (item.kind === 'core-to-feature') {
    return !(
      /^mobile\/lib\/core\/routing\/.+\.dart$/.test(item.source)
      && isFeatureApi
    );
  }
  return true;
}

function sanitizeMessage(value) {
  const firstLine = String(value || 'unknown error').split(/\r?\n/, 1)[0];
  return firstLine
    .replace(/[A-Za-z]:[\\/][^\s:]*/g, '<path>')
    .replace(/\/(?:[^\s/:]+\/)+[^\s:]*/g, '<path>');
}

function writeLine(target, message) {
  if (typeof target === 'function') target(message);
  else if (target && typeof target.write === 'function') target.write(`${message}\n`);
}

function validateScan(value) {
  if (!value || !Array.isArray(value.records) || !Array.isArray(value.errors)) {
    throw new Error('mobile boundary scan result is invalid');
  }
  for (const item of value.records) validateRecord(item);
  for (const item of value.errors) {
    if (
      !item
      || typeof item.source !== 'string'
      || typeof item.target !== 'string'
      || !ERROR_KINDS.has(item.kind)
    ) {
      throw new Error('mobile boundary scan error is invalid');
    }
  }
  return {
    records: sortedRecords(value.records),
    errors: [...value.errors].sort((left, right) => compareKeys(left, right, errorKey)),
  };
}

export function runCli(dependencies) {
  const argv = dependencies.argv || [];
  if (
    argv.length !== 1
    || !['--write-baseline', '--check-baseline', '--strict'].includes(argv[0])
  ) {
    writeLine(
      dependencies.stderr,
      'usage: check-mobile-boundaries.mjs --write-baseline | --check-baseline | --strict',
    );
    return 2;
  }

  try {
    const current = validateScan(dependencies.scan());
    if (current.errors.length > 0) {
      writeLine(
        dependencies.stderr,
        `mobile boundary scan errors (${current.errors.length} records)`,
      );
      for (const item of current.errors) {
        writeLine(dependencies.stderr, `${item.kind}: ${item.source} -> ${item.target}`);
      }
      return 1;
    }

    if (argv[0] === '--write-baseline') {
      if (typeof dependencies.writeBaseline !== 'function') {
        throw new Error('mobile baseline writer is unavailable');
      }
      const value = validateBaseline({
        schemaVersion: SCHEMA_VERSION,
        sourceRevision: SOURCE_REVISION,
        records: current.records,
      });
      dependencies.writeBaseline(value);
      writeLine(dependencies.stdout, `mobile boundary baseline written (${value.records.length} records)`);
      return 0;
    }

    if (argv[0] === '--strict') {
      const violations = current.records.filter(strictViolation);
      if (violations.length > 0) {
        writeLine(
          dependencies.stderr,
          `strict mobile boundary violations (${violations.length} records)`,
        );
        for (const item of violations) {
          writeLine(dependencies.stderr, `${recordKey(item)} count=${item.count}`);
        }
        return 1;
      }
      writeLine(dependencies.stdout, 'strict mobile boundary check passed');
      return 0;
    }

    const saved = validateBaseline(dependencies.readBaseline());
    const comparison = compareMobileBaseline(current.records, saved.records);
    if (!comparison.ok) {
      writeLine(
        dependencies.stderr,
        `mobile boundary violations added (${comparison.additions.length} records)`,
      );
      for (const item of comparison.additions) {
        writeLine(dependencies.stderr, `${recordKey(item)} count=${item.count}`);
      }
      return 1;
    }
    writeLine(
      dependencies.stdout,
      `mobile boundary baseline check passed (${current.records.length} current records)`,
    );
    return 0;
  } catch (error) {
    writeLine(
      dependencies.stderr,
      `mobile boundary configuration error: ${sanitizeMessage(error?.message)}`,
    );
    return 2;
  }
}

function defaultDependencies(argv) {
  const scriptFile = fileURLToPath(import.meta.url);
  const repoRoot = path.resolve(path.dirname(scriptFile), '..');
  const mobileLib = path.join(repoRoot, 'mobile', 'lib');
  const baselinePath = path.join(
    repoRoot,
    'scripts',
    'architecture',
    'mobile-boundaries-baseline.json',
  );
  return {
    argv,
    scan: () => scanMobileBoundaries({ mobileLib }),
    readBaseline: () => JSON.parse(fs.readFileSync(baselinePath, 'utf8')),
    writeBaseline: (value) => fs.writeFileSync(
      baselinePath,
      `${JSON.stringify(value, null, 2)}\n`,
      'utf8',
    ),
    stdout: (message) => process.stdout.write(`${message}\n`),
    stderr: (message) => process.stderr.write(`${message}\n`),
  };
}

const invokedDirectly = process.argv[1]
  && pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url;
if (invokedDirectly) {
  process.exitCode = runCli(defaultDependencies(process.argv.slice(2)));
}

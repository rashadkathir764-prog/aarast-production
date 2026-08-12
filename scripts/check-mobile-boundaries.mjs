import fs from 'node:fs';
import path from 'node:path';
import { types as utilTypes } from 'node:util';
import { fileURLToPath, pathToFileURL } from 'node:url';

const SCHEMA_VERSION = 1;
const SOURCE_REVISION = 'feafe3db0053d6c66d5f46b56ff9a512861dfbad';
const PROJECT_PACKAGE_PREFIX = 'package:aarast_mobile/';
const DART_RESERVED_WORDS = new Set([
  'assert', 'break', 'case', 'catch', 'class', 'const', 'continue',
  'default', 'do', 'else', 'enum', 'extends', 'false', 'final', 'finally',
  'for', 'if', 'in', 'is', 'new', 'null', 'rethrow', 'return', 'super',
  'switch', 'this', 'throw', 'true', 'try', 'var', 'void', 'while', 'with',
]);
const DART_BUILT_IN_IDENTIFIERS = new Set([
  'abstract', 'as', 'covariant', 'deferred', 'dynamic', 'export',
  'external', 'extension', 'factory', 'Function', 'get', 'implements',
  'import', 'interface', 'late', 'library', 'mixin', 'operator', 'part',
  'required', 'set', 'static', 'type', 'typedef',
]);
const DART_CONTEXTUAL_IDENTIFIERS = new Set([
  'async', 'await', 'base', 'hide', 'of', 'on', 'sealed', 'show', 'sync',
  'when', 'yield',
]);
const RECORD_KINDS = new Set(['core-to-feature', 'direct-cross-feature']);
const ERROR_KINDS = new Set([
  'unresolved-local-target',
  'cross-area-part',
  'invalid-part-contract',
]);
const ERROR_MESSAGES = new Map([
  ['unresolved-local-target', 'unresolved-local-target'],
  ['cross-area-part', 'cross-area-part'],
  ['invalid-part-contract', 'invalid-part-contract'],
]);
const ERROR_TARGET_PLACEHOLDER = 'mobile/lib/__unresolved_local_target__.dart';
const MAX_COLLECTION_LENGTH = 10_000;
const MAX_PATH_LENGTH = 512;
const MAX_RECORD_COUNT = 1_000_000;
const RECORD_FIELDS = [
  'count',
  'kind',
  'source',
  'sourceArea',
  'target',
  'targetArea',
];
const ERROR_FIELDS = ['kind', 'source', 'target'];
const SCAN_FIELDS = ['errors', 'records'];
const BASELINE_FIELDS = ['records', 'schemaVersion', 'sourceRevision'];

function isIdentifierStart(character) {
  // Keep the scanner's existing ASCII lexical surface explicit. Unicode
  // identifier support would require a separate lexer change and fixtures.
  return character !== undefined && /[A-Za-z_$]/.test(character);
}

function isIdentifierPart(character) {
  return character !== undefined && /[A-Za-z0-9_$]/.test(character);
}

function dartIdentifierKind(value) {
  if (DART_RESERVED_WORDS.has(value)) return 'reserved';
  if (DART_BUILT_IN_IDENTIFIERS.has(value)) return 'built-in';
  if (DART_CONTEXTUAL_IDENTIFIERS.has(value)) return 'contextual';
  return 'ordinary';
}

function isDartIdentifierToken(token) {
  return token?.type === 'identifier' && token.identifierKind !== 'reserved';
}

function isDartTypeIdentifierToken(token) {
  if (!isDartIdentifierToken(token)) return false;
  return token.identifierKind === 'ordinary'
    || token.identifierKind === 'contextual'
    // Dart 3.11.5 accepts `type` as an import prefix even though the current
    // keywords reference classifies it as a built-in identifier.
    || token.value === 'type';
}

function invalidDartSource() {
  throw new Error('invalid Dart source');
}

function decodeUnicodeScalar(hex) {
  const value = Number.parseInt(hex, 16);
  if (
    !Number.isInteger(value)
    || value > 0x10FFFF
    || (value >= 0xD800 && value <= 0xDFFF)
  ) {
    invalidDartSource();
  }
  return String.fromCodePoint(value);
}

function lineBreakLength(sourceText, index) {
  if (sourceText[index] === '\n') return 1;
  if (sourceText[index] === '\r') return sourceText[index + 1] === '\n' ? 2 : 1;
  return 0;
}

function skipNestedBlockComment(sourceText, start) {
  let commentDepth = 1;
  let index = start + 2;
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
  if (commentDepth !== 0) invalidDartSource();
  return index;
}

function skipDartInterpolationExpression(sourceText, start) {
  let index = start;
  let braceDepth = 1;

  while (index < sourceText.length) {
    const character = sourceText[index];
    const next = sourceText[index + 1];

    if (character === '/' && next === '/') {
      index += 2;
      while (index < sourceText.length && !/[\r\n]/.test(sourceText[index])) {
        index += 1;
      }
      continue;
    }
    if (character === '/' && next === '*') {
      index = skipNestedBlockComment(sourceText, index);
      continue;
    }

    const rawString = character === 'r' && (next === "'" || next === '"');
    if (character === "'" || character === '"' || rawString) {
      index = readDartString(sourceText, index, rawString).end;
      continue;
    }
    if (isIdentifierStart(character)) {
      index += 1;
      while (isIdentifierPart(sourceText[index])) index += 1;
      continue;
    }
    if (character === '{') {
      braceDepth += 1;
      index += 1;
      continue;
    }
    if (character === '}') {
      braceDepth -= 1;
      index += 1;
      if (braceDepth === 0) return index;
      continue;
    }
    index += 1;
  }

  invalidDartSource();
}

function readDartString(sourceText, start, rawPrefix = false) {
  const quoteIndex = rawPrefix ? start + 1 : start;
  const quote = sourceText[quoteIndex];
  const triple = sourceText.slice(quoteIndex, quoteIndex + 3) === quote.repeat(3);
  const delimiterLength = triple ? 3 : 1;
  let index = quoteIndex + delimiterLength;
  let value = '';
  let interpolated = false;

  if (triple) {
    const ignoredFirstLine = sourceText
      .slice(index)
      .match(/^(?:\\)?[ \t]*(?:\r\n|\r|\n)/)?.[0];
    if (ignoredFirstLine !== undefined) index += ignoredFirstLine.length;
  }

  while (index < sourceText.length) {
    if (triple && sourceText.slice(index, index + 3) === quote.repeat(3)) {
      return { value, end: index + 3, interpolated };
    }
    if (!triple && sourceText[index] === quote) {
      return { value, end: index + 1, interpolated };
    }
    const breakLength = lineBreakLength(sourceText, index);
    if (triple && breakLength > 0) {
      value += '\n';
      index += breakLength;
      continue;
    }
    if (!triple && /[\r\n]/.test(sourceText[index])) invalidDartSource();
    if (!rawPrefix && sourceText[index] === '\\') {
      if (index + 1 >= sourceText.length || /[\r\n]/.test(sourceText[index + 1])) {
        invalidDartSource();
      }
      const escaped = sourceText[index + 1];
      const control = {
        n: '\n',
        r: '\r',
        f: '\f',
        b: '\b',
        t: '\t',
        v: '\v',
      }[escaped];
      if (control !== undefined) {
        value += control;
        index += 2;
        continue;
      }
      if (escaped === 'x') {
        const hex = sourceText.slice(index + 2, index + 4);
        if (!/^[0-9A-Fa-f]{2}$/.test(hex)) invalidDartSource();
        value += decodeUnicodeScalar(hex);
        index += 4;
        continue;
      }
      if (escaped === 'u') {
        if (sourceText[index + 2] === '{') {
          const close = sourceText.indexOf('}', index + 3);
          if (close === -1) invalidDartSource();
          const hex = sourceText.slice(index + 3, close);
          if (!/^[0-9A-Fa-f]{1,6}$/.test(hex)) invalidDartSource();
          value += decodeUnicodeScalar(hex);
          index = close + 1;
          continue;
        }
        const hex = sourceText.slice(index + 2, index + 6);
        if (!/^[0-9A-Fa-f]{4}$/.test(hex)) invalidDartSource();
        value += decodeUnicodeScalar(hex);
        index += 6;
        continue;
      }
      value += escaped;
      index += 2;
      continue;
    }
    if (!rawPrefix && sourceText[index] === '$') {
      interpolated = true;
      if (sourceText[index + 1] === '{') {
        index = skipDartInterpolationExpression(sourceText, index + 2);
        continue;
      }
      if (!isIdentifierStart(sourceText[index + 1])) invalidDartSource();
      index += 2;
      while (isIdentifierPart(sourceText[index])) index += 1;
      continue;
    }
    value += sourceText[index];
    index += 1;
  }

  invalidDartSource();
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
      index = skipNestedBlockComment(sourceText, index);
      continue;
    }

    const topLevel = braceDepth === 0
      && bracketDepth === 0
      && parenthesisDepth === 0;
    const rawString = character === 'r' && (next === "'" || next === '"');
    if (character === "'" || character === '"' || rawString) {
      const parsed = readDartString(sourceText, index, rawString);
      tokens.push({
        type: 'string',
        value: parsed.value,
        interpolated: parsed.interpolated,
        topLevel,
      });
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
        identifierKind: dartIdentifierKind(sourceText.slice(start, index)),
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

function readStringLiteral(tokens, start) {
  if (tokens[start]?.type !== 'string') return null;
  let end = start;
  let value = '';
  while (tokens[end]?.type === 'string') {
    if (tokens[end].interpolated) invalidDartSource();
    value += tokens[end].value;
    end += 1;
  }
  return { value, end };
}

function readDottedIdentifierList(tokens, start) {
  if (!isDartIdentifierToken(tokens[start])) return null;
  const values = [tokens[start].value];
  let end = start + 1;
  while (tokens[end]?.value === '.') {
    if (!isDartIdentifierToken(tokens[end + 1])) invalidDartSource();
    values.push(tokens[end + 1].value);
    end += 2;
  }
  return { value: values.join('.'), end };
}

function readConfigurableUri(tokens, start = 0) {
  const primary = readStringLiteral(tokens, start);
  if (primary === null) invalidDartSource();
  const uris = [primary.value];
  let end = primary.end;

  while (tokens[end]?.type === 'identifier' && tokens[end].value === 'if') {
    end += 1;
    if (tokens[end]?.value !== '(') invalidDartSource();
    end += 1;
    const testName = readDottedIdentifierList(tokens, end);
    if (testName === null) invalidDartSource();
    end = testName.end;
    if (tokens[end]?.value === '=' && tokens[end + 1]?.value === '=') {
      const expected = readStringLiteral(tokens, end + 2);
      if (expected === null) invalidDartSource();
      end = expected.end;
    }
    if (tokens[end]?.value !== ')') invalidDartSource();
    const alternative = readStringLiteral(tokens, end + 1);
    if (alternative === null) invalidDartSource();
    uris.push(alternative.value);
    end = alternative.end;
  }

  return { uris, end };
}

function readCombinators(tokens, start) {
  let end = start;
  while (
    tokens[end]?.type === 'identifier'
    && (tokens[end].value === 'show' || tokens[end].value === 'hide')
  ) {
    end += 1;
    if (!isDartIdentifierToken(tokens[end])) invalidDartSource();
    end += 1;
    while (tokens[end]?.value === ',') {
      if (!isDartIdentifierToken(tokens[end + 1])) invalidDartSource();
      end += 2;
    }
  }
  return end;
}

function parseImportOrExport(kind, body) {
  const configurable = readConfigurableUri(body);
  let end = configurable.end;
  if (kind === 'import') {
    if (body[end]?.type === 'identifier' && body[end].value === 'deferred') {
      end += 1;
      if (body[end]?.type !== 'identifier' || body[end].value !== 'as') {
        invalidDartSource();
      }
    }
    if (body[end]?.type === 'identifier' && body[end].value === 'as') {
      end += 1;
      if (!isDartTypeIdentifierToken(body[end])) invalidDartSource();
      end += 1;
    }
  }
  end = readCombinators(body, end);
  if (end !== body.length) invalidDartSource();
  return { kind, uris: configurable.uris };
}

function parsePart(body) {
  if (body[0]?.type === 'identifier' && body[0].value === 'of') {
    const uri = readStringLiteral(body, 1);
    if (uri !== null) {
      if (uri.end !== body.length) invalidDartSource();
      return { kind: 'part-of', uris: [uri.value] };
    }
    const name = readDottedIdentifierList(body, 1);
    if (name === null || name.end !== body.length) invalidDartSource();
    return { kind: 'part-of', uris: [], name: name.value };
  }
  const uri = readStringLiteral(body, 0);
  if (uri === null || uri.end !== body.length) invalidDartSource();
  return { kind: 'part', uris: [uri.value] };
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
    while (
      end < tokens.length
      && !(tokens[end].topLevel && tokens[end].value === ';')
    ) end += 1;
    if (end >= tokens.length) invalidDartSource();
    const body = tokens.slice(index + 1, end);
    if (token.value === 'import' || token.value === 'export') {
      directives.push(parseImportOrExport(token.value, body));
    } else {
      directives.push(parsePart(body));
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

function resolveCanonicalMobileFile(target, mobileLib, realMobileLib) {
  if (!isInside(mobileLib, target)) return null;
  try {
    const realTarget = fs.realpathSync.native(target);
    if (!isInside(realMobileLib, realTarget) || !fs.statSync(realTarget).isFile()) {
      return null;
    }
    return realTarget;
  } catch {
    return null;
  }
}

function canonicalMobileRepositoryPath(absolutePath, mobileRoot) {
  return `mobile/lib/${normalizeSlashes(path.relative(mobileRoot, absolutePath))}`;
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
  const realMobileLib = fs.realpathSync.native(resolvedMobileLib);
  const repoRoot = path.resolve(resolvedMobileLib, '..', '..');
  const records = new Map();
  const errors = new Map();
  const partEdges = [];
  const partOfEdges = [];
  const nameStyleParts = [];

  function addError(item) {
    if (!ERROR_KINDS.has(item.kind)) invalidDartSource();
    const safeItem = {
      source: item.source,
      target: canonicalMobileFile(item.target)
        ? item.target
        : ERROR_TARGET_PLACEHOLDER,
      kind: item.kind,
    };
    errors.set(errorKey(safeItem), safeItem);
  }

  for (const sourceFile of listDartFiles(resolvedMobileLib)) {
    const source = repositoryPath(sourceFile, repoRoot);
    const sourceArea = areaForPath(source);
    const realSourceFile = fs.realpathSync.native(sourceFile);
    const realSource = canonicalMobileRepositoryPath(realSourceFile, realMobileLib);
    const realSourceArea = areaForPath(realSource);
    if (sourceArea !== realSourceArea) {
      addError({ source, target: realSource, kind: 'unresolved-local-target' });
      continue;
    }
    const directives = parseDartDirectives(fs.readFileSync(sourceFile, 'utf8'));

    for (const directive of directives) {
      if (directive.kind === 'part-of' && directive.uris.length === 0) {
        nameStyleParts.push({
          sourceFile: realSourceFile,
          source,
          name: directive.name || '<invalid-name-style-part-of>',
        });
        continue;
      }

      for (const specifier of directive.uris) {
        const targetFile = resolveDartTarget(sourceFile, specifier, resolvedMobileLib);
        if (targetFile === null) continue;
        const target = repositoryPath(targetFile, repoRoot);
        const realTargetFile = resolveCanonicalMobileFile(
          targetFile,
          resolvedMobileLib,
          realMobileLib,
        );
        if (realTargetFile === null) {
          addError({ source, target, kind: 'unresolved-local-target' });
          continue;
        }
        const logicalTargetArea = areaForPath(target);
        const realTarget = canonicalMobileRepositoryPath(realTargetFile, realMobileLib);
        const realTargetArea = areaForPath(realTarget);
        if (logicalTargetArea !== realTargetArea) {
          addError({ source, target, kind: 'unresolved-local-target' });
          continue;
        }

        if (directive.kind === 'part') {
          partEdges.push({
            sourceFile: realSourceFile,
            targetFile: realTargetFile,
            source,
            target,
          });
          continue;
        }
        if (directive.kind === 'part-of') {
          partOfEdges.push({
            sourceFile: realSourceFile,
            targetFile: realTargetFile,
            source,
            target,
          });
          continue;
        }

        const targetArea = logicalTargetArea;
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
      library: edge.source,
      child: edge.target,
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
      library: edge.target,
      child: edge.source,
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
    const library = relationship.library;
    const child = relationship.child;
    const realLibrary = canonicalMobileRepositoryPath(
      relationship.libraryFile,
      realMobileLib,
    );
    const realChild = canonicalMobileRepositoryPath(
      relationship.childFile,
      realMobileLib,
    );
    if (areaForPath(realLibrary) !== areaForPath(realChild)) {
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

function canonicalMobileFile(value) {
  if (
    typeof value !== 'string'
    || value.length === 0
    || value.length > MAX_PATH_LENGTH
    || !value.startsWith('mobile/lib/')
    || !value.endsWith('.dart')
    || value.includes('\\')
    || /[\u0000-\u001F\u007F-\u009F:=?*"<>|%]/.test(value)
    || path.posix.isAbsolute(value)
    || path.win32.isAbsolute(value)
    || path.posix.normalize(value) !== value
  ) return false;
  const segments = value.split('/');
  if (segments[0] !== 'mobile' || segments[1] !== 'lib' || segments.length < 3) {
    return false;
  }
  return segments.slice(2).every((segment) => (
    segment !== ''
    && segment !== '.'
    && segment !== '..'
    && /^[A-Za-z0-9_.$'{}@+-]+$/.test(segment)
  ));
}

function readPlainObject(value, expectedFields) {
  if (
    value === null
    || typeof value !== 'object'
    || Array.isArray(value)
    || utilTypes.isProxy(value)
    || Object.getPrototypeOf(value) !== Object.prototype
  ) {
    throw new Error('invalid plain object');
  }
  const ownKeys = Reflect.ownKeys(value);
  if (
    ownKeys.some((key) => typeof key !== 'string')
    || !sameArray([...ownKeys].sort(), expectedFields)
  ) {
    throw new Error('invalid plain object shape');
  }
  const result = {};
  for (const field of expectedFields) {
    const descriptor = Object.getOwnPropertyDescriptor(value, field);
    if (!descriptor || !Object.hasOwn(descriptor, 'value') || !descriptor.enumerable) {
      throw new Error('invalid plain object field');
    }
    result[field] = descriptor.value;
  }
  return result;
}

function readDenseArray(value, maximumLength = MAX_COLLECTION_LENGTH) {
  if (
    value === null
    || typeof value !== 'object'
    || utilTypes.isProxy(value)
    || !Array.isArray(value)
    || Object.getPrototypeOf(value) !== Array.prototype
  ) {
    throw new Error('invalid dense array');
  }
  const lengthDescriptor = Object.getOwnPropertyDescriptor(value, 'length');
  if (
    !lengthDescriptor
    || !Object.hasOwn(lengthDescriptor, 'value')
    || !Number.isSafeInteger(lengthDescriptor.value)
    || lengthDescriptor.value < 0
    || lengthDescriptor.value > maximumLength
  ) {
    throw new Error('invalid dense array length');
  }
  const ownKeys = Reflect.ownKeys(value);
  if (
    ownKeys.some((key) => typeof key !== 'string')
    || ownKeys.length !== lengthDescriptor.value + 1
  ) {
    throw new Error('invalid dense array shape');
  }
  const result = [];
  for (let index = 0; index < lengthDescriptor.value; index += 1) {
    const descriptor = Object.getOwnPropertyDescriptor(value, String(index));
    if (!descriptor || !Object.hasOwn(descriptor, 'value') || !descriptor.enumerable) {
      throw new Error('invalid dense array item');
    }
    result.push(descriptor.value);
  }
  return result;
}

function validateRecord(value) {
  const item = readPlainObject(value, RECORD_FIELDS);
  if (!canonicalMobileFile(item.source) || !canonicalMobileFile(item.target)) {
    throw new Error('invalid record path');
  }
  if (
    typeof item.sourceArea !== 'string'
    || typeof item.targetArea !== 'string'
    || item.sourceArea !== areaForPath(item.source)
    || item.targetArea !== areaForPath(item.target)
  ) {
    throw new Error('invalid record area');
  }
  if (!RECORD_KINDS.has(item.kind) || item.kind !== recordKind(item.sourceArea, item.targetArea)) {
    throw new Error('invalid record kind');
  }
  if (
    !Number.isSafeInteger(item.count)
    || item.count <= 0
    || item.count > MAX_RECORD_COUNT
  ) {
    throw new Error('invalid record count');
  }
  return item;
}

function validateError(value) {
  const item = readPlainObject(value, ERROR_FIELDS);
  if (
    !canonicalMobileFile(item.source)
    || !canonicalMobileFile(item.target)
    || !ERROR_KINDS.has(item.kind)
  ) {
    throw new Error('invalid scan error');
  }
  return item;
}

function validateBaseline(value) {
  const baseline = readPlainObject(value, BASELINE_FIELDS);
  if (baseline.schemaVersion !== SCHEMA_VERSION) {
    throw new Error('invalid baseline schemaVersion');
  }
  if (baseline.sourceRevision !== SOURCE_REVISION) {
    throw new Error('invalid baseline sourceRevision');
  }
  const records = readDenseArray(baseline.records).map(validateRecord);
  const keys = records.map(recordKey);
  if (!sameArray(keys, [...keys].sort()) || new Set(keys).size !== keys.length) {
    throw new Error('invalid baseline record ordering');
  }
  return {
    schemaVersion: SCHEMA_VERSION,
    sourceRevision: SOURCE_REVISION,
    records,
  };
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

function writeLine(target, message) {
  if (typeof target === 'function') target(message);
  else if (target && typeof target.write === 'function') target.write(`${message}\n`);
}

function validateScan(value) {
  const scan = readPlainObject(value, SCAN_FIELDS);
  const records = readDenseArray(scan.records).map(validateRecord);
  const errors = readDenseArray(scan.errors).map(validateError);
  const recordKeys = records.map(recordKey);
  const errorKeys = errors.map(errorKey);
  if (new Set(recordKeys).size !== recordKeys.length) {
    throw new Error('duplicate scan record');
  }
  if (new Set(errorKeys).size !== errorKeys.length) {
    throw new Error('duplicate scan error');
  }
  return {
    records: sortedRecords(records),
    errors: errors.sort((left, right) => compareKeys(left, right, errorKey)),
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
        writeLine(dependencies.stderr, `${ERROR_MESSAGES.get(item.kind)}: ${item.source}`);
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
    writeLine(dependencies.stderr, 'mobile boundary configuration error');
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

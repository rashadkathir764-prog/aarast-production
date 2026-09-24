import fs from 'node:fs';
import { createHash } from 'node:crypto';
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
      const tokenOffset = index;
      const parsed = readDartString(sourceText, index, rawString);
      tokens.push({
        type: 'string',
        value: parsed.value,
        interpolated: parsed.interpolated,
        topLevel,
        offset: tokenOffset,
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
        offset: start,
      });
      continue;
    }

    tokens.push({ type: 'punctuation', value: character, topLevel, offset: index });
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

function r9Combinators(tokens, start) {
  let end = start;
  const show = [];
  const hide = [];
  while (
    tokens[end]?.type === 'identifier'
    && (tokens[end].value === 'show' || tokens[end].value === 'hide')
  ) {
    const target = tokens[end].value === 'show' ? show : hide;
    end += 1;
    if (!isDartIdentifierToken(tokens[end])) invalidDartSource();
    target.push(tokens[end].value);
    end += 1;
    while (tokens[end]?.value === ',') {
      if (!isDartIdentifierToken(tokens[end + 1])) invalidDartSource();
      target.push(tokens[end + 1].value);
      end += 2;
    }
  }
  return {
    end,
    show: [...new Set(show)].sort(),
    hide: [...new Set(hide)].sort(),
  };
}

function directiveLine(sourceText, token) {
  return (sourceText.slice(0, token.offset).match(/\r\n|\r|\n/g) || []).length + 1;
}

export function parseR9DartDirectives(sourceText) {
  const text = String(sourceText);
  const tokens = tokenizeDart(text);
  const directives = [];
  const consumed = new Set();

  for (let index = 0; index < tokens.length; index += 1) {
    const token = tokens[index];
    if (
      !token.topLevel
      || token.type !== 'identifier'
      || !['import', 'export', 'part'].includes(token.value)
    ) continue;

    let end = index + 1;
    while (end < tokens.length && !(tokens[end].topLevel && tokens[end].value === ';')) {
      end += 1;
    }
    if (end >= tokens.length) invalidDartSource();
    for (let cursor = index; cursor <= end; cursor += 1) consumed.add(cursor);
    const body = tokens.slice(index + 1, end);
    const line = directiveLine(text, token);

    if (token.value === 'part') {
      const parsed = parsePart(body);
      if (parsed.uris.length === 0) {
        directives.push({
          directiveKind: 'part-of',
          uri: null,
          show: [],
          hide: [],
          conditional: false,
          line,
        });
      } else {
        directives.push({
          directiveKind: parsed.kind,
          uri: parsed.uris[0],
          show: [],
          hide: [],
          conditional: false,
          line,
        });
      }
      index = end;
      continue;
    }

    const configurable = readConfigurableUri(body);
    let combinatorStart = configurable.end;
    if (token.value === 'import') {
      if (body[combinatorStart]?.value === 'deferred') combinatorStart += 1;
      if (body[combinatorStart]?.value === 'as') combinatorStart += 2;
    }
    const combinators = r9Combinators(body, combinatorStart);
    // The historical parser remains the grammar authority and fails closed.
    parseImportOrExport(token.value, body);
    for (const uri of configurable.uris) {
      directives.push({
        directiveKind: token.value,
        uri,
        show: combinators.show,
        hide: combinators.hide,
        conditional: configurable.uris.length > 1,
        line,
      });
    }
    index = end;
  }

  const declaration = tokens.find((token, index) => (
    token.topLevel && !consumed.has(index) && token.value !== ';'
  ));
  if (declaration) {
    directives.push({
      directiveKind: 'declaration',
      uri: null,
      show: [],
      hide: [],
      conditional: false,
      line: directiveLine(text, declaration),
    });
  }
  return directives.sort((left, right) => (
    left.line - right.line
    || left.directiveKind.localeCompare(right.directiveKind, 'en')
    || String(left.uri).localeCompare(String(right.uri), 'en')
  ));
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

const R9_BASE_REVISION = '833a4f1d31781b45cd0a68ecee1b969ac85f237f';
const R9_BASELINE_SHA256 = 'f9939fa25b7e3e3b7e3563c4dce30aa9a2cb0781cdf2ed8bbf9448477644cf1f';
const R9_ROOT_SHA256 = '1cf2239bdf339b12fa76abfa3dd90ef9bbf2dd39a0778f2af9385f2e4e28848b';
const R9_ALLOWED_PATHS_SHA256 = 'eda3b152a7eb8986482fa1b2d0aeaa32120a26f721be1cf1c36515ba107f967c';
const R9_FEATURES = [
  'account_contexts', 'auth', 'catalogs', 'chat', 'finance', 'guests', 'home',
  'marketplace', 'more', 'notifications', 'onboarding', 'provider_portal',
  'settings', 'sharing',
  'shell', 'support', 'tasks', 'wedding_day', 'wedding_plans', 'welcome_gateway',
];
const R9_COMPOSITION_SOURCES = [
  'mobile/lib/app.dart',
  'mobile/lib/core/routing/app_router.dart',
  'mobile/lib/main.dart',
];
const R9_DEBT = {
  'task-1': { legacy: 269, root: 34 },
  'task-2': { legacy: 265, root: 34 },
  'task-3': { legacy: 265, root: 34 },
  'task-4': { legacy: 255, root: 34 },
  'task-5': { legacy: 198, root: 34 },
  'task-6': { legacy: 119, root: 34 },
  'task-7': { legacy: 59, root: 34 },
  'task-8': { legacy: 0, root: 0 },
  'task-9': { legacy: 0, root: 0 },
  'task-10': { legacy: 0, root: 0 },
  'task-11': { legacy: 0, root: 0 },
};
const R9_DOCUMENTS = [
  {
    path: 'docs/superpowers/specs/2026-08-28-modular-monolith-r9-mobile-strict-boundaries-design.md',
    sha256: '45f732498afda4fd0ba7861eb0aff75c31580cc14d20c810a655f3857174c5f5',
  },
  {
    path: 'docs/superpowers/plans/2026-08-28-modular-monolith-r9-mobile-strict-boundaries.md',
    sha256: '061e26f63393d9c988c3dbec1043e633ed32f9a213fda55b6db4406beccb2a0a',
  },
];
const R9_ROOT_PAIRS = [
  'mobile/lib/app.dart -> mobile/lib/features/account_contexts/providers/account_context_controller.dart',
  'mobile/lib/app.dart -> mobile/lib/features/auth/providers/auth_controller.dart',
  'mobile/lib/main.dart -> mobile/lib/features/account_contexts/data/account_contexts_api.dart',
  'mobile/lib/main.dart -> mobile/lib/features/account_contexts/providers/account_context_controller.dart',
  'mobile/lib/main.dart -> mobile/lib/features/auth/data/auth_repository.dart',
  'mobile/lib/main.dart -> mobile/lib/features/auth/providers/auth_controller.dart',
  'mobile/lib/main.dart -> mobile/lib/features/catalogs/data/reference_catalog_api.dart',
  'mobile/lib/main.dart -> mobile/lib/features/catalogs/providers/reference_catalog_provider.dart',
  'mobile/lib/main.dart -> mobile/lib/features/chat/data/chat_api.dart',
  'mobile/lib/main.dart -> mobile/lib/features/chat/data/chat_realtime_client.dart',
  'mobile/lib/main.dart -> mobile/lib/features/chat/providers/chat_provider.dart',
  'mobile/lib/main.dart -> mobile/lib/features/finance/data/finance_api.dart',
  'mobile/lib/main.dart -> mobile/lib/features/finance/providers/finance_provider.dart',
  'mobile/lib/main.dart -> mobile/lib/features/guests/data/guests_api.dart',
  'mobile/lib/main.dart -> mobile/lib/features/guests/providers/guests_provider.dart',
  'mobile/lib/main.dart -> mobile/lib/features/home/providers/home_dashboard_provider.dart',
  'mobile/lib/main.dart -> mobile/lib/features/marketplace/data/marketplace_api.dart',
  'mobile/lib/main.dart -> mobile/lib/features/marketplace/providers/marketplace_provider.dart',
  'mobile/lib/main.dart -> mobile/lib/features/notifications/data/notifications_api.dart',
  'mobile/lib/main.dart -> mobile/lib/features/notifications/providers/notifications_provider.dart',
  'mobile/lib/main.dart -> mobile/lib/features/onboarding/data/guest_onboarding_storage.dart',
  'mobile/lib/main.dart -> mobile/lib/features/onboarding/data/yemen_administrative_api.dart',
  'mobile/lib/main.dart -> mobile/lib/features/onboarding/providers/yemen_administrative_provider.dart',
  'mobile/lib/main.dart -> mobile/lib/features/settings/data/settings_api.dart',
  'mobile/lib/main.dart -> mobile/lib/features/settings/providers/settings_provider.dart',
  'mobile/lib/main.dart -> mobile/lib/features/sharing/data/sharing_api.dart',
  'mobile/lib/main.dart -> mobile/lib/features/sharing/providers/contribution_history_provider.dart',
  'mobile/lib/main.dart -> mobile/lib/features/sharing/providers/sharing_provider.dart',
  'mobile/lib/main.dart -> mobile/lib/features/sharing/services/plan_leave_coordinator.dart',
  'mobile/lib/main.dart -> mobile/lib/features/tasks/data/task_timeline_api.dart',
  'mobile/lib/main.dart -> mobile/lib/features/tasks/providers/task_timeline_provider.dart',
  'mobile/lib/main.dart -> mobile/lib/features/wedding_plans/data/wedding_plans_api.dart',
  'mobile/lib/main.dart -> mobile/lib/features/wedding_plans/providers/dashboard_summary_provider.dart',
  'mobile/lib/main.dart -> mobile/lib/features/wedding_plans/providers/wedding_plans_provider.dart',
];
const R9_MANIFEST_FIELDS = [
  'allowedChangedPaths', 'baseRevision', 'compositionSources', 'documents',
  'expectedDebt', 'featureApis', 'finalLegalRecordCount', 'historicalBaseline',
  'rootInventory', 'schemaVersion',
];
const R9_RECORD_FIELDS = [
  'conditional', 'count', 'directiveKind', 'hide', 'show', 'source',
  'sourceArea', 'target', 'targetArea',
];

function canonicalRepositoryFile(value) {
  if (
    typeof value !== 'string'
    || value.length === 0
    || value.length > MAX_PATH_LENGTH
    || value.includes('\\')
    || /[\u0000-\u001F\u007F-\u009F:=?*"<>|%]/.test(value)
    || path.posix.isAbsolute(value)
    || path.win32.isAbsolute(value)
    || path.posix.normalize(value) !== value
  ) return false;
  return value.split('/').every((segment) => (
    segment !== ''
    && segment !== '.'
    && segment !== '..'
    && /^[A-Za-z0-9_.@+$'{}-]+$/.test(segment)
  ));
}

function validateStringArray(value, { nonEmpty = false } = {}) {
  const result = readDenseArray(value);
  if (
    (nonEmpty && result.length === 0)
    || result.some((item) => typeof item !== 'string' || item.length === 0)
    || new Set(result).size !== result.length
    || !sameArray(result, [...result].sort())
  ) throw new Error('invalid string array');
  return result;
}

function validateR9Record(value) {
  const item = readPlainObject(value, R9_RECORD_FIELDS);
  if (!canonicalMobileFile(item.source) || !canonicalMobileFile(item.target)) {
    throw new Error('invalid R9 record path');
  }
  if (
    item.sourceArea !== areaForPath(item.source)
    || item.targetArea !== areaForPath(item.target)
    || !['import', 'export', 'part', 'part-of'].includes(item.directiveKind)
    || typeof item.conditional !== 'boolean'
    || !Number.isSafeInteger(item.count)
    || item.count <= 0
  ) throw new Error('invalid R9 record');
  return {
    ...item,
    show: validateStringArray(item.show),
    hide: validateStringArray(item.hide),
  };
}

function r9RecordKey(item) {
  return [
    item.source,
    item.target,
    item.sourceArea,
    item.targetArea,
    item.directiveKind,
    item.show.join(','),
    item.hide.join(','),
    item.conditional ? '1' : '0',
  ].join('|');
}

function validateExactObject(value, expected, fields) {
  const item = readPlainObject(value, fields);
  for (const field of fields) {
    if (item[field] !== expected[field]) throw new Error('invalid manifest identity');
  }
  return item;
}

export function validateR9Manifest(value) {
  const manifest = readPlainObject(value, R9_MANIFEST_FIELDS);
  if (manifest.schemaVersion !== 1 || manifest.baseRevision !== R9_BASE_REVISION) {
    throw new Error('invalid R9 manifest identity');
  }
  const historicalBaseline = validateExactObject(
    manifest.historicalBaseline,
    {
      path: 'scripts/architecture/mobile-boundaries-baseline.json',
      sourceRevision: SOURCE_REVISION,
      sha256: R9_BASELINE_SHA256,
      recordCount: 269,
    },
    ['path', 'recordCount', 'sha256', 'sourceRevision'],
  );
  const rootInventory = readPlainObject(
    manifest.rootInventory,
    ['canonicalSha256', 'recordCount', 'records'],
  );
  if (rootInventory.recordCount !== 34 || rootInventory.canonicalSha256 !== R9_ROOT_SHA256) {
    throw new Error('invalid root inventory identity');
  }
  const rootRecords = readDenseArray(rootInventory.records).map(validateR9Record);
  const rootKeys = rootRecords.map(r9RecordKey);
  if (
    rootRecords.length !== 34
    || new Set(rootKeys).size !== rootKeys.length
    || !sameArray(rootKeys, [...rootKeys].sort())
    || rootRecords.some((item, index) => (
      !['mobile/lib/app.dart', 'mobile/lib/main.dart'].includes(item.source)
      || item.directiveKind !== 'import'
      || item.count !== 1
      || item.show.length !== 0
      || item.hide.length !== 0
      || item.conditional
      || `${item.source} -> ${item.target}` !== R9_ROOT_PAIRS[index]
    ))
  ) throw new Error('invalid root inventory');

  const featureApis = readDenseArray(manifest.featureApis).map((value, index) => {
    const item = readPlainObject(value, ['area', 'path']);
    const feature = R9_FEATURES[index];
    if (
      item.area !== `features/${feature}`
      || item.path !== `mobile/lib/features/${feature}/${feature}_api.dart`
    ) throw new Error('invalid feature API inventory');
    return item;
  });
  if (featureApis.length !== R9_FEATURES.length) throw new Error('invalid feature API count');

  const debt = readPlainObject(manifest.expectedDebt, Object.keys(R9_DEBT).sort());
  const expectedDebt = {};
  for (const [task, expected] of Object.entries(R9_DEBT)) {
    expectedDebt[task] = validateExactObject(debt[task], expected, ['legacy', 'root']);
  }
  const compositionSources = validateStringArray(manifest.compositionSources);
  if (!sameArray(compositionSources, R9_COMPOSITION_SOURCES)) {
    throw new Error('invalid composition sources');
  }
  if (manifest.finalLegalRecordCount !== 172) throw new Error('invalid final legal count');

  const documents = readDenseArray(manifest.documents).map((value, index) => (
    validateExactObject(value, R9_DOCUMENTS[index] || {}, ['path', 'sha256'])
  ));
  if (documents.length !== R9_DOCUMENTS.length) throw new Error('invalid document inventory');

  const allowedChangedPaths = readDenseArray(manifest.allowedChangedPaths);
  if (
    allowedChangedPaths.length !== 157
    || allowedChangedPaths.some((item) => !canonicalRepositoryFile(item))
    || new Set(allowedChangedPaths).size !== allowedChangedPaths.length
    || !sameArray(allowedChangedPaths, [...allowedChangedPaths].sort())
    || createHash('sha256').update(JSON.stringify(allowedChangedPaths)).digest('hex')
      !== R9_ALLOWED_PATHS_SHA256
  ) throw new Error('invalid allowed changed path fence');

  return {
    schemaVersion: 1,
    baseRevision: R9_BASE_REVISION,
    historicalBaseline,
    rootInventory: {
      recordCount: 34,
      canonicalSha256: R9_ROOT_SHA256,
      records: rootRecords,
    },
    featureApis,
    expectedDebt,
    finalLegalRecordCount: 172,
    compositionSources,
    documents,
    allowedChangedPaths,
  };
}

function stableR9Record({ source, target, directive, count = 1 }) {
  return {
    source,
    target,
    sourceArea: areaForPath(source),
    targetArea: areaForPath(target),
    directiveKind: directive.directiveKind,
    show: [...directive.show],
    hide: [...directive.hide],
    conditional: directive.conditional,
    count,
  };
}

function exactOwnerApiPathForArea(area) {
  if (!area.startsWith('features/')) return null;
  const feature = area.slice('features/'.length);
  return `mobile/lib/features/${feature}/${feature}_api.dart`;
}

function r9HistoricalKey(item) {
  const kind = recordKind(item.sourceArea, item.targetArea);
  return [item.source, item.target, item.sourceArea, item.targetArea, kind].join('|');
}

export function scanR9MobileBoundaries({ mobileLib, manifest }) {
  const contract = validateR9Manifest(manifest);
  const resolvedMobileLib = path.resolve(mobileLib);
  const realMobileLib = fs.realpathSync.native(resolvedMobileLib);
  const repoRoot = path.resolve(resolvedMobileLib, '..', '..');
  const historical = scanMobileBoundaries({ mobileLib: resolvedMobileLib });
  const errors = new Map(historical.errors.map((item) => [errorKey(item), item]));
  const legacy = new Map();
  const roots = new Map();
  const legal = new Map();
  const malformed = new Map();
  const exactCompositionSources = new Set(contract.compositionSources);
  const sourceOwnerState = new Map();

  function addError(kind, source, target = source) {
    const item = { kind, source, target };
    errors.set(`${source}|${target}|${kind}`, item);
  }
  function addRecord(collection, item) {
    const key = r9RecordKey(item);
    const current = collection.get(key);
    if (current) current.count += item.count;
    else collection.set(key, { ...item });
  }

  for (const sourceFile of listDartFiles(resolvedMobileLib)) {
    const source = repositoryPath(sourceFile, repoRoot);
    const sourceArea = areaForPath(source);
    const isOwnerApi = source === exactOwnerApiPathForArea(sourceArea);
    const directives = parseR9DartDirectives(fs.readFileSync(sourceFile, 'utf8'));
    const pairState = new Map();

    for (const directive of directives) {
      if (isOwnerApi && directive.directiveKind === 'declaration') {
        addError('owner-api-declaration', source);
        continue;
      }
      if (directive.uri === null) {
        if (isOwnerApi) addError('owner-api-forbidden-directive', source);
        continue;
      }
      const targetFile = resolveDartTarget(sourceFile, directive.uri, resolvedMobileLib);
      if (targetFile === null) {
        if (isOwnerApi) addError('owner-api-forbidden-directive', source);
        continue;
      }
      const target = repositoryPath(targetFile, repoRoot);
      const realTargetFile = resolveCanonicalMobileFile(targetFile, resolvedMobileLib, realMobileLib);
      if (realTargetFile === null) continue;
      const record = stableR9Record({ source, target, directive });
      const targetArea = record.targetArea;
      const targetIsOwnerApi = target === exactOwnerApiPathForArea(targetArea);

      if (isOwnerApi) {
        if (directive.directiveKind !== 'export') {
          addError('owner-api-forbidden-directive', source, target);
        } else {
          if (directive.show.length === 0) addError('owner-export-empty-show', source, target);
          if (directive.hide.length > 0) addError('owner-export-hide', source, target);
          if (directive.conditional) addError('owner-export-conditional', source, target);
          if (targetArea !== sourceArea) addError('owner-export-cross-owner', source, target);
          if (targetIsOwnerApi) addError('owner-export-api-target', source, target);
        }
      }

      if (!targetArea.startsWith('features/') || sourceArea === targetArea) continue;
      const state = pairState.get(targetArea) || { api: 0, internal: 0 };
      if (targetIsOwnerApi && directive.directiveKind === 'import') state.api += 1;
      else state.internal += 1;
      pairState.set(targetArea, state);

      if (directive.directiveKind === 'export') {
        addError('cross-area-export', source, target);
      }
      if (targetIsOwnerApi && directive.directiveKind === 'import') {
        const importerAllowed = (
          sourceArea.startsWith('features/') || exactCompositionSources.has(source)
        );
        let structurallyLegal = importerAllowed;
        if (!importerAllowed) addError('invalid-feature-importer', source, target);
        if (directive.show.length === 0) {
          addError('owner-import-empty-show', source, target);
          structurallyLegal = false;
        }
        if (directive.hide.length > 0) {
          addError('owner-import-hide', source, target);
          structurallyLegal = false;
        }
        if (directive.conditional) {
          addError('owner-import-conditional', source, target);
          structurallyLegal = false;
        }
        if (structurallyLegal) addRecord(legal, record);
        else addRecord(malformed, record);
      } else if (sourceArea.startsWith('features/') || sourceArea === 'core') {
        addRecord(legacy, record);
      } else {
        addRecord(roots, record);
        if (!['mobile/lib/app.dart', 'mobile/lib/main.dart'].includes(source)) {
          addError('invalid-feature-importer', source, target);
        }
      }
    }

    sourceOwnerState.set(source, pairState);
  }

  for (const [source, pairState] of sourceOwnerState) {
    for (const [targetArea, state] of pairState) {
      const safeTarget = `mobile/lib/${targetArea}/${targetArea.slice('features/'.length)}_api.dart`;
      if (state.api > 0 && state.internal > 0) addError('mixed-owner-imports', source, safeTarget);
      if (state.api > 1) addError('duplicate-owner-api-import', source, safeTarget);
    }
  }

  const sorted = (collection) => [...collection.values()].sort((left, right) => (
    r9RecordKey(left).localeCompare(r9RecordKey(right), 'en')
  ));
  const legacyRecords = sorted(legacy);
  const rootRecords = sorted(roots);
  const legalRecords = sorted(legal);
  const strictMap = new Map();
  for (const item of [...legacyRecords, ...rootRecords, ...sorted(malformed)]) {
    strictMap.set(r9RecordKey(item), item);
  }
  return {
    errors: [...errors.values()].sort((left, right) => (
      `${left.source}|${left.target}|${left.kind}`.localeCompare(
        `${right.source}|${right.target}|${right.kind}`,
        'en',
      )
    )),
    legacyRecords,
    rootRecords,
    legalRecords,
    strictViolations: sorted(strictMap),
  };
}

export function compareR9MobileDebt({ scan, baseline, manifest }) {
  const contract = validateR9Manifest(manifest);
  const saved = validateBaseline(baseline);
  const allowedLegacy = new Map(saved.records.map((item) => [recordKey(item), item.count]));
  const currentLegacy = new Map();
  for (const item of scan.legacyRecords) {
    const key = r9HistoricalKey(item);
    currentLegacy.set(key, (currentLegacy.get(key) || 0) + item.count);
  }
  const additions = [];
  for (const item of scan.legacyRecords) {
    const key = r9HistoricalKey(item);
    if ((currentLegacy.get(key) || 0) > (allowedLegacy.get(key) || 0)) addRecordOnce(additions, item);
  }
  const allowedRoots = new Map(contract.rootInventory.records.map((item) => [
    r9RecordKey(item),
    item.count,
  ]));
  for (const item of scan.rootRecords) {
    const key = r9RecordKey(item);
    if (item.count > (allowedRoots.get(key) || 0)) addRecordOnce(additions, item);
  }
  additions.sort((left, right) => r9RecordKey(left).localeCompare(r9RecordKey(right), 'en'));
  return {
    ok: additions.length === 0 && scan.errors.length === 0,
    additions,
    legacyViolationCount: scan.legacyRecords.length,
    rootViolationCount: scan.rootRecords.length,
  };
}

function addRecordOnce(records, item) {
  if (!records.some((candidate) => r9RecordKey(candidate) === r9RecordKey(item))) {
    records.push(item);
  }
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

    if (
      typeof dependencies.scanR9 === 'function'
      && typeof dependencies.readManifest === 'function'
      && typeof dependencies.readBaselineText === 'function'
    ) {
      const manifest = validateR9Manifest(dependencies.readManifest());
      const baselineText = dependencies.readBaselineText();
      if (
        typeof baselineText !== 'string'
        || createHash('sha256').update(baselineText).digest('hex')
          !== manifest.historicalBaseline.sha256
      ) throw new Error('invalid historical baseline hash');
      const saved = validateBaseline(JSON.parse(baselineText));
      const r9 = dependencies.scanR9(manifest);
      if (
        !r9
        || !Array.isArray(r9.errors)
        || !Array.isArray(r9.legacyRecords)
        || !Array.isArray(r9.rootRecords)
        || !Array.isArray(r9.legalRecords)
        || !Array.isArray(r9.strictViolations)
      ) throw new Error('invalid R9 scan');
      if (r9.errors.length > 0) {
        writeLine(
          dependencies.stderr,
          `R9 mobile boundary structural errors (${r9.errors.length} records)`,
        );
        for (const item of r9.errors) {
          const source = canonicalMobileFile(item?.source)
            ? item.source
            : 'mobile/lib/__invalid_r9_source__.dart';
          writeLine(dependencies.stderr, `R9-structural-violation: ${source}`);
        }
        return 1;
      }
      if (argv[0] === '--strict') {
        if (r9.strictViolations.length > 0) {
          writeLine(
            dependencies.stderr,
            `strict R9 mobile boundary violations (${r9.strictViolations.length} records)`,
          );
          for (const item of r9.strictViolations) {
            const source = canonicalMobileFile(item?.source)
              ? item.source
              : 'mobile/lib/__invalid_r9_source__.dart';
            writeLine(dependencies.stderr, `strict-r9-boundary: ${source}`);
          }
          return 1;
        }
        writeLine(
          dependencies.stdout,
          `strict R9 mobile boundary check passed (legal=${r9.legalRecords.length})`,
        );
        return 0;
      }
      const comparison = compareR9MobileDebt({ scan: r9, baseline: saved, manifest });
      if (!comparison.ok) {
        writeLine(
          dependencies.stderr,
          `R9 mobile boundary debt additions (${comparison.additions.length} records)`,
        );
        for (const item of comparison.additions) {
          const source = canonicalMobileFile(item?.source)
            ? item.source
            : 'mobile/lib/__invalid_r9_source__.dart';
          writeLine(dependencies.stderr, `R9-debt-addition: ${source}`);
        }
        return 1;
      }
      writeLine(
        dependencies.stdout,
        'R9 mobile boundary baseline check passed '
          + `(legacy=${comparison.legacyViolationCount}, `
          + `root=${comparison.rootViolationCount}, legal=${r9.legalRecords.length})`,
      );
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
  const manifestPath = path.join(
    repoRoot,
    'scripts',
    'architecture',
    'r9-mobile-strict-manifest.json',
  );
  return {
    argv,
    scan: () => scanMobileBoundaries({ mobileLib }),
    readBaseline: () => JSON.parse(fs.readFileSync(baselinePath, 'utf8')),
    readBaselineText: () => fs.readFileSync(baselinePath, 'utf8'),
    readManifest: () => JSON.parse(fs.readFileSync(manifestPath, 'utf8')),
    scanR9: (manifest) => scanR9MobileBoundaries({ mobileLib, manifest }),
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

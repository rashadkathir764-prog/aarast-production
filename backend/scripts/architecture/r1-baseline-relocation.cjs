'use strict';

const crypto = require('node:crypto');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { spawnSync } = require('node:child_process');
const utilTypes = require('node:util').types;

const SCHEMA_VERSION = 1;
const R1_BASE_REVISION = '94b677b7b8e2219e0db2cbc553fa3d26b4876456';
const SOURCE_REVISION = 'feafe3db0053d6c66d5f46b56ff9a512861dfbad';
const BASE_DEPENDENCY_PATH = 'backend/.dependency-cruiser-known-violations.json';
const BASE_OWNERSHIP_PATH = 'backend/architecture/ownership-baseline.json';
const EXPECTED_MAP_PATH = 'architecture/r1-relocation-map.json';
const MAX_RECORDS = 10_000;
const MAX_COUNT = 1_000_000;
const MAX_PATH_LENGTH = 4_096;
const MAX_IDENTIFIER_LENGTH = 256;
const DEPENDENCY_KEYS = [
  'type',
  'from',
  'to',
  'unresolvedTo',
  'dependencyTypes',
  'rule',
];
const OWNERSHIP_KEYS = [
  'key',
  'file',
  'context',
  'owner',
  'model',
  'operation',
  'mode',
  'source',
  'reason',
  'count',
];
const SECRET_VALUE = /(?:password|secret|token|credential)\s*=|BEGIN (?:RSA |OPENSSH )?PRIVATE KEY|postgres(?:ql)?:\/\/|https?:\/\//i;
const RESOLVABLE_EXTENSIONS = ['.ts', '.tsx', '.mts', '.cts', '.js', '.jsx', '.mjs', '.cjs'];
const APPROVED_R1_MAP = {
  schemaVersion: 1,
  dependencyRuleRenames: [
    { from: 'current-platform-no-business-contexts', to: 'platform-no-business-contexts' },
  ],
  dependencyPrefixes: [
    { from: 'src/common/config/', to: 'src/platform/config/' },
    { from: 'src/common/filters/', to: 'src/platform/http/' },
    { from: 'src/common/http/', to: 'src/platform/http/' },
    { from: 'src/common/pagination/', to: 'src/platform/http/' },
    { from: 'src/common/redis/', to: 'src/platform/redis/' },
    { from: 'src/common/observability/', to: 'src/platform/observability/' },
    { from: 'src/common/prisma/', to: 'src/platform/database/' },
    { from: 'src/common/idempotency/', to: 'src/platform/idempotency/' },
    { from: 'src/common/validation/money.ts', to: 'src/shared-kernel/money/money.ts' },
    { from: 'src/common/phone/', to: 'src/shared-kernel/phone/' },
    { from: 'src/common/privacy/', to: 'src/shared-kernel/privacy/' },
    { from: 'src/common/time/', to: 'src/shared-kernel/time/' },
    { from: 'src/common/admin/admin-permissions.ts', to: 'src/modules/backoffice/domain/admin-permissions.ts' },
    { from: 'src/prisma/', to: 'src/platform/database/' },
    { from: 'src/outbox/', to: 'src/platform/outbox/' },
    { from: 'src/health.controller.ts', to: 'src/platform/health/health.controller.ts' },
    { from: 'src/health/', to: 'src/platform/health/' },
    { from: 'src/auth/openwa-otp-config.ts', to: 'src/platform/otp-transport/openwa-otp-config.ts' },
    { from: 'src/auth/openwa-transient-text.ts', to: 'src/platform/otp-transport/openwa-transient-text.ts' },
    { from: 'src/auth/whatsapp-otp-config.ts', to: 'src/platform/otp-transport/whatsapp-otp-config.ts' },
    { from: 'src/users/application-user-identity.ts', to: 'src/shared-kernel/privacy/application-user-identity.ts' },
    { from: 'src/admin/admin-privacy.ts', to: 'src/shared-kernel/privacy/admin-notification-privacy.ts' },
  ],
  ownershipFilePrefixes: [
    { from: 'backend/src/common/config/', to: 'backend/src/platform/config/' },
    { from: 'backend/src/common/filters/', to: 'backend/src/platform/http/' },
    { from: 'backend/src/common/http/', to: 'backend/src/platform/http/' },
    { from: 'backend/src/common/pagination/', to: 'backend/src/platform/http/' },
    { from: 'backend/src/common/redis/', to: 'backend/src/platform/redis/' },
    { from: 'backend/src/common/observability/', to: 'backend/src/platform/observability/' },
    { from: 'backend/src/common/prisma/', to: 'backend/src/platform/database/' },
    { from: 'backend/src/common/idempotency/', to: 'backend/src/platform/idempotency/' },
    { from: 'backend/src/prisma/', to: 'backend/src/platform/database/' },
    { from: 'backend/src/outbox/', to: 'backend/src/platform/outbox/' },
    { from: 'backend/src/health.controller.ts', to: 'backend/src/platform/health/health.controller.ts' },
    { from: 'backend/src/health/', to: 'backend/src/platform/health/' },
  ],
};

function isPlainDataObject(value) {
  return value !== null
    && typeof value === 'object'
    && !Array.isArray(value)
    && !utilTypes.isProxy(value)
    && Object.getPrototypeOf(value) === Object.prototype;
}

function ownDataProperties(value, label) {
  if (!isPlainDataObject(value)) throw new Error(`${label} must be a plain object`);
  const descriptors = Object.getOwnPropertyDescriptors(value);
  for (const descriptor of Object.values(descriptors)) {
    if (!Object.hasOwn(descriptor, 'value')) throw new Error(`${label} must contain data only`);
  }
  return Object.fromEntries(Object.entries(descriptors).map(([key, descriptor]) => [key, descriptor.value]));
}

function exactObject(value, keys, label) {
  const data = ownDataProperties(value, label);
  const actual = Object.keys(data).sort();
  const expected = [...keys].sort();
  if (actual.length !== expected.length || actual.some((key, index) => key !== expected[index])) {
    throw new Error(`${label} shape is invalid`);
  }
  return data;
}

function denseArray(value, label) {
  if (!Array.isArray(value) || utilTypes.isProxy(value) || value.length > MAX_RECORDS) {
    throw new Error(`${label} must be a bounded array`);
  }
  for (let index = 0; index < value.length; index += 1) {
    if (!Object.hasOwn(value, index)) throw new Error(`${label} must be dense`);
  }
  return [...value];
}

function canonicalIdentifier(value) {
  return typeof value === 'string'
    && value.length > 0
    && value.length <= MAX_IDENTIFIER_LENGTH
    && /^[A-Za-z0-9_$<>+-]+(?:-[A-Za-z0-9_$<>+-]+)*$/.test(value);
}

function canonicalRepositoryPath(value, prefix) {
  return typeof value === 'string'
    && value.length > prefix.length
    && value.length <= MAX_PATH_LENGTH
    && value.startsWith(prefix)
    && !/[\u0000-\u001f\u007f\\]/.test(value)
    && !SECRET_VALUE.test(value)
    && !path.posix.isAbsolute(value)
    && !path.win32.isAbsolute(value)
    && !value.split('/').some((segment) => segment === '' || segment === '.' || segment === '..')
    && path.posix.normalize(value) === value;
}

function canonicalRelocationPath(value, prefix) {
  if (typeof value !== 'string') return false;
  return value.endsWith('/')
    ? canonicalRepositoryPath(`${value}relocation-target.ts`, prefix)
    : canonicalRepositoryPath(value, prefix);
}

function canonicalUnresolved(value) {
  if (typeof value !== 'string' || value.length === 0 || value.length > MAX_PATH_LENGTH) return false;
  if (/[\u0000-\u001f\u007f\\]/.test(value) || SECRET_VALUE.test(value)) return false;
  if (path.posix.isAbsolute(value) || path.win32.isAbsolute(value)) return false;
  if (!value.startsWith('./') && !value.startsWith('../')) return false;
  const segments = value.split('/');
  return !segments.some((segment, index) => (
    segment === '' || (segment === '.' && index !== 0)
  ));
}

function dependencyTargetCandidates(record) {
  const resolved = path.posix.normalize(path.posix.join(
    path.posix.dirname(record.from),
    record.unresolvedTo,
  ));
  if (!canonicalRepositoryPath(resolved, 'src/')) return [];
  if (RESOLVABLE_EXTENSIONS.some((extension) => resolved.endsWith(extension))) {
    const candidates = [resolved];
    const substitutions = {
      '.js': ['.ts', '.tsx', '.js', '.jsx'],
      '.jsx': ['.tsx', '.jsx'],
      '.mjs': ['.mts', '.mjs'],
      '.cjs': ['.cts', '.cjs'],
    };
    for (const [emitted, sources] of Object.entries(substitutions)) {
      if (!resolved.endsWith(emitted)) continue;
      const stem = resolved.slice(0, -emitted.length);
      candidates.push(...sources.map((extension) => `${stem}${extension}`));
    }
    return [...new Set(candidates)];
  }
  return [
    ...RESOLVABLE_EXTENSIONS.map((extension) => `${resolved}${extension}`),
    ...RESOLVABLE_EXTENSIONS.map((extension) => `${resolved}/index${extension}`),
  ];
}

function dependencyMetadataEqual(left, right) {
  return left.dependencyTypes.length === right.dependencyTypes.length
    && left.dependencyTypes.every((entry, index) => entry === right.dependencyTypes[index]);
}

function dependencyKey(record) {
  return `${record.rule.name}|${record.from}|${record.to}`;
}

function validateDependency(value) {
  const record = exactObject(value, DEPENDENCY_KEYS, 'dependency record');
  if (record.type !== 'dependency') throw new Error('dependency type is invalid');
  if (!canonicalRepositoryPath(record.from, 'src/') || !canonicalRepositoryPath(record.to, 'src/')) {
    throw new Error('dependency path is invalid');
  }
  if (!canonicalUnresolved(record.unresolvedTo)) throw new Error('dependency unresolved path is invalid');
  const dependencyTypes = denseArray(record.dependencyTypes, 'dependency types');
  if (
    dependencyTypes.length < 1
    || dependencyTypes.length > 3
    || new Set(dependencyTypes).size !== dependencyTypes.length
    || dependencyTypes.some((entry) => !['local', 'import', 'type-only'].includes(entry))
  ) {
    throw new Error('dependency types are invalid');
  }
  const rule = exactObject(record.rule, ['severity', 'name'], 'dependency rule');
  if (rule.severity !== 'error' || !canonicalIdentifier(rule.name)) {
    throw new Error('dependency rule is invalid');
  }
  const normalized = {
    type: 'dependency',
    from: record.from,
    to: record.to,
    unresolvedTo: record.unresolvedTo,
    dependencyTypes,
    rule: { severity: 'error', name: rule.name },
  };
  if (!dependencyTargetCandidates(normalized).includes(normalized.to)) {
    throw new Error('dependency unresolved path is inconsistent');
  }
  return normalized;
}

function validateDependencies(value) {
  const records = denseArray(value, 'dependency baseline').map(validateDependency);
  const keys = records.map(dependencyKey);
  if (
    new Set(keys).size !== keys.length
    || keys.some((key, index) => index > 0 && keys[index - 1] > key)
  ) {
    throw new Error('dependency records must be sorted and keys unique');
  }
  return records;
}

function ownershipKey(record) {
  return [
    record.file,
    record.context,
    record.owner ?? '',
    record.model,
    record.operation,
    record.mode,
    record.source,
    record.reason,
  ].join('|');
}

function validateOwnershipRecord(value) {
  const record = exactObject(value, OWNERSHIP_KEYS, 'ownership record');
  if (!canonicalRepositoryPath(record.file, 'backend/src/')) {
    throw new Error('ownership file is invalid');
  }
  for (const field of ['context', 'model', 'operation', 'mode', 'source', 'reason']) {
    if (!canonicalIdentifier(record[field])) throw new Error(`ownership ${field} is invalid`);
  }
  if (record.owner !== null && !canonicalIdentifier(record.owner)) {
    throw new Error('ownership owner is invalid');
  }
  if (!Number.isSafeInteger(record.count) || record.count <= 0 || record.count > MAX_COUNT) {
    throw new Error('ownership count is invalid');
  }
  const normalized = {
    key: '',
    file: record.file,
    context: record.context,
    owner: record.owner,
    model: record.model,
    operation: record.operation,
    mode: record.mode,
    source: record.source,
    reason: record.reason,
    count: record.count,
  };
  normalized.key = ownershipKey(normalized);
  if (record.key !== normalized.key) throw new Error('ownership key is invalid');
  return normalized;
}

function validateOwnershipBaseline(value) {
  const baseline = exactObject(
    value,
    ['schemaVersion', 'sourceRevision', 'violations'],
    'ownership baseline',
  );
  if (baseline.schemaVersion !== SCHEMA_VERSION || baseline.sourceRevision !== SOURCE_REVISION) {
    throw new Error('ownership baseline header is invalid');
  }
  const violations = denseArray(baseline.violations, 'ownership violations')
    .map(validateOwnershipRecord);
  const keys = violations.map((record) => record.key);
  if (new Set(keys).size !== keys.length || keys.some((key, index) => index > 0 && keys[index - 1] > key)) {
    throw new Error('ownership keys must be sorted and unique');
  }
  return { schemaVersion: SCHEMA_VERSION, sourceRevision: SOURCE_REVISION, violations };
}

function validatePrefixPair(value, label, prefix) {
  const pair = exactObject(value, ['from', 'to'], label);
  if (!canonicalRelocationPath(pair.from, prefix) || !canonicalRelocationPath(pair.to, prefix)) {
    throw new Error(`${label} path is invalid`);
  }
  if (pair.from === pair.to) throw new Error(`${label} must change the path`);
  return { from: pair.from, to: pair.to };
}

function validateMap(value) {
  const map = exactObject(
    value,
    ['schemaVersion', 'dependencyRuleRenames', 'dependencyPrefixes', 'ownershipFilePrefixes'],
    'relocation map',
  );
  if (map.schemaVersion !== SCHEMA_VERSION) throw new Error('relocation map schemaVersion is invalid');
  const dependencyRuleRenames = denseArray(map.dependencyRuleRenames, 'dependency rule renames')
    .map((entry) => {
      const pair = exactObject(entry, ['from', 'to'], 'dependency rule rename');
      if (!canonicalIdentifier(pair.from) || !canonicalIdentifier(pair.to) || pair.from === pair.to) {
        throw new Error('dependency rule rename is invalid');
      }
      return { from: pair.from, to: pair.to };
    });
  const dependencyPrefixes = denseArray(map.dependencyPrefixes, 'dependency prefixes')
    .map((entry) => validatePrefixPair(entry, 'dependency prefix', 'src/'));
  const ownershipFilePrefixes = denseArray(map.ownershipFilePrefixes, 'ownership prefixes')
    .map((entry) => validatePrefixPair(entry, 'ownership prefix', 'backend/src/'));
  for (const [label, records] of [
    ['dependency rule renames', dependencyRuleRenames],
    ['dependency prefixes', dependencyPrefixes],
    ['ownership prefixes', ownershipFilePrefixes],
  ]) {
    const from = records.map((record) => record.from);
    if (new Set(from).size !== from.length) {
      throw new Error(`${label} must have unique sources`);
    }
    const sorted = [...from].sort();
    for (let index = 0; index < sorted.length; index += 1) {
      for (let other = index + 1; other < sorted.length; other += 1) {
        if (sorted[other].startsWith(sorted[index])) {
          throw new Error(`${label} sources overlap`);
        }
      }
    }
  }
  const validated = {
    schemaVersion: SCHEMA_VERSION,
    dependencyRuleRenames,
    dependencyPrefixes,
    ownershipFilePrefixes,
  };
  if (JSON.stringify(validated) !== JSON.stringify(APPROVED_R1_MAP)) {
    throw new Error('relocation map is not the approved R1 contract');
  }
  return validated;
}

function applyPrefix(value, prefixes) {
  const matches = prefixes.filter((entry) => value.startsWith(entry.from));
  if (matches.length > 1) throw new Error('relocation prefixes overlap');
  if (matches.length === 0) return value;
  return `${matches[0].to}${value.slice(matches[0].from.length)}`;
}

function applyRule(value, renames) {
  const matches = renames.filter((entry) => entry.from === value);
  if (matches.length > 1) throw new Error('rule renames overlap');
  return matches.length === 1 ? matches[0].to : value;
}

function mappedDependencyVariants(record, map) {
  const mappedFrom = applyPrefix(record.from, map.dependencyPrefixes);
  const mappedTo = applyPrefix(record.to, map.dependencyPrefixes);
  const fromValues = mappedFrom === record.from ? [record.from] : [mappedFrom, record.from];
  const toValues = mappedTo === record.to ? [record.to] : [mappedTo, record.to];
  const variants = [];
  for (const from of fromValues) {
    for (const to of toValues) {
      const relocated = from !== record.from || to !== record.to;
      if (!relocated) continue;
      variants.push({
        ...record,
        from,
        to,
        rule: {
          ...record.rule,
          name: applyRule(record.rule.name, map.dependencyRuleRenames),
        },
      });
    }
  }
  return variants;
}

function compareDependencies(base, candidate, map) {
  const candidateByKey = new Map(candidate.map((record) => [dependencyKey(record), record]));
  const originsByCandidate = new Map();
  for (const record of base) {
    const variants = [record, ...mappedDependencyVariants(record, map)];
    for (const variant of variants) {
      const key = dependencyKey(variant);
      if (!candidateByKey.has(key)) continue;
      if (!originsByCandidate.has(key)) originsByCandidate.set(key, new Set());
      originsByCandidate.get(key).add(dependencyKey(record));
    }
  }
  if ([...originsByCandidate.values()].some((origins) => origins.size > 1)) {
    throw new Error('dependency relocation collision');
  }
  let mapped = 0;
  let removed = 0;
  for (const record of base) {
    const unchangedKey = dependencyKey(record);
    const unchanged = candidateByKey.get(unchangedKey);
    if (unchanged) {
      if (!dependencyMetadataEqual(record, unchanged)) {
        throw new Error('dependency metadata changed');
      }
      candidateByKey.delete(unchangedKey);
      continue;
    }
    const matchedKey = mappedDependencyVariants(record, map)
      .map((mappedRecord) => dependencyKey(mappedRecord))
      .find((key) => candidateByKey.has(key));
    if (!matchedKey) {
      removed += 1;
      continue;
    }
    if (!dependencyMetadataEqual(record, candidateByKey.get(matchedKey))) {
      throw new Error('dependency metadata changed');
    }
    mapped += 1;
    candidateByKey.delete(matchedKey);
  }
  if (candidateByKey.size > 0) throw new Error('dependency additions are forbidden');
  return { mapped, removed, decreased: 0 };
}

function mappedOwnership(record, map) {
  const file = applyPrefix(record.file, map.ownershipFilePrefixes);
  const relocated = { ...record, file, key: '' };
  relocated.key = ownershipKey(relocated);
  return relocated;
}

function compareOwnership(base, candidate, map) {
  const candidateByKey = new Map(candidate.map((record) => [record.key, record]));
  const originsByCandidate = new Map();
  for (const record of base) {
    for (const key of new Set([record.key, mappedOwnership(record, map).key])) {
      if (!candidateByKey.has(key)) continue;
      if (!originsByCandidate.has(key)) originsByCandidate.set(key, new Set());
      originsByCandidate.get(key).add(record.key);
    }
  }
  if ([...originsByCandidate.values()].some((origins) => origins.size > 1)) {
    throw new Error('ownership relocation collision');
  }
  let mapped = 0;
  let removed = 0;
  let decreased = 0;
  for (const record of base) {
    const unchanged = candidateByKey.get(record.key);
    if (unchanged) {
      if (unchanged.count > record.count) throw new Error('ownership count increased');
      if (unchanged.count < record.count) decreased += 1;
      candidateByKey.delete(record.key);
      continue;
    }
    const mappedRecord = mappedOwnership(record, map);
    const current = candidateByKey.get(mappedRecord.key);
    if (!current) {
      removed += 1;
      continue;
    }
    if (current.count > record.count) throw new Error('ownership count increased');
    if (mappedRecord.key !== record.key) mapped += 1;
    if (current.count < record.count) decreased += 1;
    candidateByKey.delete(mappedRecord.key);
  }
  if (candidateByKey.size > 0) throw new Error('ownership additions are forbidden');
  return { mapped, removed, decreased };
}

function canonicalSha256(value) {
  return crypto.createHash('sha256').update(`${JSON.stringify(value, null, 2)}\n`).digest('hex');
}

function verifyRelocation(input) {
  const options = ownDataProperties(input, 'verification input');
  if (options.baseRevision !== R1_BASE_REVISION) {
    throw new Error('base revision is invalid');
  }
  const baseDependencies = validateDependencies(options.baseDependencies);
  const candidateDependencies = validateDependencies(options.candidateDependencies);
  const baseOwnership = validateOwnershipBaseline(options.baseOwnership);
  const candidateOwnership = validateOwnershipBaseline(options.candidateOwnership);
  const map = validateMap(options.map);
  const candidateHashes = exactObject(options.candidateHashes, ['dependency', 'ownership'], 'candidate hashes');
  if (!/^[a-f0-9]{64}$/.test(candidateHashes.dependency) || !/^[a-f0-9]{64}$/.test(candidateHashes.ownership)) {
    throw new Error('candidate hash is invalid');
  }
  return {
    baseRevision: options.baseRevision,
    candidateHashes: {
      dependency: candidateHashes.dependency,
      ownership: candidateHashes.ownership,
    },
    totals: {
      dependency: compareDependencies(baseDependencies, candidateDependencies, map),
      ownership: compareOwnership(baseOwnership.violations, candidateOwnership.violations, map),
    },
  };
}

function parseArgs(argv) {
  if (!Array.isArray(argv) || argv.length !== 11 || argv[0] !== '--verify') {
    throw new Error('arguments are invalid');
  }
  const values = {};
  for (let index = 1; index < argv.length; index += 2) {
    const flag = argv[index];
    const value = argv[index + 1];
    if (!['--base-ref', '--dependency-candidate', '--ownership-candidate', '--map', '--report'].includes(flag)) {
      throw new Error('argument is unknown');
    }
    if (Object.hasOwn(values, flag) || typeof value !== 'string' || value.length === 0) {
      throw new Error('argument is duplicated or empty');
    }
    values[flag] = value;
  }
  if (Object.keys(values).length !== 5) throw new Error('arguments are incomplete');
  if (values['--base-ref'] !== R1_BASE_REVISION) throw new Error('base revision is invalid');
  for (const flag of ['--dependency-candidate', '--ownership-candidate', '--report']) {
    const value = values[flag];
    if (!path.isAbsolute(value) || /[\u0000-\u001f\u007f]/.test(value) || value.length > MAX_PATH_LENGTH) {
      throw new Error('candidate/report path is invalid');
    }
    const relativeToTemp = path.relative(path.resolve(os.tmpdir()), path.resolve(value));
    if (
      relativeToTemp === ''
      || relativeToTemp === '..'
      || relativeToTemp.startsWith(`..${path.sep}`)
      || path.isAbsolute(relativeToTemp)
    ) {
      throw new Error('candidate/report path must be inside OS temp');
    }
  }
  if (values['--map'].replace(/\\/g, '/') !== EXPECTED_MAP_PATH) {
    throw new Error('map path is invalid');
  }
  return {
    baseRef: values['--base-ref'],
    dependencyCandidate: values['--dependency-candidate'],
    ownershipCandidate: values['--ownership-candidate'],
    map: values['--map'],
    report: values['--report'],
  };
}

function parseJsonText(text, label) {
  if (typeof text !== 'string' || Buffer.byteLength(text, 'utf8') > 32 * 1024 * 1024) {
    throw new Error(`${label} is too large`);
  }
  try {
    return JSON.parse(text);
  } catch {
    throw new Error(`${label} is invalid JSON`);
  }
}

function writeLine(target, message) {
  if (typeof target === 'function') target(message);
  else if (target && typeof target.write === 'function') target.write(`${message}\n`);
}

function pathIdentity(stat) {
  return `${stat.dev}:${stat.ino}`;
}

function insidePath(root, target) {
  const relative = path.relative(root, target);
  return relative !== ''
    && relative !== '..'
    && !relative.startsWith(`..${path.sep}`)
    && !path.isAbsolute(relative);
}

function safeTempPath(target, mustExist) {
  if (typeof target !== 'string' || !path.isAbsolute(target)) {
    throw new Error('temporary path is invalid');
  }
  const lexicalRoot = path.resolve(os.tmpdir());
  const realRoot = fs.realpathSync.native(lexicalRoot);
  const resolved = path.resolve(target);
  if (!insidePath(lexicalRoot, resolved)) throw new Error('temporary path escapes root');
  const relative = path.relative(lexicalRoot, resolved);
  let current = lexicalRoot;
  const segments = relative.split(path.sep);
  for (let index = 0; index < segments.length; index += 1) {
    current = path.join(current, segments[index]);
    if (!fs.existsSync(current)) {
      if (mustExist || index !== segments.length - 1) {
        throw new Error('temporary path does not exist');
      }
      continue;
    }
    const stat = fs.lstatSync(current);
    if (stat.isSymbolicLink()) throw new Error('temporary path contains a link');
  }
  const parentReal = fs.realpathSync.native(path.dirname(resolved));
  if (parentReal !== realRoot && !insidePath(realRoot, parentReal)) {
    throw new Error('temporary path parent escapes root');
  }
  if (!fs.existsSync(resolved)) return { path: resolved, realPath: null, identity: null };
  const real = fs.realpathSync.native(resolved);
  if (!insidePath(realRoot, real)) throw new Error('temporary path resolves outside root');
  const stat = fs.statSync(resolved, { bigint: true });
  if (!stat.isFile()) throw new Error('temporary path is not a file');
  return { path: resolved, realPath: real, identity: pathIdentity(stat) };
}

function readCandidateSnapshot(target) {
  const before = safeTempPath(target, true);
  const handle = fs.openSync(before.path, 'r');
  let bytes;
  let openedBefore;
  let openedAfter;
  try {
    openedBefore = fs.fstatSync(handle, { bigint: true });
    if (
      !openedBefore.isFile()
      || pathIdentity(openedBefore) !== before.identity
      || openedBefore.size > BigInt(32 * 1024 * 1024)
    ) {
      throw new Error('candidate handle is invalid');
    }
    bytes = fs.readFileSync(handle);
    openedAfter = fs.fstatSync(handle, { bigint: true });
  } finally {
    fs.closeSync(handle);
  }
  const after = safeTempPath(target, true);
  if (
    before.identity !== after.identity
    || before.realPath !== after.realPath
    || pathIdentity(openedAfter) !== before.identity
    || openedBefore.size !== openedAfter.size
    || BigInt(bytes.length) !== openedAfter.size
  ) {
    throw new Error('candidate identity changed');
  }
  return {
    ...after,
    bytes,
    text: bytes.toString('utf8'),
    hash: crypto.createHash('sha256').update(bytes).digest('hex'),
  };
}

function revalidateCandidateSnapshot(snapshot) {
  const current = readCandidateSnapshot(snapshot.path);
  if (
    current.identity !== snapshot.identity
    || current.realPath !== snapshot.realPath
    || current.hash !== snapshot.hash
    || !current.bytes.equals(snapshot.bytes)
  ) {
    throw new Error('candidate changed after verification');
  }
  return current;
}

function assertDistinctPaths(paths) {
  const canonical = paths.map((item) => (
    process.platform === 'win32' ? item.path.toLowerCase() : item.path
  ));
  if (new Set(canonical).size !== canonical.length) throw new Error('candidate/report paths alias');
  const identities = paths.map((item) => item.identity).filter(Boolean);
  if (new Set(identities).size !== identities.length) throw new Error('candidate/report identities alias');
}

function atomicWrite(target, value, candidateSnapshots = []) {
  const authorized = safeTempPath(target, false);
  const checkedCandidates = candidateSnapshots.map(revalidateCandidateSnapshot);
  assertDistinctPaths([...checkedCandidates, authorized]);
  const temporary = `${target}.${process.pid}.${Date.now()}.tmp`;
  try {
    fs.writeFileSync(temporary, `${JSON.stringify(value, null, 2)}\n`, {
      encoding: 'utf8',
      flag: 'wx',
    });
    safeTempPath(temporary, true);
    const finalCandidates = candidateSnapshots.map(revalidateCandidateSnapshot);
    const recheckedTarget = safeTempPath(target, false);
    assertDistinctPaths([
      ...finalCandidates,
      recheckedTarget,
    ]);
    fs.renameSync(temporary, target);
  } finally {
    try {
      fs.rmSync(temporary, { force: true });
    } catch {
      // Only the fixed sanitized error is reported by runCli.
    }
  }
}

function runCli(dependencies) {
  try {
    const args = parseArgs(dependencies.argv || []);
    const cwd = path.resolve(dependencies.cwd || process.cwd());
    const mapPath = path.resolve(cwd, args.map);
    if (!mapPath.startsWith(`${cwd}${path.sep}`)) throw new Error('map escapes backend root');
    const readText = dependencies.readText || ((target) => fs.readFileSync(target, 'utf8'));
    const readBaseJson = dependencies.readBaseJson;
    if (typeof readBaseJson !== 'function') throw new Error('base reader is unavailable');
    const dependency = readCandidateSnapshot(args.dependencyCandidate);
    const ownership = readCandidateSnapshot(args.ownershipCandidate);
    const reportTarget = safeTempPath(args.report, false);
    assertDistinctPaths([dependency, ownership, reportTarget]);
    const dependencyText = dependency.text;
    const ownershipText = ownership.text;
    const report = verifyRelocation({
      baseRevision: args.baseRef,
      baseDependencies: readBaseJson(args.baseRef, BASE_DEPENDENCY_PATH),
      candidateDependencies: parseJsonText(dependencyText, 'dependency candidate'),
      baseOwnership: readBaseJson(args.baseRef, BASE_OWNERSHIP_PATH),
      candidateOwnership: parseJsonText(ownershipText, 'ownership candidate'),
      map: parseJsonText(readText(mapPath), 'relocation map'),
      candidateHashes: {
        dependency: dependency.hash,
        ownership: ownership.hash,
      },
    });
    if (dependencies.writeReport) {
      const checkedCandidates = [dependency, ownership].map(revalidateCandidateSnapshot);
      const recheckedReport = safeTempPath(args.report, false);
      assertDistinctPaths([
        ...checkedCandidates,
        recheckedReport,
      ]);
      dependencies.writeReport(args.report, report);
    } else {
      atomicWrite(args.report, report, [dependency, ownership]);
    }
    writeLine(dependencies.stdout, 'R1 baseline relocation verified');
    return 0;
  } catch {
    writeLine(dependencies.stderr, 'ERROR - R1 baseline relocation verification failed');
    return 2;
  }
}

function defaultDependencies(argv) {
  return {
    argv,
    cwd: process.cwd(),
    readBaseJson: (baseRef, repositoryPath) => {
      const result = spawnSync('git', ['show', `${baseRef}:${repositoryPath}`], {
        cwd: path.resolve(__dirname, '../../..'),
        encoding: 'utf8',
        maxBuffer: 32 * 1024 * 1024,
        windowsHide: true,
      });
      if (result.status !== 0 || result.signal || result.error) {
        throw new Error('base baseline cannot be read');
      }
      return parseJsonText(result.stdout, 'base baseline');
    },
    stdout: (message) => process.stdout.write(`${message}\n`),
    stderr: (message) => process.stderr.write(`${message}\n`),
  };
}

module.exports = {
  verifyRelocation,
  runCli,
  canonicalSha256,
};

if (require.main === module) {
  process.exitCode = runCli(defaultDependencies(process.argv.slice(2)));
}

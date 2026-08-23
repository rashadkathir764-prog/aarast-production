'use strict';

const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { types: utilTypes } = require('node:util');
const ts = require('typescript');

const R7_BASE = '31ea5324007fc71fa4b3590fbb98a454ee1deaa7';
const MANIFEST_PATH = 'backend/architecture/r7-collaboration-relocation.json';

const EXPECTED_MOVES = Object.freeze([
  ['backend/src/contribution-history/contribution-history.contracts.ts', 'backend/src/modules/collaboration/internal/contribution-history.contracts.ts'],
  ['backend/src/contribution-history/contribution-history.controller.ts', 'backend/src/modules/collaboration/api/contribution-history.controller.ts'],
  ['backend/src/contribution-history/contribution-history.service.ts', 'backend/src/modules/collaboration/internal/contribution-history.service.ts'],
  ['backend/src/contribution-history/contribution-snapshot.builder.ts', 'backend/src/modules/collaboration/public/contribution-snapshot.builder.ts'],
  ['backend/src/contribution-history/contributor-scope.service.ts', 'backend/src/modules/collaboration/internal/contributor-scope.service.ts'],
  ['backend/src/contribution-history/dto/list-contributions.dto.ts', 'backend/src/modules/collaboration/api/dto/list-contributions.dto.ts'],
  ['backend/src/sharing/dto/create-plan-invite.dto.ts', 'backend/src/modules/collaboration/api/dto/create-plan-invite.dto.ts'],
  ['backend/src/sharing/dto/create-shared-member.dto.ts', 'backend/src/modules/collaboration/api/dto/create-shared-member.dto.ts'],
  ['backend/src/sharing/dto/leave-plan.dto.ts', 'backend/src/modules/collaboration/api/dto/leave-plan.dto.ts'],
  ['backend/src/sharing/dto/request-invite-otp.dto.ts', 'backend/src/modules/collaboration/api/dto/request-invite-otp.dto.ts'],
  ['backend/src/sharing/dto/update-shared-member.dto.ts', 'backend/src/modules/collaboration/api/dto/update-shared-member.dto.ts'],
  ['backend/src/sharing/dto/verify-invite-otp.dto.ts', 'backend/src/modules/collaboration/api/dto/verify-invite-otp.dto.ts'],
  ['backend/src/sharing/invitation-delivery.service.ts', 'backend/src/modules/collaboration/internal/invitation-delivery.service.ts'],
  ['backend/src/sharing/invite-access.service.ts', 'backend/src/modules/collaboration/internal/invite-access.service.ts'],
  ['backend/src/sharing/permission.service.ts', 'backend/src/modules/collaboration/internal/permission.service.ts'],
  ['backend/src/sharing/plan-permissions.ts', 'backend/src/modules/collaboration/internal/plan-permissions.ts'],
  ['backend/src/sharing/sharing.controller.ts', 'backend/src/modules/collaboration/api/sharing.controller.ts'],
  ['backend/src/sharing/sharing.service.ts', 'backend/src/modules/collaboration/internal/sharing.service.ts'],
].map(([from, to]) => Object.freeze({ from, to })));

const EXPECTED_PUBLIC_SNAPSHOT_CONTRACT = Object.freeze({
  path: 'backend/src/modules/collaboration/public/contribution-snapshot.builder.ts',
  exports: Object.freeze([
    'buildContributionSnapshot',
    'canonicalJson',
    'hashContributionSnapshot',
    'validateContributionSnapshot',
  ]),
});

const EXPECTED_PUBLIC_SNAPSHOT_IMPORTS = Object.freeze([
  '@nestjs/common',
  '@prisma/client',
  'node:crypto',
]);

const EXPECTED_CONTROLLER_INVENTORIES = Object.freeze([
  Object.freeze({
    target: 'backend/src/modules/collaboration/api/contribution-history.controller.ts',
    operations: 2,
    fingerprint: '52bfb1432ab942b8c68259f4457788a59a36ea4758a31bc20df42d731e688da4',
  }),
  Object.freeze({
    target: 'backend/src/modules/collaboration/api/sharing.controller.ts',
    operations: 17,
    fingerprint: '14e679f88f40b86586234024ac1f239a21a01cf915219f721f13f448b9767f01',
  }),
]);

const EXPECTED_CONSTRUCTOR_CONSUMERS = Object.freeze([
  Object.freeze({
    from: 'backend/src/sharing/invitation-delivery.service.ts',
    to: 'backend/src/modules/collaboration/internal/invitation-delivery.service.ts',
    consumerClass: 'InvitationDeliveryService',
    parameter: 'transientDelivery',
    parameterIndex: 0,
    token: 'IDENTITY_TRANSIENT_DELIVERY_PORT',
  }),
  Object.freeze({
    from: 'backend/src/sharing/invite-access.service.ts',
    to: 'backend/src/modules/collaboration/internal/invite-access.service.ts',
    consumerClass: 'InviteAccessService',
    parameter: 'auth',
    parameterIndex: 1,
    token: 'IDENTITY_AUTH_PORT',
  }),
  Object.freeze({
    from: 'backend/src/sharing/sharing.service.ts',
    to: 'backend/src/modules/collaboration/internal/sharing.service.ts',
    consumerClass: 'SharingService',
    parameter: 'notifications',
    parameterIndex: 2,
    token: 'NOTIFICATIONS_PORT',
  }),
  Object.freeze({
    from: 'backend/src/sharing/sharing.service.ts',
    to: 'backend/src/modules/collaboration/internal/sharing.service.ts',
    consumerClass: 'SharingService',
    parameter: 'realtime',
    parameterIndex: 5,
    token: 'MESSAGING_REALTIME_PORT',
  }),
]);

const EXPECTED_CONTROLLER_SOURCES = Object.freeze([
  Object.freeze({
    from: 'backend/src/contribution-history/contribution-history.controller.ts',
    to: 'backend/src/modules/collaboration/api/contribution-history.controller.ts',
  }),
  Object.freeze({
    from: 'backend/src/sharing/sharing.controller.ts',
    to: 'backend/src/modules/collaboration/api/sharing.controller.ts',
  }),
]);

const EXPECTED_RETIRED_DEPENDENCY_KEYS = Object.freeze([
  'context-finance-cross-context|src/budget-categories/budget-categories.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-finance-cross-context|src/wedding-costs/wedding-costs.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-guests-cross-context|src/guests/guests.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-offer-acceptance.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-offer-rejection.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-request-cancellation.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-request-creation.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-planning-cross-context|src/wedding-plans/wedding-plans.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-tasks-cross-context|src/tasks/tasks.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
]);

const EXPECTED_OWNERSHIP_PROJECTION = Object.freeze([
  Object.freeze({ from: 'backend/src/contribution-history/contribution-history.service.ts', to: 'backend/src/modules/collaboration/internal/contribution-history.service.ts', records: 5, occurrences: 7 }),
  Object.freeze({ from: 'backend/src/sharing/invite-access.service.ts', to: 'backend/src/modules/collaboration/internal/invite-access.service.ts', records: 1, occurrences: 1 }),
  Object.freeze({ from: 'backend/src/sharing/permission.service.ts', to: 'backend/src/modules/collaboration/internal/permission.service.ts', records: 2, occurrences: 6 }),
  Object.freeze({ from: 'backend/src/sharing/sharing.service.ts', to: 'backend/src/modules/collaboration/internal/sharing.service.ts', records: 20, occurrences: 66 }),
]);

const EXPECTED_OPTIONAL_DEPENDENCIES = Object.freeze([
  Object.freeze({
    from: 'backend/src/sharing/sharing.service.ts',
    to: 'backend/src/modules/collaboration/internal/sharing.service.ts',
    consumerClass: 'SharingService',
    parameter: 'realtime',
    parameterIndex: 5,
    token: 'MESSAGING_REALTIME_PORT',
    optional: true,
    undefinedBehavior: 'unchanged',
  }),
]);

const EXPECTED_BASELINES = Object.freeze({
  baseDependencyRecords: 31,
  retiredDependencyRecords: 9,
  strictDependencyRecords: 22,
  baseOwnershipRecords: 385,
  baseOwnershipOccurrences: 781,
  projectedOwnershipRecords: 28,
  projectedOwnershipOccurrences: 80,
  strictOwnershipRecords: 385,
  strictOwnershipOccurrences: 781,
});

const EXPECTED_ALLOWED_PATHS = Object.freeze([
  'ARCHITECTURE.md',
  'CHANGELOG.md',
  'backend/.dependency-cruiser-known-violations.json',
  'backend/architecture/ownership-baseline.json',
  'backend/architecture/r3-context-boundaries.json',
  'backend/architecture/r7-collaboration-relocation.json',
  'backend/package.json',
  'backend/scripts/architecture/r3-context-scan.cjs',
  'backend/scripts/architecture/r3-scope.cjs',
  'backend/scripts/architecture/r5-identity-scan.cjs',
  'backend/scripts/architecture/r6-sharing-otp-transport-scan.cjs',
  'backend/scripts/architecture/r7-collaboration-relocation-scan.cjs',
  'backend/scripts/security/prisma-config-merge-security.cjs',
  'backend/scripts/smoke/phase2-auth-lifecycle-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-conversation-revocation-smoke.ts',
  'backend/scripts/smoke/phase2-marketplace-write-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-money-authorization-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-notification-authorization-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-notification-preferences-smoke.ts',
  'backend/scripts/smoke/phase2-plan-permission-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-quote-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-sharing-permission-concurrency-smoke.ts',
  'backend/scripts/smoke/phase2-task-guest-permission-concurrency-smoke.ts',
  'backend/scripts/smoke/phase3-context-transition-smoke.ts',
  'backend/src/budget-categories/budget-categories.service.ts',
  'backend/src/contribution-history/contribution-history.contracts.ts',
  'backend/src/contribution-history/contribution-history.controller.ts',
  'backend/src/contribution-history/contribution-history.service.ts',
  'backend/src/contribution-history/contribution-snapshot.builder.ts',
  'backend/src/contribution-history/contributor-scope.service.ts',
  'backend/src/contribution-history/dto/list-contributions.dto.ts',
  'backend/src/guests/guests.service.ts',
  'backend/src/marketplace/quote-offer-acceptance.ts',
  'backend/src/marketplace/quote-offer-rejection.ts',
  'backend/src/marketplace/quote-request-cancellation.ts',
  'backend/src/marketplace/quote-request-creation.ts',
  'backend/src/modules/collaboration/api/contribution-history.controller.ts',
  'backend/src/modules/collaboration/api/dto/create-plan-invite.dto.ts',
  'backend/src/modules/collaboration/api/dto/create-shared-member.dto.ts',
  'backend/src/modules/collaboration/api/dto/leave-plan.dto.ts',
  'backend/src/modules/collaboration/api/dto/list-contributions.dto.ts',
  'backend/src/modules/collaboration/api/dto/request-invite-otp.dto.ts',
  'backend/src/modules/collaboration/api/dto/update-shared-member.dto.ts',
  'backend/src/modules/collaboration/api/dto/verify-invite-otp.dto.ts',
  'backend/src/modules/collaboration/api/sharing.controller.ts',
  'backend/src/modules/collaboration/collaboration.module.ts',
  'backend/src/modules/collaboration/internal/collaboration-history.internal.module.ts',
  'backend/src/modules/collaboration/internal/collaboration-permission.internal.module.ts',
  'backend/src/modules/collaboration/internal/collaboration-scope.internal.module.ts',
  'backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts',
  'backend/src/modules/collaboration/internal/contribution-history.contracts.ts',
  'backend/src/modules/collaboration/internal/contribution-history.service.ts',
  'backend/src/modules/collaboration/internal/contributor-scope.service.ts',
  'backend/src/modules/collaboration/internal/invitation-delivery.service.ts',
  'backend/src/modules/collaboration/internal/invite-access.service.ts',
  'backend/src/modules/collaboration/internal/permission.service.ts',
  'backend/src/modules/collaboration/internal/plan-permissions.ts',
  'backend/src/modules/collaboration/internal/sharing.service.ts',
  'backend/src/modules/collaboration/public/contribution-snapshot.builder.ts',
  'backend/src/sharing/dto/create-plan-invite.dto.ts',
  'backend/src/sharing/dto/create-shared-member.dto.ts',
  'backend/src/sharing/dto/leave-plan.dto.ts',
  'backend/src/sharing/dto/request-invite-otp.dto.ts',
  'backend/src/sharing/dto/update-shared-member.dto.ts',
  'backend/src/sharing/dto/verify-invite-otp.dto.ts',
  'backend/src/sharing/invitation-delivery.service.ts',
  'backend/src/sharing/invite-access.service.ts',
  'backend/src/sharing/permission.service.ts',
  'backend/src/sharing/plan-permissions.ts',
  'backend/src/sharing/sharing.controller.ts',
  'backend/src/sharing/sharing.service.ts',
  'backend/src/tasks/tasks.service.ts',
  'backend/src/wedding-costs/wedding-costs.service.ts',
  'backend/src/wedding-plans/wedding-plans.service.ts',
  'backend/test/architecture-r1-layout.test.ts',
  'backend/test/architecture-r3-closure.test.ts',
  'backend/test/architecture-r3-collaboration-ports.test.ts',
  'backend/test/architecture-r3-composition.test.ts',
  'backend/test/architecture-r3-contexts.test.ts',
  'backend/test/architecture-r3-identity-port.test.ts',
  'backend/test/architecture-r3-notifications-port.test.ts',
  'backend/test/architecture-r3-scope.test.ts',
  'backend/test/architecture-r4-planning-finance-boundary.test.ts',
  'backend/test/architecture-r5-identity-relocation.test.ts',
  'backend/test/architecture-r6-sharing-otp-transport.test.ts',
  'backend/test/architecture-r7-collaboration-relocation.test.ts',
  'backend/test/archived-plan-lifecycle.test.ts',
  'backend/test/contexts.test.ts',
  'backend/test/contribution-history-dedupe.test.ts',
  'backend/test/contribution-history-freeze.test.ts',
  'backend/test/contribution-history-list-consistency.test.ts',
  'backend/test/contribution-history-privacy.test.ts',
  'backend/test/contributor-live-read-boundary.test.ts',
  'backend/test/contributor-permission-authority.test.ts',
  'backend/test/contributor-task-guest-scope.test.ts',
  'backend/test/invite-delivery.test.ts',
  'backend/test/notification-logic.test.ts',
  'backend/test/plan-permissions.test.ts',
  'backend/test/prisma-config-merge-security.test.ts',
  'backend/test/sharing-member-scope.test.ts',
  'backend/test/sharing-permission-ceiling.test.ts',
  'backend/test/sharing-reinvite-authority.test.ts',
  'backend/test/sharing-self-leave.test.ts',
  'docs/README.md',
  'docs/SCRIPTS.md',
  'docs/backend/README.md',
  'docs/project/DECISIONS.md',
  'docs/project/EXECUTION_PLAN.md',
  'docs/project/STATUS.md',
  'docs/qa/README.md',
  'docs/superpowers/plans/2026-08-23-modular-monolith-r7-collaboration-relocation-completion.md',
  'docs/superpowers/plans/2026-08-23-modular-monolith-r7-collaboration-relocation.md',
  'docs/superpowers/specs/2026-08-23-modular-monolith-r7-collaboration-relocation-completion.md',
  'docs/superpowers/specs/2026-08-23-modular-monolith-r7-collaboration-relocation-design.md',
]);

function assertPlainData(value, label, seen = new Set(), depth = 0) {
  if (value === null || typeof value === 'boolean'
      || (typeof value === 'number' && Number.isFinite(value))
      || (typeof value === 'string' && value.length <= 4096)) return;
  if (!value || typeof value !== 'object' || depth > 32 || seen.has(value)
      || utilTypes.isProxy(value)) {
    throw new Error(label + ' must be bounded plain data');
  }
  seen.add(value);
  if (Array.isArray(value)) {
    if (Object.getPrototypeOf(value) !== Array.prototype || value.length > 512) {
      throw new Error(label + ' must be a bounded plain array');
    }
    for (let index = 0; index < value.length; index += 1) {
      const descriptor = Object.getOwnPropertyDescriptor(value, String(index));
      if (!descriptor || !descriptor.enumerable
          || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) {
        throw new Error(label + ' must be dense plain data');
      }
      assertPlainData(value[index], label, seen, depth + 1);
    }
    if (Reflect.ownKeys(value).length !== value.length + 1) {
      throw new Error(label + ' must contain array data only');
    }
  } else {
    if (Object.getPrototypeOf(value) !== Object.prototype) {
      throw new Error(label + ' must be a plain object');
    }
    for (const key of Reflect.ownKeys(value)) {
      const descriptor = Object.getOwnPropertyDescriptor(value, key);
      if (typeof key !== 'string' || !descriptor || !descriptor.enumerable
          || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) {
        throw new Error(label + ' must use plain data properties');
      }
      assertPlainData(value[key], label, seen, depth + 1);
    }
  }
  seen.delete(value);
}

function assertExact(actual, expected, label) {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(label + ' drift detected');
  }
}

function validateRelativePaths(paths, label) {
  if (!Array.isArray(paths)) throw new Error(label + ' must be an array');
  for (const entry of paths) {
    if (typeof entry !== 'string' || !entry || entry.includes('\\')
        || path.posix.isAbsolute(entry) || path.win32.isAbsolute(entry)
        || entry.split('/').includes('.') || entry.split('/').includes('..')) {
      throw new Error(label + ' contains an invalid path');
    }
  }
  if (new Set(paths).size !== paths.length
      || JSON.stringify(paths) !== JSON.stringify([...paths].sort())) {
    throw new Error(label + ' must be sorted and unique');
  }
}

function validateR7Manifest(value) {
  assertPlainData(value, 'R7 manifest');
  const keys = Object.keys(value).sort();
  const expectedKeys = [
    'allowedChangedPaths',
    'baseRevision',
    'expectedBaselines',
    'frozenOptionalDependencies',
    'historicalHandoffs',
    'moves',
    'publicSnapshotContract',
    'schemaVersion',
    'stage',
  ];
  assertExact(keys, expectedKeys, 'R7 manifest keys');
  if (value.schemaVersion !== 1 || value.baseRevision !== R7_BASE) {
    throw new Error('R7 manifest identity is invalid');
  }
  if (value.stage !== 'design') throw new Error('R7 manifest stage is invalid');
  assertExact(value.moves, EXPECTED_MOVES, 'R7 move map');
  assertExact(value.publicSnapshotContract, EXPECTED_PUBLIC_SNAPSHOT_CONTRACT, 'R7 public snapshot contract');
  assertExact(value.historicalHandoffs, {
    constructorConsumers: EXPECTED_CONSTRUCTOR_CONSUMERS,
    controllerSources: EXPECTED_CONTROLLER_SOURCES,
    retiredDependencyKeys: EXPECTED_RETIRED_DEPENDENCY_KEYS,
    ownershipProjection: EXPECTED_OWNERSHIP_PROJECTION,
  }, 'R7 historical handoffs');
  assertExact(value.frozenOptionalDependencies, EXPECTED_OPTIONAL_DEPENDENCIES, 'R7 optional dependencies');
  assertExact(value.expectedBaselines, EXPECTED_BASELINES, 'R7 expected baselines');
  validateRelativePaths(value.allowedChangedPaths, 'R7 allowed paths');
  assertExact(value.allowedChangedPaths, EXPECTED_ALLOWED_PATHS, 'R7 allowed paths');
  return Object.freeze(value);
}

function dependencyKey(record) {
  return [record.rule && record.rule.name, record.from, record.to].join('|');
}

function verifyDesignBaselines(repositoryRoot, manifest) {
  const dependency = JSON.parse(fs.readFileSync(path.join(
    repositoryRoot,
    'backend',
    '.dependency-cruiser-known-violations.json',
  ), 'utf8'));
  if (!Array.isArray(dependency)
      || dependency.length !== manifest.expectedBaselines.baseDependencyRecords) {
    throw new Error('R7 design dependency baseline drift detected');
  }
  const debt = dependency.map(dependencyKey)
    .filter((key) => manifest.historicalHandoffs.retiredDependencyKeys.includes(key));
  assertExact(debt, manifest.historicalHandoffs.retiredDependencyKeys, 'R7 dependency handoff');

  const ownership = JSON.parse(fs.readFileSync(path.join(
    repositoryRoot,
    'backend',
    'architecture',
    'ownership-baseline.json',
  ), 'utf8'));
  if (!ownership || !Array.isArray(ownership.violations)
      || ownership.violations.length !== manifest.expectedBaselines.baseOwnershipRecords) {
    throw new Error('R7 design ownership baseline drift detected');
  }
  const total = ownership.violations.reduce((sum, record) => sum + record.count, 0);
  if (total !== manifest.expectedBaselines.baseOwnershipOccurrences) {
    throw new Error('R7 design ownership occurrence drift detected');
  }
  for (const projection of manifest.historicalHandoffs.ownershipProjection) {
    const records = ownership.violations.filter((record) => record.file === projection.from);
    const occurrences = records.reduce((sum, record) => sum + record.count, 0);
    if (records.length !== projection.records || occurrences !== projection.occurrences) {
      throw new Error('R7 ownership handoff drift detected');
    }
  }
}

function activeMovePath(repositoryRoot, manifest, targetPath) {
  const move = manifest.moves.find((entry) => entry.to === targetPath);
  if (!move) throw new Error('R7 source contract target is outside the move map');
  const sourceExists = fs.existsSync(path.join(repositoryRoot, ...move.from.split('/')));
  const targetExists = fs.existsSync(path.join(repositoryRoot, ...move.to.split('/')));
  if (sourceExists === targetExists) {
    throw new Error('R7 source contract path identity drift detected');
  }
  return sourceExists ? move.from : move.to;
}

function parseTypeScriptSource(repositoryRoot, relativePath) {
  const sourceText = fs.readFileSync(
    path.join(repositoryRoot, ...relativePath.split('/')),
    'utf8',
  );
  const sourceFile = ts.createSourceFile(
    relativePath,
    sourceText,
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.TS,
  );
  if (sourceFile.parseDiagnostics.length > 0) {
    throw new Error('R7 TypeScript source could not be parsed');
  }
  return sourceFile;
}

function decoratorsOf(node) {
  return ts.canHaveDecorators(node) ? (ts.getDecorators(node) || []) : [];
}

function decoratorName(decorator, sourceFile) {
  const expression = decorator.expression;
  if (!ts.isCallExpression(expression)) return expression.getText(sourceFile);
  return expression.expression.getText(sourceFile);
}

function isExported(node) {
  return ts.canHaveModifiers(node)
    && (ts.getModifiers(node) || []).some((modifier) => modifier.kind === ts.SyntaxKind.ExportKeyword);
}

function exportedNames(statement, sourceFile) {
  if (!isExported(statement)) return [];
  if ((ts.isFunctionDeclaration(statement) || ts.isClassDeclaration(statement)
      || ts.isInterfaceDeclaration(statement) || ts.isTypeAliasDeclaration(statement)
      || ts.isEnumDeclaration(statement)) && statement.name) {
    return [statement.name.text];
  }
  if (ts.isVariableStatement(statement)) {
    return statement.declarationList.declarations.map((declaration) => declaration.name.getText(sourceFile));
  }
  return ['<unsupported-export>'];
}

function verifyPublicSnapshotSource(repositoryRoot, manifest) {
  const activePath = activeMovePath(
    repositoryRoot,
    manifest,
    manifest.publicSnapshotContract.path,
  );
  const sourceFile = parseTypeScriptSource(repositoryRoot, activePath);
  let dynamicDependencies = 0;
  const visit = (node) => {
    if (ts.isImportEqualsDeclaration(node)
        || (ts.isCallExpression(node)
          && ((ts.isIdentifier(node.expression) && node.expression.text === 'require')
            || node.expression.kind === ts.SyntaxKind.ImportKeyword))) {
      dynamicDependencies += 1;
    }
    ts.forEachChild(node, visit);
  };
  visit(sourceFile);
  if (dynamicDependencies !== 0) {
    throw new Error('R7 public snapshot dynamic dependency drift detected');
  }
  const imports = sourceFile.statements
    .filter(ts.isImportDeclaration)
    .map((statement) => statement.moduleSpecifier.text)
    .sort();
  assertExact(imports, EXPECTED_PUBLIC_SNAPSHOT_IMPORTS, 'R7 public snapshot imports');
  const exports = sourceFile.statements
    .flatMap((statement) => exportedNames(statement, sourceFile))
    .sort();
  assertExact(exports, [...manifest.publicSnapshotContract.exports].sort(), 'R7 public snapshot exports');
  return Object.freeze({ exports: exports.length, imports: imports.length });
}

function verifyConstructorHandoffs(repositoryRoot, manifest) {
  const sourceFiles = new Map();
  let optional = 0;
  let optionalSyntax = 0;
  for (const move of manifest.moves) {
    const activePath = activeMovePath(repositoryRoot, manifest, move.to);
    const sourceFile = parseTypeScriptSource(repositoryRoot, activePath);
    sourceFiles.set(move.to, sourceFile);
    const visit = (node) => {
      optional += decoratorsOf(node)
        .filter((decorator) => decoratorName(decorator, sourceFile) === 'Optional')
        .length;
      ts.forEachChild(node, visit);
    };
    visit(sourceFile);
    for (const classNode of sourceFile.statements.filter(ts.isClassDeclaration)) {
      for (const constructorNode of classNode.members.filter(ts.isConstructorDeclaration)) {
        for (const parameter of constructorNode.parameters) {
          if (parameter.initializer) {
            throw new Error('R7 constructor default drift detected');
          }
          let typeContainsUndefined = false;
          if (parameter.type) {
            const visitType = (node) => {
              if (node.kind === ts.SyntaxKind.UndefinedKeyword) typeContainsUndefined = true;
              ts.forEachChild(node, visitType);
            };
            visitType(parameter.type);
          }
          if (parameter.questionToken || typeContainsUndefined) optionalSyntax += 1;
        }
      }
    }
  }

  for (const consumer of manifest.historicalHandoffs.constructorConsumers) {
    const sourceFile = sourceFiles.get(consumer.to);
    const classNode = sourceFile.statements.find((statement) => (
      ts.isClassDeclaration(statement)
      && statement.name
      && statement.name.text === consumer.consumerClass
    ));
    const constructors = classNode
      ? classNode.members.filter(ts.isConstructorDeclaration)
      : [];
    if (constructors.length !== 1) {
      throw new Error('R7 constructor class drift detected');
    }
    const parameter = constructors[0].parameters[consumer.parameterIndex];
    if (!parameter || parameter.name.getText(sourceFile) !== consumer.parameter) {
      throw new Error('R7 constructor parameter drift detected');
    }
    const decorators = decoratorsOf(parameter);
    const names = decorators.map((decorator) => decoratorName(decorator, sourceFile));
    const frozen = manifest.frozenOptionalDependencies.find((entry) => (
      entry.to === consumer.to
      && entry.consumerClass === consumer.consumerClass
      && entry.parameterIndex === consumer.parameterIndex
    ));
    const expectedNames = frozen ? ['Optional', 'Inject'] : ['Inject'];
    if (JSON.stringify(names) !== JSON.stringify(expectedNames)) {
      throw new Error('R7 constructor optionality drift detected');
    }
    const inject = decorators.find((decorator) => decoratorName(decorator, sourceFile) === 'Inject');
    const expression = inject && inject.expression;
    if (!expression || !ts.isCallExpression(expression)
        || expression.arguments.length !== 1
        || expression.arguments[0].getText(sourceFile) !== consumer.token) {
      throw new Error('R7 constructor injection drift detected');
    }
    if (Boolean(parameter.questionToken) !== Boolean(frozen)) {
      throw new Error('R7 constructor optionality drift detected');
    }
  }
  if (optional !== manifest.frozenOptionalDependencies.length
      || optionalSyntax !== manifest.frozenOptionalDependencies.length) {
    throw new Error('R7 constructor optionality drift detected');
  }
  return Object.freeze({
    consumers: manifest.historicalHandoffs.constructorConsumers.length,
    optional,
  });
}

function controllerInventory(sourceFile) {
  const classes = sourceFile.statements
    .filter(ts.isClassDeclaration)
    .map((classNode) => ({
      class: classNode.name ? classNode.name.text : '<anonymous>',
      decorators: decoratorsOf(classNode).map((decorator) => decorator.expression.getText(sourceFile)),
      methods: classNode.members.filter(ts.isMethodDeclaration).map((method) => ({
        name: method.name.getText(sourceFile),
        decorators: decoratorsOf(method).map((decorator) => decorator.expression.getText(sourceFile)),
        params: method.parameters.map((parameter) => (
          decoratorsOf(parameter).map((decorator) => decorator.expression.getText(sourceFile))
        )),
      })),
    }));
  const operations = classes.reduce((sum, entry) => sum + entry.methods.length, 0);
  const fingerprint = crypto.createHash('sha256')
    .update(JSON.stringify(classes))
    .digest('hex');
  return { operations, fingerprint };
}

function verifyControllerHandoffs(repositoryRoot, manifest) {
  let operations = 0;
  for (const expected of EXPECTED_CONTROLLER_INVENTORIES) {
    if (!manifest.historicalHandoffs.controllerSources.some((entry) => entry.to === expected.target)) {
      throw new Error('R7 controller handoff drift detected');
    }
    const activePath = activeMovePath(repositoryRoot, manifest, expected.target);
    const actual = controllerInventory(parseTypeScriptSource(repositoryRoot, activePath));
    assertExact(actual, {
      operations: expected.operations,
      fingerprint: expected.fingerprint,
    }, 'R7 controller inventory');
    operations += actual.operations;
  }
  return Object.freeze({ controllers: EXPECTED_CONTROLLER_INVENTORIES.length, operations });
}

function scanR7CollaborationRelocation(options) {
  if (!options || typeof options !== 'object' || Array.isArray(options)) {
    throw new Error('R7 scan options are invalid');
  }
  const manifest = validateR7Manifest(options.manifest);
  if (typeof options.repositoryRoot !== 'string' || !path.isAbsolute(options.repositoryRoot)) {
    throw new Error('R7 repository root must be absolute');
  }
  let sourceFiles = 0;
  let targetFiles = 0;
  for (const move of manifest.moves) {
    if (fs.existsSync(path.join(options.repositoryRoot, ...move.from.split('/')))) sourceFiles += 1;
    if (fs.existsSync(path.join(options.repositoryRoot, ...move.to.split('/')))) targetFiles += 1;
  }
  if (sourceFiles !== 18 || targetFiles !== 0) {
    throw new Error('R7 design stage does not match the filesystem');
  }
  verifyDesignBaselines(options.repositoryRoot, manifest);
  verifyPublicSnapshotSource(options.repositoryRoot, manifest);
  verifyConstructorHandoffs(options.repositoryRoot, manifest);
  verifyControllerHandoffs(options.repositoryRoot, manifest);
  return Object.freeze({ ok: true, stage: manifest.stage, sourceFiles, targetFiles });
}

function runCli(dependencies = {}) {
  const argv = dependencies.argv || process.argv.slice(2);
  const stdout = dependencies.stdout || ((message) => process.stdout.write(message + '\n'));
  const stderr = dependencies.stderr || ((message) => process.stderr.write(message + '\n'));
  const repositoryRoot = dependencies.repositoryRoot || path.resolve(__dirname, '../../..');
  try {
    if (argv.length !== 1 || argv[0] !== '--check') throw new Error('invalid arguments');
    const manifest = JSON.parse(fs.readFileSync(path.join(
      repositoryRoot,
      ...MANIFEST_PATH.split('/'),
    ), 'utf8'));
    const result = scanR7CollaborationRelocation({ repositoryRoot, manifest });
    stdout('PASS - R7 Collaboration relocation: stage=' + result.stage
      + ', source=' + result.sourceFiles + ', target=' + result.targetFiles);
    return 0;
  } catch {
    stderr('ERROR - R7 Collaboration relocation validation failed');
    return 2;
  }
}

module.exports = {
  EXPECTED_ALLOWED_PATHS,
  EXPECTED_BASELINES,
  EXPECTED_MOVES,
  MANIFEST_PATH,
  R7_BASE,
  runCli,
  scanR7CollaborationRelocation,
  validateR7Manifest,
  verifyConstructorHandoffs,
  verifyControllerHandoffs,
  verifyPublicSnapshotSource,
};

if (require.main === module) process.exitCode = runCli();

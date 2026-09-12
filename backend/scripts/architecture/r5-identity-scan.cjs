'use strict';

const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { types: utilTypes } = require('node:util');
const ts = require('typescript');
const {
  expectedR12aDependencyRecords,
  expectedR12aSuccessorDependencyRecords,
  expectedR12aOwnershipBaseline,
  normalizeR12aIdentityProviderRatingImport,
  validateR12aManifest,
} = require('./r12a-backoffice-catalog-public-contracts-scan.cjs');

const R5_BASE = '9dab73acdc187a4a18d8a675713d8ded40a16d02';
const MANIFEST_PATH = 'backend/architecture/r5-identity-relocation.json';
const STAGES = Object.freeze(['inventory', 'task-2', 'task-3', 'task-4', 'strict']);
const R5_SECURITY_CHECKPOINT_PATHS = Object.freeze([
  'backend/architecture/r5-identity-relocation.json',
  'backend/package-lock.json',
  'backend/package.json',
  'backend/scripts/security/prisma-config-merge-security.cjs',
  'backend/test/architecture-r5-identity-relocation.test.ts',
  'backend/test/prisma-config-merge-security.test.ts',
  'docs/SCRIPTS.md',
  'docs/superpowers/plans/2026-08-20-modular-monolith-r5-identity-relocation.md',
  'docs/superpowers/plans/2026-08-21-r5-prisma-config-merge-security-checkpoint.md',
  'docs/superpowers/specs/2026-08-20-modular-monolith-r5-identity-relocation-design.md',
  'docs/superpowers/specs/2026-08-21-r5-prisma-config-merge-security-checkpoint-design.md',
]);
const STATIC_HASHES = Object.freeze({
  moves: 'b4cfefb11fa70c69d02e5d72324eec3411c69954b17b97d55839beb49c798f66',
  publicRuntimeContracts: '408ba2aeef53e6fdbccfcbaecad2a47ff055cf78d969ee07fd322d4aa10261d2',
  qaHarnessCorrections: '8ec309583ce994774e044b9d242575e069cc27bab70e50ac62707a274bf654f0',
  retiredRoots: '36ddd91996084e08e19a1645e8382d94dd3005d4f2d77b5c7653c5e707ef0984',
  expectedBaselines: '5c693143b483f7df2eb9e732adb6ba55f1ba1409fa22fa247e4aa5129e98da1e',
  allowedChangedPaths: 'fe9232b6c4584090baf4a910d78eac3d2eed517c970046ea56dc0f734b210d35',
});
const AUTH_STAGE_HASHES = Object.freeze({
  'backend/src/modules/identity/internal/auth/auth-challenge-cleanup.scheduler.ts': '3e648ecf471097575ce9a3bd58b3e369cdc6481d031e8699a488686ddbd62ac4',
  'backend/src/modules/identity/api/auth.controller.ts': 'b2a12009154ff773cfdeea207467673b5d45ff5397ed0f3162efdc4dcc2aace0',
  'backend/src/modules/identity/internal/auth/auth.service.ts': '18e18c339e156c614643f1fa3501897f78426c69bd0f6ff16091a9c1bff09388',
  'backend/src/modules/identity/api/auth-dto/admin-password-reset-confirm.dto.ts': '08b03870968877f13a57bd1d6381cbedb0441790904a9c71513343aa6ab337e1',
  'backend/src/modules/identity/api/auth-dto/admin-password-reset-request.dto.ts': '99db47869fd4a69121c456368aa9c950f1a04fdb223ec2d1cf5dfa0f0aeba782',
  'backend/src/modules/identity/api/auth-dto/complete-admin-login.dto.ts': 'a728c65d2a8d73eaccbd5ddfc6f019bb69758b3bc0d51e970f91b33443b45bb3',
  'backend/src/modules/identity/api/auth-dto/complete-registration.dto.ts': '73f27c87065ef23f40d4beed6f614cb1e5072799bc6377e12643f67d77c348b6',
  'backend/src/modules/identity/api/auth-dto/login.dto.ts': '72eb8b68c5dd7286adf0dc720cd2ec46b10a98d0f86b5f5bcc9802373b5d7c87',
  'backend/src/modules/identity/api/auth-dto/logout.dto.ts': '765b1403a565c220d11f0f3e305b5f79c237434c0323ec5bd89711439496138c',
  'backend/src/modules/identity/api/auth-dto/password-reset-confirm.dto.ts': 'c50ba21d476c9dea0dd64138cf1c421bdaeee39284cb23205da0179f53d073a9',
  'backend/src/modules/identity/api/auth-dto/password-reset-request.dto.ts': '063e1a909cd2c44536b6f0f610657183b28437e32ddcc474b1208c4a3f53ee00',
  'backend/src/modules/identity/api/auth-dto/refresh.dto.ts': 'b99e06eeb60b35da89bff3e96ad6feee0a9c1aefbcf57b5ed0d89a693f79e4e0',
  'backend/src/modules/identity/api/auth-dto/register.dto.ts': '1da820f62172b53511aa84d7f83a9c89fe84e327c4c29e88566709e6cb58281b',
  'backend/src/modules/identity/api/auth-dto/request-otp.dto.ts': 'b63f2b7adb381be46c17d3fcad614a2ec1fb690d2cbcac52aee30fc32e6482fc',
  'backend/src/modules/identity/api/auth-dto/verify-otp.dto.ts': 'eb414cee0767fe180662d25a0d00bf9574629f577cb82ed5b67c26f1fed510f2',
  'backend/src/modules/identity/internal/auth/jwt-secret.ts': '935ee2c98d5580698363060dc50fb900572ff12515c3ef94ba349f492958b5b5',
  'backend/src/modules/identity/internal/auth/jwt.strategy.ts': '53e81a8ae84368462e835a9148cbc9a90e64f232a5a15212348a81b72521d118',
  'backend/src/modules/identity/internal/auth/login-throttle-cleanup.scheduler.ts': 'ec26f161cb9558d1791f5097d9c609d2fc2fd7bad8eb72a871a5fef42b1bf769',
  'backend/src/modules/identity/internal/auth/login-throttle.service.ts': '434f3e1e5ae72ad29f37ffae0c2e61d98940e475c64f0a42c762443a65753913',
  'backend/src/modules/identity/internal/auth/otp-channel.ts': 'eabda733c0d29c9825e58887223ad108175de342a83c6404d128777ab2ed9939',
  'backend/src/modules/identity/internal/auth/otp-dispatch-quota-cleanup.scheduler.ts': '2ad3813b9aa260e075912b3d352292518ba2995c4e0c07eba6b572d22ed47594',
  'backend/src/modules/identity/internal/auth/otp-dispatch-quota.service.ts': '15610b3d0cef600f541379e655c1861095033c14088714fe81c1ab30c821786f',
  'backend/src/modules/identity/internal/auth/refresh-token-policy.ts': '75bbdad072c93d286ebafdeca29e116dcfab6e147e4d5bbeeb009c54173675d4',
  'backend/src/modules/identity/identity.module.ts': '30bc5a6272e1ab61c23c8991b9dde2d1d693b5ea5bb523d3459fa429776fe6b8',
  'backend/src/modules/identity/internal/identity-auth.internal.module.ts': '901f103d8ceda80f3338dfe93b4121b33090079ddfc24f9694dad562359975de',
  'backend/src/main.ts': '3d8d6cf5c950be5e301d905cb922d708dd9fc18d74fbe654b48a8c507d4659b5',
});
const PROFILE_STAGE_HASHES = Object.freeze({
  'backend/src/modules/identity/api/contexts.controller.ts': '4f0da66fa89ea43a3f2f4a779a2937d7f9229d511353835d87681f731bf70d52',
  'backend/src/modules/identity/internal/profile/contexts.service.ts': 'dc002bb485abb8fc7e07957db7a86459ec244d929623c886b41c157a959affc8',
  'backend/src/modules/identity/api/context-dto/validate-context.dto.ts': 'f0f2b6145ad6d4767577f7e5d827b2a33a5aec0a2688139b81171fc869df6d55',
  'backend/src/modules/identity/api/me.controller.ts': 'aa541765674450e347f3ba2f0c8d6e36f23100d2c80cd66b23d47a6bffeb0a75',
  'backend/src/modules/identity/api/account-deletion-status.controller.ts': 'e819551d0eea5497318c03b3b782121fb3692a0daf8aa445e050d47179a046be',
  'backend/src/modules/identity/api/user-dto/account-deletion-status.dto.ts': 'abf6e0fdc9e3f52b8bedb43e8d0971869bbdee8f43f52d8df84186f9a187633d',
  'backend/src/modules/identity/api/user-dto/update-profile.dto.ts': '608a20c00abd2e56c8b025abc3d267126919b75343ddb71eccaf70b464dfca10',
  'backend/src/modules/identity/api/user-dto/update-settings.dto.ts': 'a984bf7ec5305b154501ad8ec888013bca867860c4053f75eb6257180fd9ebd6',
  'backend/src/modules/identity/api/user-dto/user-lookup.dto.ts': 'cee52f86c98cd790d4e22348cdd9b762058c5219c6afee6426c29f22bd552e79',
  'backend/src/modules/identity/api/users.controller.ts': 'c02ed21af85593eb9032029f5072232f32d82023d9485ef16172363961ec2a59',
  'backend/src/modules/identity/internal/profile/users.service.ts': 'a8edc6ce6264010098842d7a6b7a806eb0a6cf76c2e6e4a5d45a3bf81cfb109c',
  'backend/src/modules/identity/internal/identity-profile.internal.module.ts': '7c5aea591785d6e2c963125f6247a777859212abfd943467f41ba4aaee074cf8',
});
const R5_BASE_DEPENDENCY_HASH =
  'd912959a094fe96403267114f346cbe0082f4764dabd451bc78a8f18502a21b0';
const R5_BASE_OWNERSHIP_HASH =
  '228edf06082b914f56f4c4d98468640c448ed35ae873620a7f72df6ac1a9c26a';
const REMAINING_DEPENDENCY_KEYS = Object.freeze([
  'context-backoffice-cross-context|src/admin/admin-mutation-executor.ts|src/marketplace/provider-review-rating.ts',
  'context-catalog-cross-context|src/catalogs/administrative-catalog.service.ts|src/admin/admin-mutation-gate.ts',
  'context-catalog-cross-context|src/catalogs/catalogs.controller.ts|src/admin/admin-permission.decorator.ts',
  'context-catalog-cross-context|src/catalogs/catalogs.controller.ts|src/admin/admin-permission.guard.ts',
  'context-catalog-cross-context|src/catalogs/catalogs.controller.ts|src/admin/admin.guard.ts',
  'context-catalog-cross-context|src/catalogs/reference-catalog.service.ts|src/admin/admin-mutation-gate.ts',
  'context-finance-cross-context|src/budget-categories/budget-categories.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-finance-cross-context|src/wedding-costs/wedding-costs.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-guests-cross-context|src/guests/guests.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-insights-cross-context|src/dashboard/dashboard.contracts.ts|src/wedding-plans/wedding-location.ts',
  'context-insights-cross-context|src/dashboard/dashboard.service.ts|src/wedding-plans/wedding-location.ts',
  'context-marketplace-cross-context|src/marketplace/marketplace.presenter.ts|src/wedding-plans/wedding-location.ts',
  'context-marketplace-cross-context|src/marketplace/marketplace.service.ts|src/wedding-costs/wedding-cost.presenter.ts',
  'context-marketplace-cross-context|src/marketplace/marketplace.service.ts|src/wedding-plans/wedding-location.ts',
  'context-marketplace-cross-context|src/marketplace/quote-offer-acceptance.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-offer-acceptance.ts|src/conversations/conversation-lifecycle.ts',
  'context-marketplace-cross-context|src/marketplace/quote-offer-acceptance.ts|src/wedding-costs/wedding-cost.presenter.ts',
  'context-marketplace-cross-context|src/marketplace/quote-offer-rejection.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-offer-rejection.ts|src/conversations/conversation-lifecycle.ts',
  'context-marketplace-cross-context|src/marketplace/quote-request-cancellation.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-request-cancellation.ts|src/conversations/conversation-lifecycle.ts',
  'context-marketplace-cross-context|src/marketplace/quote-request-creation.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-marketplace-cross-context|src/marketplace/quote-request-creation.ts|src/conversations/conversation-lifecycle.ts',
  'context-marketplace-cross-context|src/provider-dashboard/provider-dashboard.service.ts|src/conversations/conversation-lifecycle.ts',
  'context-marketplace-cross-context|src/provider-dashboard/provider-dashboard.service.ts|src/wedding-plans/wedding-location.ts',
  'context-messaging-cross-context|src/conversations/conversations.service.ts|src/provider-dashboard/provider-access-policy.ts',
  'context-notifications-cross-context|src/notifications/notifications.service.ts|src/provider-dashboard/provider-access-policy.ts',
  'context-planning-cross-context|src/onboarding/dto/import-local-plan.dto.ts|src/guests/dto/create-guest.dto.ts',
  'context-planning-cross-context|src/onboarding/dto/import-local-plan.dto.ts|src/tasks/dto/create-task.dto.ts',
  'context-planning-cross-context|src/wedding-plans/wedding-plans.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
  'context-tasks-cross-context|src/tasks/tasks.service.ts|src/contribution-history/contribution-snapshot.builder.ts',
]);
const R7_HISTORICAL_DEPENDENCY_HASH =
  '82f08c01aa76b18e1d64b725358ebac335750ffee7fe7b0898ea9c34b7c25a42';
const R7_HISTORICAL_OWNERSHIP_HASH =
  '139b166d5c5b1dad20954a66118188a991704ca6e3911a80fe7d0fc07489af41';
const R7_HISTORY_OWNERSHIP_PROJECTION = Object.freeze({
  from: 'backend/src/contribution-history/contribution-history.service.ts',
  to: 'backend/src/modules/collaboration/internal/contribution-history.service.ts',
  records: 5,
  occurrences: 7,
});
const R7_SHARING_OWNERSHIP_PROJECTIONS = Object.freeze([
  Object.freeze({
    from: 'backend/src/sharing/invite-access.service.ts',
    to: 'backend/src/modules/collaboration/internal/invite-access.service.ts',
    records: 1,
    occurrences: 1,
  }),
  Object.freeze({
    from: 'backend/src/sharing/permission.service.ts',
    to: 'backend/src/modules/collaboration/internal/permission.service.ts',
    records: 2,
    occurrences: 6,
  }),
  Object.freeze({
    from: 'backend/src/sharing/sharing.service.ts',
    to: 'backend/src/modules/collaboration/internal/sharing.service.ts',
    records: 20,
    occurrences: 66,
  }),
]);
const R7_RETIRED_DEPENDENCY_KEYS = Object.freeze(REMAINING_DEPENDENCY_KEYS.filter(
  (key) => key.endsWith('|src/contribution-history/contribution-snapshot.builder.ts'),
));
const MAX_ARRAY_ITEMS = 1000;
const MAX_TEXT_LENGTH = 4096;

function plainObject(value, label) {
  if (!value || typeof value !== 'object' || Array.isArray(value)
      || utilTypes.isProxy(value) || Object.getPrototypeOf(value) !== Object.prototype) {
    throw new Error(`${label} must be a plain object`);
  }
  for (const key of Reflect.ownKeys(value)) {
    const descriptor = Object.getOwnPropertyDescriptor(value, key);
    if (typeof key !== 'string' || !descriptor || !descriptor.enumerable
        || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) {
      throw new Error(`${label} must use plain data properties`);
    }
  }
  return value;
}

function denseArray(value, label) {
  if (!Array.isArray(value) || utilTypes.isProxy(value)
      || Object.getPrototypeOf(value) !== Array.prototype
      || value.length > MAX_ARRAY_ITEMS) {
    throw new Error(`${label} must be a bounded plain array`);
  }
  for (let index = 0; index < value.length; index += 1) {
    const descriptor = Object.getOwnPropertyDescriptor(value, String(index));
    if (!descriptor || !descriptor.enumerable
        || !Object.prototype.hasOwnProperty.call(descriptor, 'value')) {
      throw new Error(`${label} must be dense plain data`);
    }
  }
  const ownKeys = Reflect.ownKeys(value);
  if (ownKeys.some((key) => typeof key !== 'string')
      || ownKeys.length !== value.length + 1 || !ownKeys.includes('length')) {
    throw new Error(`${label} must contain array data only`);
  }
  return value;
}

function assertDeepPlainData(value, label, seen = new Set(), depth = 0) {
  if (value === null || typeof value === 'boolean'
      || (typeof value === 'number' && Number.isFinite(value))
      || (typeof value === 'string' && value.length <= MAX_TEXT_LENGTH)) return;
  if (!value || typeof value !== 'object' || depth > 32 || seen.has(value)) {
    throw new Error(`${label} must be bounded plain data`);
  }
  seen.add(value);
  if (Array.isArray(value)) {
    const array = denseArray(value, label);
    for (let index = 0; index < array.length; index += 1) {
      assertDeepPlainData(
        Object.getOwnPropertyDescriptor(array, String(index)).value,
        `${label}[${index}]`,
        seen,
        depth + 1,
      );
    }
  } else {
    const object = plainObject(value, label);
    for (const key of Object.keys(object)) {
      assertDeepPlainData(
        Object.getOwnPropertyDescriptor(object, key).value,
        `${label}.${key}`,
        seen,
        depth + 1,
      );
    }
  }
  seen.delete(value);
}

function exactObject(value, keys, label) {
  const object = plainObject(value, label);
  if (Object.keys(object).sort().join('|') !== [...keys].sort().join('|')) {
    throw new Error(`${label} keys are invalid`);
  }
  return object;
}

function hash(value) {
  return crypto.createHash('sha256').update(JSON.stringify(value)).digest('hex');
}

function relativePath(value, label) {
  if (typeof value !== 'string' || value.length === 0 || value.length > MAX_TEXT_LENGTH
      || value.includes('\\') || path.posix.isAbsolute(value)
      || value.split('/').includes('.') || value.split('/').includes('..')
      || /[\u0000-\u001f]/u.test(value)) {
    throw new Error(`${label} contains an invalid path`);
  }
  return value;
}

function validateMove(value, label) {
  const move = exactObject(value, ['from', 'to'], label);
  return Object.freeze({
    from: relativePath(move.from, `${label}.from`),
    to: relativePath(move.to, `${label}.to`),
  });
}

function validatePublicRuntimeContract(value, label) {
  const contract = exactObject(value, ['source', 'target', 'declarations'], label);
  const declarations = denseArray(contract.declarations, `${label}.declarations`).map(
    (entry, index) => {
      if (typeof entry !== 'string' || !/^(class|const|function|interface|type):[A-Za-z_$][\w$]*$/u.test(entry)) {
        throw new Error(`${label}.declarations[${index}] is invalid`);
      }
      return entry;
    },
  );
  if (new Set(declarations).size !== declarations.length
      || JSON.stringify(declarations) !== JSON.stringify([...declarations].sort())) {
    throw new Error(`${label}.declarations must be sorted and unique`);
  }
  return Object.freeze({
    source: relativePath(contract.source, `${label}.source`),
    target: relativePath(contract.target, `${label}.target`),
    declarations: Object.freeze(declarations),
  });
}

function validateQaHarnessCorrection(value, label) {
  const correction = exactObject(
    value,
    ['path', 'baseSha256', 'approvedSha256', 'rationale'],
    label,
  );
  for (const key of ['baseSha256', 'approvedSha256']) {
    if (typeof correction[key] !== 'string' || !/^[a-f0-9]{64}$/u.test(correction[key])) {
      throw new Error(`${label}.${key} is invalid`);
    }
  }
  if (typeof correction.rationale !== 'string' || correction.rationale.length === 0
      || correction.rationale.length > MAX_TEXT_LENGTH) {
    throw new Error(`${label}.rationale is invalid`);
  }
  return Object.freeze({
    path: relativePath(correction.path, `${label}.path`),
    baseSha256: correction.baseSha256,
    approvedSha256: correction.approvedSha256,
    rationale: correction.rationale,
  });
}

function validatePathList(value, label) {
  const entries = denseArray(value, label).map(
    (entry, index) => relativePath(entry, `${label}[${index}]`),
  );
  if (new Set(entries).size !== entries.length
      || JSON.stringify(entries) !== JSON.stringify([...entries].sort())) {
    throw new Error(`${label} must be sorted and unique`);
  }
  return entries;
}

function validateR5Manifest(value) {
  assertDeepPlainData(value, 'R5 identity manifest');
  const manifest = exactObject(value, [
    'schemaVersion',
    'baseRevision',
    'stage',
    'moves',
    'publicRuntimeContracts',
    'qaHarnessCorrections',
    'retiredRoots',
    'expectedBaselines',
    'allowedChangedPaths',
  ], 'R5 identity manifest');
  if (manifest.schemaVersion !== 1 || manifest.baseRevision !== R5_BASE) {
    throw new Error('R5 identity manifest identity is invalid');
  }
  if (!STAGES.includes(manifest.stage)) throw new Error('R5 identity manifest stage is invalid');

  const moves = denseArray(manifest.moves, 'R5 identity manifest moves')
    .map((move, index) => validateMove(move, `R5 identity manifest moves[${index}]`));
  const publicRuntimeContracts = denseArray(
    manifest.publicRuntimeContracts,
    'R5 identity manifest public runtime',
  ).map((contract, index) => validatePublicRuntimeContract(
    contract,
    `R5 identity manifest public runtime[${index}]`,
  ));
  const qaHarnessCorrections = denseArray(
    manifest.qaHarnessCorrections,
    'R5 identity manifest QA harness corrections',
  ).map((correction, index) => validateQaHarnessCorrection(
    correction,
    `R5 identity manifest QA harness corrections[${index}]`,
  ));
  const correctionPaths = qaHarnessCorrections.map((correction) => correction.path);
  if (new Set(correctionPaths).size !== correctionPaths.length
      || JSON.stringify(correctionPaths) !== JSON.stringify([...correctionPaths].sort())) {
    throw new Error('R5 identity manifest QA harness corrections must be sorted and unique');
  }
  const retiredRoots = denseArray(manifest.retiredRoots, 'R5 identity manifest retired roots')
    .map((root, index) => relativePath(root, `R5 identity manifest retired roots[${index}]`));
  const expectedBaselines = exactObject(manifest.expectedBaselines, [
    'dependencyRecords',
    'ownershipRecords',
    'ownershipOccurrences',
  ], 'R5 identity manifest expected baselines');
  for (const [key, expected] of Object.entries({
    dependencyRecords: 31,
    ownershipRecords: 385,
    ownershipOccurrences: 781,
  })) {
    if (expectedBaselines[key] !== expected) {
      throw new Error('R5 identity manifest expected baselines are invalid');
    }
  }
  const allowedChangedPaths = validatePathList(
    manifest.allowedChangedPaths,
    'R5 identity manifest allowed paths',
  );

  const staticValues = {
    moves,
    publicRuntimeContracts,
    qaHarnessCorrections,
    retiredRoots,
    expectedBaselines,
    allowedChangedPaths,
  };
  for (const [key, expectedHash] of Object.entries(STATIC_HASHES)) {
    if (hash(staticValues[key]) !== expectedHash) {
      throw new Error(`R5 identity manifest ${key} drift detected`);
    }
  }
  return Object.freeze({
    schemaVersion: 1,
    baseRevision: R5_BASE,
    stage: manifest.stage,
    moves: Object.freeze(moves),
    publicRuntimeContracts: Object.freeze(publicRuntimeContracts),
    qaHarnessCorrections: Object.freeze(qaHarnessCorrections),
    retiredRoots: Object.freeze(retiredRoots),
    expectedBaselines: Object.freeze({ ...expectedBaselines }),
    allowedChangedPaths: Object.freeze(allowedChangedPaths),
  });
}

const R5_ARCHITECTURE_SCRIPT =
  'npm run architecture:imports && npm run architecture:ownership && npm run architecture:ports && npm run architecture:r3 && npm run architecture:r4 && npm run architecture:r5';
const R6_ARCHITECTURE_SCRIPT =
  R5_ARCHITECTURE_SCRIPT + ' && npm run architecture:r6';
const R7_ARCHITECTURE_SCRIPT =
  R6_ARCHITECTURE_SCRIPT + ' && npm run architecture:r7';
const R8_ARCHITECTURE_SCRIPT =
  R7_ARCHITECTURE_SCRIPT + ' && npm run architecture:r8';
const R12A_ARCHITECTURE_SCRIPT =
  R8_ARCHITECTURE_SCRIPT + ' && npm run architecture:r12a';
const R6_STANDALONE_SCRIPT =
  'node scripts/architecture/r6-sharing-otp-transport-scan.cjs --check';
const R7_STANDALONE_SCRIPT =
  'node scripts/architecture/r7-collaboration-relocation-scan.cjs --check';
const R8_STANDALONE_SCRIPT =
  'node scripts/architecture/r8-global-module-removal-scan.cjs --check';
const R12A_STANDALONE_SCRIPT =
  'node scripts/architecture/r12a-backoffice-catalog-public-contracts-scan.cjs --check';
const R5_SECURITY_PACKAGE_JSON_SHA256 =
  '6db5c9fc4f6b6f7b3088cf351e61917d6dc62dfbeee6f816ffacb957f8d883ef';
const R6_IDENTITY_MODULE_IMPORT =
  'import { IdentityTransientDeliveryPublicModule } from "./public/identity-transient-delivery-public.module";';
const R6_IDENTITY_MODULE_REGISTRATION =
  '    IdentityTransientDeliveryPublicModule,\n';

function projectR6ArchitectureScriptsForR5Security(value) {
  assertDeepPlainData(value, 'R5 security package');
  const packageJson = plainObject(value, 'R5 security package');
  const scripts = plainObject(packageJson.scripts, 'R5 security package scripts');
  let projectedScripts = { ...scripts };
  const r12aScriptKeys = Object.keys(projectedScripts)
    .filter((scriptName) => scriptName.startsWith('architecture:r12a'));
  const hasR12aAggregateIdentity = typeof projectedScripts.architecture === 'string'
    && projectedScripts.architecture.includes('architecture:r12a');
  if (r12aScriptKeys.length > 0 || hasR12aAggregateIdentity) {
    if (r12aScriptKeys.length !== 1
        || r12aScriptKeys[0] !== 'architecture:r12a'
        || projectedScripts['architecture:r12a'] !== R12A_STANDALONE_SCRIPT
        || projectedScripts.architecture !== R12A_ARCHITECTURE_SCRIPT) {
      throw new Error('R5 security R12A architecture delegation is invalid');
    }
    delete projectedScripts['architecture:r12a'];
    projectedScripts.architecture = R8_ARCHITECTURE_SCRIPT;
  }
  const r8ScriptKeys = Object.keys(projectedScripts)
    .filter((scriptName) => scriptName.startsWith('architecture:r8'));
  const hasR8AggregateIdentity = typeof projectedScripts.architecture === 'string'
    && projectedScripts.architecture.includes('architecture:r8');
  if (r8ScriptKeys.length > 0 || hasR8AggregateIdentity) {
    if (r8ScriptKeys.length !== 1
        || r8ScriptKeys[0] !== 'architecture:r8'
        || projectedScripts['architecture:r8'] !== R8_STANDALONE_SCRIPT
        || projectedScripts.architecture !== R8_ARCHITECTURE_SCRIPT) {
      throw new Error('R5 security R8 architecture delegation is invalid');
    }
    delete projectedScripts['architecture:r8'];
    projectedScripts.architecture = R7_ARCHITECTURE_SCRIPT;
  }
  if (Object.prototype.hasOwnProperty.call(projectedScripts, 'architecture:r7')) {
    if (projectedScripts['architecture:r7'] !== R7_STANDALONE_SCRIPT
        || projectedScripts.architecture !== R7_ARCHITECTURE_SCRIPT) {
      throw new Error('R5 security R7 architecture delegation is invalid');
    }
    delete projectedScripts['architecture:r7'];
    projectedScripts.architecture = R6_ARCHITECTURE_SCRIPT;
  }
  if (!Object.prototype.hasOwnProperty.call(projectedScripts, 'architecture:r6')) {
    return packageJson;
  }
  if (projectedScripts['architecture:r6'] !== R6_STANDALONE_SCRIPT
      || projectedScripts.architecture !== R6_ARCHITECTURE_SCRIPT) {
    throw new Error('R5 security R6 architecture delegation is invalid');
  }
  delete projectedScripts['architecture:r6'];
  projectedScripts.architecture = R5_ARCHITECTURE_SCRIPT;
  return {
    ...packageJson,
    scripts: projectedScripts,
  };
}

function projectR6IdentityModuleForR5(source) {
  if (typeof source !== 'string') throw new Error('R5 auth stage drift detected');
  const normalized = source.replace(/\r\n/gu, '\n');
  const importCount = normalized.split(R6_IDENTITY_MODULE_IMPORT).length - 1;
  const registrationCount = normalized.split(R6_IDENTITY_MODULE_REGISTRATION).length - 1;
  if (importCount === 0 && registrationCount === 0) return normalized;
  if (importCount !== 1 || registrationCount !== 1) {
    throw new Error('R5 auth stage drift detected');
  }
  return normalized
    .replace(`${R6_IDENTITY_MODULE_IMPORT}\n`, '')
    .replace(R6_IDENTITY_MODULE_REGISTRATION, '');
}

function validateR5SecurityCheckpointScope(value) {
  const input = exactObject(value, ['changedPaths', 'packageJson', 'packageLock'], 'R5 security scope');
  const changedPaths = validatePathList(input.changedPaths, 'R5 security changed paths');
  const triggerPaths = new Set([
    'backend/package-lock.json',
    'backend/scripts/security/prisma-config-merge-security.cjs',
    'backend/test/prisma-config-merge-security.test.ts',
    'docs/superpowers/plans/2026-08-21-r5-prisma-config-merge-security-checkpoint.md',
    'docs/superpowers/specs/2026-08-21-r5-prisma-config-merge-security-checkpoint-design.md',
  ]);
  const active = changedPaths.some((relative) => triggerPaths.has(relative));
  if (!active) return Object.freeze({ active: false });
  for (const requiredPath of R5_SECURITY_CHECKPOINT_PATHS) {
    if (!changedPaths.includes(requiredPath)) {
      throw new Error('R5 security checkpoint path set is incomplete');
    }
  }
  for (const relative of changedPaths) {
    if ((relative.startsWith('backend/scripts/security/')
          && relative !== 'backend/scripts/security/prisma-config-merge-security.cjs')
        || (relative.startsWith('backend/test/prisma-config-merge-security')
          && relative !== 'backend/test/prisma-config-merge-security.test.ts')) {
      throw new Error('R5 security checkpoint contains an extra implementation path');
    }
  }
  const security = require('../security/prisma-config-merge-security.cjs');
  const packageJson = plainObject(input.packageJson, 'R5 security package');
  const scripts = plainObject(packageJson.scripts, 'R5 security package scripts');
  const r12bKeys = Object.keys(scripts)
    .filter((scriptName) => scriptName.startsWith('architecture:r12b'));
  const hasR12bAggregateIdentity = typeof scripts.architecture === 'string'
    && scripts.architecture.includes('architecture:r12b');
  const historicalPackageJson = r12bKeys.length > 0 || hasR12bAggregateIdentity
    ? security.projectR12BArchitectureScripts(packageJson)
    : packageJson;
  security.validatePackageGraph(
    projectR6ArchitectureScriptsForR5Security(historicalPackageJson),
    input.packageLock,
    {
      expectedPackageFingerprint: R5_SECURITY_PACKAGE_JSON_SHA256,
      expectedLockFingerprint: security.PINNED_PACKAGE_LOCK_SHA256,
    },
  );
  return Object.freeze({ active: true });
}

function isInside(parent, candidate) {
  const relative = path.relative(parent, candidate);
  return relative === '' || (!path.isAbsolute(relative) && relative !== '..'
    && !relative.startsWith(`..${path.sep}`));
}

function inspectExistingPath(repositoryRoot, relative, expected) {
  const root = (fs.realpathSync.native || fs.realpathSync)(repositoryRoot);
  const parts = relative.split('/');
  let cursor = repositoryRoot;
  for (let index = 0; index < parts.length; index += 1) {
    cursor = path.join(cursor, parts[index]);
    if (!fs.existsSync(cursor)) return { exists: false };
    const status = fs.lstatSync(cursor);
    if (status.isSymbolicLink()) throw new Error('R5 source contains a symbolic or junction reparse point');
    if (index < parts.length - 1 && !status.isDirectory()) {
      throw new Error('R5 source parent is not a directory');
    }
  }
  const status = fs.lstatSync(cursor);
  const real = (fs.realpathSync.native || fs.realpathSync)(cursor);
  if (!isInside(root, real)) throw new Error('R5 source escapes the repository');
  if (expected === 'file' && !status.isFile()) throw new Error('R5 source is not a plain file');
  if (expected === 'directory' && !status.isDirectory()) throw new Error('R5 root is not a plain directory');
  return { exists: true };
}

function normalizedFileHash(filePath) {
  return normalizedTextHash(fs.readFileSync(filePath, 'utf8'));
}

function normalizedTextHash(text) {
  if (typeof text !== 'string') throw new Error('R5 QA harness source is invalid');
  return crypto.createHash('sha256').update(text.replace(/\r\n/gu, '\n')).digest('hex');
}

function r12cPredecessorProjection(repositoryRoot) {
  const relative = 'backend/architecture/r12c-zero-cross-context-dependencies.json';
  if (!inspectExistingPath(repositoryRoot, relative, 'file').exists) return null;
  const r12c = require('./r12c-zero-cross-context-dependencies-scan.cjs');
  const manifest = r12c.validateR12cManifest(JSON.parse(fs.readFileSync(
    path.join(repositoryRoot, ...relative.split('/')),
    'utf8',
  )));
  return r12c.projectR12cWorkingTreeToPredecessor({ repositoryRoot, manifest });
}

function projectR7QaHarnessForR5(relativePath, text) {
  const pathHandoffs = new Map([
    [
      'backend/scripts/smoke/phase2-auth-lifecycle-concurrency-smoke.ts',
      [
        '../../src/modules/collaboration/internal/invite-access.service',
        '../../src/sharing/invite-access.service',
      ],
    ],
    [
      'backend/scripts/smoke/phase3-context-transition-smoke.ts',
      [
        '../../src/modules/collaboration/internal/permission.service',
        '../../src/sharing/permission.service',
      ],
    ],
  ]);
  const handoff = pathHandoffs.get(relativePath);
  return handoff ? text.replace(handoff[0], handoff[1]) : text;
}

function verifyR5QaHarnessCorrections(options) {
  const input = plainObject(options, 'R5 QA harness verifier options');
  const keys = Object.keys(input).sort();
  if (keys.some((key) => !['manifest', 'readBaseFile', 'readWorkingFile', 'repositoryRoot'].includes(key))
      || !keys.includes('manifest') || !keys.includes('repositoryRoot')) {
    throw new Error('R5 QA harness verifier options are invalid');
  }
  if (typeof input.repositoryRoot !== 'string' || !path.isAbsolute(input.repositoryRoot)) {
    throw new Error('R5 QA harness repository root must be absolute');
  }
  const manifest = validateR5Manifest(input.manifest);
  const readBaseFile = input.readBaseFile === undefined
    ? (relative) => execFileSync(
      'git',
      ['show', `${R5_BASE}:${relative}`],
      { cwd: input.repositoryRoot, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 },
    )
    : input.readBaseFile;
  if (typeof readBaseFile !== 'function') {
    throw new Error('R5 QA harness base reader is invalid');
  }
  if (input.readWorkingFile !== undefined && typeof input.readWorkingFile !== 'function') {
    throw new Error('R5 QA harness working reader is invalid');
  }
  const readWorkingFile = input.readWorkingFile
    || r12cPredecessorProjection(input.repositoryRoot)?.readWorkingFile;
  for (const correction of manifest.qaHarnessCorrections) {
    if (!manifest.allowedChangedPaths.includes(correction.path)) {
      throw new Error('R5 QA harness correction is outside the candidate scope');
    }
    const inspected = inspectExistingPath(input.repositoryRoot, correction.path, 'file');
    if (!inspected.exists) throw new Error('R5 QA harness correction is missing');
    const liveSource = readWorkingFile === undefined
      ? fs.readFileSync(path.join(input.repositoryRoot, ...correction.path.split('/')), 'utf8')
      : readWorkingFile(correction.path).toString('utf8');
    if (normalizedTextHash(readBaseFile(correction.path)) !== correction.baseSha256
        || normalizedTextHash(projectR7QaHarnessForR5(correction.path, liveSource))
          !== correction.approvedSha256) {
      throw new Error('R5 QA harness correction drift detected');
    }
  }
  return Object.freeze({ corrections: manifest.qaHarnessCorrections.length });
}

function validateR5AuthStage(repositoryRoot) {
  for (const [relative, expectedHash] of Object.entries(AUTH_STAGE_HASHES)) {
    const inspected = inspectExistingPath(repositoryRoot, relative, 'file');
    if (!inspected.exists) throw new Error('R5 auth stage drift detected');
    const absolute = path.join(repositoryRoot, ...relative.split('/'));
    const source = fs.readFileSync(absolute, 'utf8');
    const projected = relative === 'backend/src/modules/identity/identity.module.ts'
      ? projectR6IdentityModuleForR5(source)
      : source;
    if (normalizedTextHash(projected) !== expectedHash) {
      throw new Error('R5 auth stage drift detected');
    }
  }
}

function validateR5ProfileStage(repositoryRoot, r12aManifestValue = undefined, readWorkingFile = undefined) {
  if (typeof repositoryRoot !== 'string' || !path.isAbsolute(repositoryRoot)) {
    throw new Error('R5 profile repository root must be absolute');
  }
  const predecessorRead = readWorkingFile || r12cPredecessorProjection(repositoryRoot)?.readWorkingFile;
  for (const [relative, expectedHash] of Object.entries(PROFILE_STAGE_HASHES)) {
    const inspected = inspectExistingPath(repositoryRoot, relative, 'file');
    if (!inspected.exists) throw new Error('R5 profile stage drift detected');
    const absolute = path.join(repositoryRoot, ...relative.split('/'));
    if (readWorkingFile !== undefined && typeof readWorkingFile !== 'function') {
      throw new Error('R5 profile working reader is invalid');
    }
    let source = predecessorRead === undefined
      ? fs.readFileSync(absolute, 'utf8')
      : predecessorRead(relative).toString('utf8');
    if (relative === 'backend/src/modules/identity/internal/profile/users.service.ts') {
      const r12aPath = path.join(
        repositoryRoot,
        'backend',
        'architecture',
        'r12a-backoffice-catalog-public-contracts.json',
      );
      const r12aManifest = r12aManifestValue === undefined
        ? validateR12aManifest(JSON.parse(fs.readFileSync(r12aPath, 'utf8')))
        : validateR12aManifest(r12aManifestValue);
      if (r12aManifest.stage === 'strict') {
        const file = ts.createSourceFile(relative, source, ts.ScriptTarget.Latest, true, ts.ScriptKind.TS);
        const imports = file.statements.filter(ts.isImportDeclaration);
        const liveImport = '../../../marketplace/public/provider-review-rating';
        const historicalImport = '../../../../marketplace/provider-review-rating';
        if (imports.filter((item) => item.moduleSpecifier.text === liveImport).length !== 1
          || imports.some((item) => item.moduleSpecifier.text === historicalImport)) {
          throw new Error('R5 profile stage drift detected');
        }
        source = normalizeR12aIdentityProviderRatingSource(source, r12aManifest);
      }
    }
    if (normalizedTextHash(source) !== expectedHash) {
      throw new Error('R5 profile stage drift detected');
    }
  }
}

function validateR5RetiredRoots(repositoryRoot, manifestValue) {
  const manifest = validateR5Manifest(manifestValue);
  for (const rootName of manifest.retiredRoots) {
    const legacyRoot = inspectExistingPath(
      repositoryRoot,
      `backend/src/${rootName}`,
      'directory',
    );
    if (legacyRoot.exists) throw new Error('R5 retired identity root remains');
  }
}

function moveStage(move) {
  if (move.to.includes('/public/')) return 'task-2';
  if (move.to.includes('/internal/auth/') || move.to.includes('/api/auth')) return 'task-3';
  return 'task-4';
}

function mapOwnershipRecordsForR5(records, manifestValue) {
  const manifest = validateR5Manifest(manifestValue);
  const currentStage = STAGES.indexOf(manifest.stage);
  if (!Array.isArray(records)) throw new Error('R5 ownership records must be an array');
  const completedMoves = new Map(manifest.moves
    .filter((move) => currentStage >= STAGES.indexOf(moveStage(move)))
    .map((move) => [move.from, move.to]));
  const mapped = records.map((record, index) => {
    assertDeepPlainData(record, `R5 ownership records[${index}]`);
    const item = plainObject(record, `R5 ownership records[${index}]`);
    if (typeof item.file !== 'string' || typeof item.key !== 'string'
        || !item.key.startsWith(`${item.file}|`)) {
      throw new Error('R5 ownership record identity is invalid');
    }
    const r7Projection = [
      R7_HISTORY_OWNERSHIP_PROJECTION,
      ...R7_SHARING_OWNERSHIP_PROJECTIONS,
    ].find((projection) => projection.from === item.file);
    const target = completedMoves.get(item.file) || r7Projection?.to || null;
    if (!target) return { ...item };
    return {
      ...item,
      file: target,
      key: `${target}${item.key.slice(item.file.length)}`,
    };
  }).sort((left, right) => (left.key < right.key ? -1 : left.key > right.key ? 1 : 0));
  if (new Set(mapped.map((record) => record.key)).size !== mapped.length) {
    throw new Error('R5 ownership relocation collides');
  }
  return mapped;
}

function applyR12aOwnershipProjection(ownership, manifestValue) {
  return expectedR12aOwnershipBaseline(ownership, validateR12aManifest(manifestValue));
}

function normalizeR12aIdentityProviderRatingSource(source, manifestValue) {
  const manifest = validateR12aManifest(manifestValue);
  return normalizeR12aIdentityProviderRatingImport(source, manifest)
    .replace('../../../marketplace/public/provider-review-rating', '../../../../marketplace/provider-review-rating');
}

function dependencyRecordKey(record) {
  return `${record.rule.name}|${record.from}|${record.to}`;
}

function validateDependencyRecords(value, label) {
  const records = denseArray(value, label).map((item, index) => {
    const record = exactObject(item, [
      'type', 'from', 'to', 'unresolvedTo', 'dependencyTypes', 'rule',
    ], `${label}[${index}]`);
    if (record.type !== 'dependency') throw new Error(`${label} has an invalid type`);
    for (const key of ['from', 'to', 'unresolvedTo']) {
      if (typeof record[key] !== 'string' || record[key].length === 0
          || record[key].length > MAX_TEXT_LENGTH) {
        throw new Error(`${label} has an invalid path`);
      }
    }
    const dependencyTypes = denseArray(
      record.dependencyTypes,
      `${label}[${index}] dependency types`,
    );
    if (dependencyTypes.length === 0 || dependencyTypes.some((type) => (
      typeof type !== 'string' || type.length === 0 || type.length > 128
    )) || new Set(dependencyTypes).size !== dependencyTypes.length) {
      throw new Error(`${label} has invalid dependency types`);
    }
    const rule = exactObject(record.rule, ['severity', 'name'], `${label}[${index}] rule`);
    if (rule.severity !== 'error' || typeof rule.name !== 'string'
        || !/^context-[a-z-]+-cross-context$/u.test(rule.name)) {
      throw new Error(`${label} has an invalid rule`);
    }
    return {
      type: record.type,
      from: record.from,
      to: record.to,
      unresolvedTo: record.unresolvedTo,
      dependencyTypes: [...dependencyTypes],
      rule: { severity: rule.severity, name: rule.name },
    };
  });
  const keys = records.map(dependencyRecordKey);
  if (new Set(keys).size !== keys.length) throw new Error(`${label} contains a collision`);
  return records;
}

function verifyR7DependencyHandoff(options) {
  const input = exactObject(options, [
    'historicalDependency', 'liveDependency',
  ], 'R7 dependency handoff input');
  const historical = validateDependencyRecords(
    input.historicalDependency,
    'R7 historical dependency',
  );
  if (historical.length !== 31 || R7_RETIRED_DEPENDENCY_KEYS.length !== 9
      || hash(historical) !== R7_HISTORICAL_DEPENDENCY_HASH) {
    throw new Error('R7 historical dependency identity is invalid');
  }
  const live = validateDependencyRecords(input.liveDependency, 'R7 live dependency');
  const retired = new Set(R7_RETIRED_DEPENDENCY_KEYS);
  const expectedLive = historical.filter((record) => !retired.has(dependencyRecordKey(record)));
  if (live.length !== 22 || JSON.stringify(live) !== JSON.stringify(expectedLive)) {
    throw new Error('R7 live dependency projection is invalid');
  }
  return Object.freeze({
    historicalDependencyRecords: historical.length,
    liveDependencyRecords: live.length,
    retiredDependencyRecords: historical.length - live.length,
  });
}

function verifyR7HistoryOwnershipHandoff(options) {
  const input = exactObject(options, [
    'historicalOwnership', 'liveOwnership',
  ], 'R7 history ownership handoff input');
  const historical = validateOwnershipBaseline(
    input.historicalOwnership,
    'R7 historical ownership',
  );
  const historicalOccurrences = historical.violations.reduce(
    (sum, record) => sum + record.count,
    0,
  );
  if (historical.violations.length !== 385 || historicalOccurrences !== 781
      || hash(historical) !== R7_HISTORICAL_OWNERSHIP_HASH) {
    throw new Error('R7 historical ownership identity is invalid');
  }
  const live = validateOwnershipBaseline(input.liveOwnership, 'R7 live ownership');
  const expected = {
    ...historical,
    violations: historical.violations.map((record) => {
      if (record.file !== R7_HISTORY_OWNERSHIP_PROJECTION.from) return { ...record };
      return {
        ...record,
        key: String(record.key).replace(
          R7_HISTORY_OWNERSHIP_PROJECTION.from,
          R7_HISTORY_OWNERSHIP_PROJECTION.to,
        ),
        file: R7_HISTORY_OWNERSHIP_PROJECTION.to,
      };
    }),
  };
  const projected = expected.violations.filter(
    (record) => record.file === R7_HISTORY_OWNERSHIP_PROJECTION.to,
  );
  const projectedOccurrences = projected.reduce((sum, record) => sum + record.count, 0);
  const liveOccurrences = live.violations.reduce((sum, record) => sum + record.count, 0);
  if (projected.length !== R7_HISTORY_OWNERSHIP_PROJECTION.records
      || projectedOccurrences !== R7_HISTORY_OWNERSHIP_PROJECTION.occurrences
      || live.violations.length !== 385 || liveOccurrences !== 781
      || JSON.stringify(live) !== JSON.stringify(expected)) {
    throw new Error('R7 live ownership projection is invalid');
  }
  return Object.freeze({
    historicalOwnershipRecords: historical.violations.length,
    historicalOwnershipOccurrences: historicalOccurrences,
    liveOwnershipRecords: live.violations.length,
    liveOwnershipOccurrences: liveOccurrences,
    projectedRecords: projected.length,
    projectedOccurrences,
  });
}

function verifyR7SharingOwnershipHandoff(options) {
  const input = exactObject(options, [
    'historicalOwnership', 'liveOwnership',
  ], 'R7 Sharing ownership handoff input');
  const historical = validateOwnershipBaseline(
    input.historicalOwnership,
    'R7 historical ownership',
  );
  const historicalOccurrences = historical.violations.reduce(
    (sum, record) => sum + record.count,
    0,
  );
  if (historical.violations.length !== 385 || historicalOccurrences !== 781
      || hash(historical) !== R7_HISTORICAL_OWNERSHIP_HASH) {
    throw new Error('R7 historical ownership identity is invalid');
  }
  const live = validateOwnershipBaseline(input.liveOwnership, 'R7 live ownership');
  const projections = [
    R7_HISTORY_OWNERSHIP_PROJECTION,
    ...R7_SHARING_OWNERSHIP_PROJECTIONS,
  ];
  const expected = {
    ...historical,
    violations: historical.violations.map((record) => {
      const projection = projections.find((item) => item.from === record.file);
      if (!projection) return { ...record };
      return {
        ...record,
        key: String(record.key).replace(projection.from, projection.to),
        file: projection.to,
      };
    }).sort((left, right) => left.key.localeCompare(right.key)),
  };
  const sharingTargets = new Set(R7_SHARING_OWNERSHIP_PROJECTIONS.map((item) => item.to));
  const projected = expected.violations.filter((record) => sharingTargets.has(record.file));
  const projectedOccurrences = projected.reduce((sum, record) => sum + record.count, 0);
  const liveOccurrences = live.violations.reduce((sum, record) => sum + record.count, 0);
  if (projected.length !== 23 || projectedOccurrences !== 73
      || live.violations.length !== 385 || liveOccurrences !== 781
      || JSON.stringify(live) !== JSON.stringify(expected)) {
    throw new Error('R7 live ownership projection is invalid');
  }
  return Object.freeze({
    historicalOwnershipRecords: historical.violations.length,
    historicalOwnershipOccurrences: historicalOccurrences,
    liveOwnershipRecords: live.violations.length,
    liveOwnershipOccurrences: liveOccurrences,
    projectedRecords: projected.length,
    projectedOccurrences,
  });
}

function expectedR5DependencyRecords(records, manifestValue) {
  const manifest = validateR5Manifest(manifestValue);
  const base = validateDependencyRecords(records, 'R5 base dependency baseline');
  if (base.length !== 89 || hash(base) !== R5_BASE_DEPENDENCY_HASH) {
    throw new Error('R5 base dependency baseline identity is invalid');
  }
  const moves = new Map(manifest.moves.map((move) => [
    move.from.replace(/^backend\//u, ''),
    move.to.replace(/^backend\//u, ''),
  ]));
  const mapped = base.map((record) => ({
    ...record,
    from: moves.get(record.from) || record.from,
    to: moves.get(record.to) || record.to,
  }));
  const expectedKeys = new Set(REMAINING_DEPENDENCY_KEYS);
  const remaining = mapped.filter((record) => expectedKeys.has(dependencyRecordKey(record)));
  if (remaining.length !== manifest.expectedBaselines.dependencyRecords
      || JSON.stringify(remaining.map(dependencyRecordKey))
        !== JSON.stringify(REMAINING_DEPENDENCY_KEYS)) {
    throw new Error('R5 dependency retirement ledger is invalid');
  }
  return remaining;
}

function validateOwnershipBaseline(value, label) {
  const baseline = exactObject(
    value,
    ['schemaVersion', 'sourceRevision', 'violations'],
    label,
  );
  if (baseline.schemaVersion !== 1 || typeof baseline.sourceRevision !== 'string'
      || !/^[0-9a-f]{40}$/u.test(baseline.sourceRevision)) {
    throw new Error(`${label} identity is invalid`);
  }
  const violations = denseArray(baseline.violations, `${label} violations`).map(
    (record, index) => {
      assertDeepPlainData(record, `${label} violations[${index}]`);
      return { ...plainObject(record, `${label} violations[${index}]`) };
    },
  );
  return {
    schemaVersion: baseline.schemaVersion,
    sourceRevision: baseline.sourceRevision,
    violations,
  };
}

function verifyR5Baselines(options) {
  const input = plainObject(options, 'R5 baseline verifier input');
  const allowed = new Set([
    'baseDependency', 'candidateDependency', 'baseOwnership',
    'candidateOwnership', 'manifest', 'r12aManifest', 'repositoryRoot', 'readImmutableFile',
  ]);
  if (Object.keys(input).some((key) => !allowed.has(key))) {
    throw new Error('R5 baseline verifier input keys are invalid');
  }
  const manifest = validateR5Manifest(input.manifest);
  const r12aManifest = input.r12aManifest === undefined
    ? null : validateR12aManifest(input.r12aManifest);
  if (input.repositoryRoot !== undefined
      && (typeof input.repositoryRoot !== 'string' || !path.isAbsolute(input.repositoryRoot))) {
    throw new Error('R5 baseline repository root is invalid');
  }
  if (input.readImmutableFile !== undefined && typeof input.readImmutableFile !== 'function') {
    throw new Error('R5 baseline immutable reader is invalid');
  }
  const baseDependency = validateDependencyRecords(
    input.baseDependency,
    'R5 base dependency baseline',
  );
  if (hash(baseDependency) !== R5_BASE_DEPENDENCY_HASH) {
    throw new Error('R5 base dependency baseline identity is invalid');
  }
  const expectedDependency = expectedR5DependencyRecords(baseDependency, manifest);
  const candidateDependency = validateDependencyRecords(
    input.candidateDependency,
    'R5 dependency candidate',
  );
  if (!r12aManifest && JSON.stringify(candidateDependency) !== JSON.stringify(expectedDependency)) {
    throw new Error('R5 dependency baseline drift detected');
  }

  const baseOwnership = validateOwnershipBaseline(
    input.baseOwnership,
    'R5 base ownership baseline',
  );
  if (hash(baseOwnership) !== R5_BASE_OWNERSHIP_HASH) {
    throw new Error('R5 base ownership baseline identity is invalid');
  }
  const candidateOwnership = validateOwnershipBaseline(
    input.candidateOwnership,
    'R5 ownership candidate',
  );
  let expectedOwnership = {
    ...baseOwnership,
    violations: mapOwnershipRecordsForR5(baseOwnership.violations, manifest),
  };
  if (r12aManifest) {
    const historicalR7Live22 = expectedDependency.filter(
      (record) => !R7_RETIRED_DEPENDENCY_KEYS.includes(dependencyRecordKey(record)),
    );
    if (historicalR7Live22.length !== 22) throw new Error('R5 R7 dependency handoff is invalid');
    const expectedR12aDependency = input.repositoryRoot === undefined
      ? expectedR12aDependencyRecords(historicalR7Live22, r12aManifest)
      : expectedR12aSuccessorDependencyRecords({
        repositoryRoot: input.repositoryRoot,
        r12aEntryRecords: historicalR7Live22,
        r12aManifest,
        readImmutableFile: input.readImmutableFile,
      });
    if (JSON.stringify(candidateDependency) !== JSON.stringify(expectedR12aDependency)) {
      throw new Error('R5 R12A dependency baseline drift detected');
    }
    expectedOwnership = applyR12aOwnershipProjection(expectedOwnership, r12aManifest);
  }
  if (JSON.stringify(candidateOwnership) !== JSON.stringify(expectedOwnership)) {
    throw new Error('R5 ownership baseline drift detected');
  }
  const ownershipOccurrences = candidateOwnership.violations.reduce((total, record) => {
    if (!Number.isSafeInteger(record.count) || record.count < 1) {
      throw new Error('R5 ownership baseline drift detected');
    }
    return total + record.count;
  }, 0);
  if (candidateOwnership.violations.length !== manifest.expectedBaselines.ownershipRecords
      || ownershipOccurrences !== manifest.expectedBaselines.ownershipOccurrences) {
    throw new Error('R5 ownership baseline drift detected');
  }
  return Object.freeze({
    dependencyRecords: candidateDependency.length,
    retiredDependencyRecords: baseDependency.length - candidateDependency.length,
    ownershipRecords: candidateOwnership.violations.length,
    ownershipOccurrences,
  });
}

function exportedDeclarations(filePath) {
  const sourceFile = ts.createSourceFile(
    filePath,
    fs.readFileSync(filePath, 'utf8'),
    ts.ScriptTarget.Latest,
    true,
  );
  const declarations = [];
  const isExported = (node) => (ts.getCombinedModifierFlags(node) & ts.ModifierFlags.Export) !== 0;
  for (const statement of sourceFile.statements) {
    if (!isExported(statement)) continue;
    if (ts.isClassDeclaration(statement) && statement.name) {
      declarations.push(`class:${statement.name.text}`);
    } else if (ts.isFunctionDeclaration(statement) && statement.name) {
      declarations.push(`function:${statement.name.text}`);
    } else if (ts.isInterfaceDeclaration(statement)) {
      declarations.push(`interface:${statement.name.text}`);
    } else if (ts.isTypeAliasDeclaration(statement)) {
      declarations.push(`type:${statement.name.text}`);
    } else if (ts.isVariableStatement(statement)) {
      for (const declaration of statement.declarationList.declarations) {
        if (ts.isIdentifier(declaration.name)) declarations.push(`const:${declaration.name.text}`);
      }
    }
  }
  return declarations.sort();
}

function walkTypeScriptFiles(root) {
  if (!fs.existsSync(root)) return [];
  const files = [];
  for (const entry of fs.readdirSync(root, { withFileTypes: true })) {
    const target = path.join(root, entry.name);
    if (entry.isDirectory()) files.push(...walkTypeScriptFiles(target));
    else if (/\.(?:cts|mts|ts|tsx)$/u.test(entry.name)) files.push(target);
  }
  return files;
}

function isIdentityOwnerSource(backendRoot, filePath) {
  const relative = path.relative(path.join(backendRoot, 'src'), filePath).split(path.sep);
  return ['auth', 'contexts', 'me', 'users'].includes(relative[0])
    || (relative[0] === 'modules' && relative[1] === 'identity');
}

function publicRuntimeConsumers(repositoryRoot, contractPaths) {
  const backendRoot = path.join(repositoryRoot, 'backend');
  const configPath = path.join(backendRoot, 'tsconfig.json');
  if (!fs.existsSync(configPath)) throw new Error('R5 public runtime consumer inventory is unavailable');
  const config = ts.readConfigFile(configPath, ts.sys.readFile);
  if (config.error) throw new Error('R5 public runtime consumer inventory is unavailable');
  const options = ts.parseJsonConfigFileContent(config.config, ts.sys, backendRoot).options;
  const normalizedContracts = new Map(
    contractPaths.map((entry) => [path.normalize(entry), 0]),
  );
  for (const filePath of walkTypeScriptFiles(path.join(backendRoot, 'src'))) {
    if (isIdentityOwnerSource(backendRoot, filePath)) continue;
    const sourceFile = ts.createSourceFile(
      filePath,
      fs.readFileSync(filePath, 'utf8'),
      ts.ScriptTarget.Latest,
      true,
    );
    for (const statement of sourceFile.statements) {
      if ((!ts.isImportDeclaration(statement) && !ts.isExportDeclaration(statement))
          || !statement.moduleSpecifier || !ts.isStringLiteral(statement.moduleSpecifier)) continue;
      const resolved = ts.resolveModuleName(
        statement.moduleSpecifier.text,
        filePath,
        options,
        ts.sys,
      ).resolvedModule;
      if (!resolved) continue;
      const key = path.normalize(resolved.resolvedFileName);
      if (normalizedContracts.has(key)) {
        normalizedContracts.set(key, normalizedContracts.get(key) + 1);
      }
    }
  }
  return normalizedContracts;
}

function validatePublicRuntimeSurface(repositoryRoot, manifest) {
  const stageIndex = STAGES.indexOf(manifest.stage);
  const currentPaths = manifest.publicRuntimeContracts.map((contract) => {
    const moved = stageIndex >= STAGES.indexOf('task-2');
    const relative = moved ? contract.target : contract.source;
    const absolute = path.join(repositoryRoot, ...relative.split('/'));
    if (JSON.stringify(exportedDeclarations(absolute)) !== JSON.stringify(contract.declarations)) {
      throw new Error('R5 public runtime declaration drift detected');
    }
    return absolute;
  });
  const consumers = publicRuntimeConsumers(repositoryRoot, currentPaths);
  if ([...consumers.values()].some((count) => count === 0)) {
    throw new Error('R5 public runtime consumer surface is hollow');
  }
}

function scanR5Identity(options) {
  const input = plainObject(options, 'R5 scan options');
  if (typeof input.repositoryRoot !== 'string' || !path.isAbsolute(input.repositoryRoot)) {
    throw new Error('R5 repository root must be absolute');
  }
  const manifest = validateR5Manifest(input.manifest);
  const r12aManifest = input.r12aManifest === undefined
    ? null : validateR12aManifest(input.r12aManifest);
  const currentStage = STAGES.indexOf(manifest.stage);
  const r12cProjection = r12cPredecessorProjection(input.repositoryRoot);
  for (const move of manifest.moves) {
    const moved = currentStage >= STAGES.indexOf(moveStage(move));
    const source = inspectExistingPath(input.repositoryRoot, move.from, 'file');
    const target = inspectExistingPath(input.repositoryRoot, move.to, 'file');
    if (moved && (source.exists || !target.exists)) {
      throw new Error('R5 move stage does not match the filesystem');
    }
    if (!moved && (!source.exists || target.exists)) {
      throw new Error('R5 inventory does not match the filesystem');
    }
  }
  validatePublicRuntimeSurface(input.repositoryRoot, manifest);
  if (currentStage >= STAGES.indexOf('task-3')) {
    validateR5AuthStage(input.repositoryRoot);
  }
  if (manifest.stage === 'strict') {
    validateR5ProfileStage(
      input.repositoryRoot,
      r12aManifest || undefined,
      r12cProjection?.readWorkingFile,
    );
    validateR5RetiredRoots(input.repositoryRoot, manifest);
    verifyR5QaHarnessCorrections({
      repositoryRoot: input.repositoryRoot,
      manifest,
      readWorkingFile: r12cProjection?.readWorkingFile,
    });
  }
  return Object.freeze({ ok: true, stage: manifest.stage, moves: manifest.moves.length });
}

function fileIdentity(status) {
  return Object.freeze({
    dev: status.dev,
    ino: status.ino,
    size: status.size,
    mtimeMs: status.mtimeMs,
    ctimeMs: status.ctimeMs,
  });
}

function sameFileIdentity(left, right) {
  return left.dev === right.dev && left.ino === right.ino && left.size === right.size
    && left.mtimeMs === right.mtimeMs && left.ctimeMs === right.ctimeMs;
}

function readTempCandidateJson(candidatePath) {
  if (typeof candidatePath !== 'string' || !path.isAbsolute(candidatePath)) {
    throw new Error('R5 candidate path is invalid');
  }
  const tempRoot = (fs.realpathSync.native || fs.realpathSync)(os.tmpdir());
  const resolved = path.resolve(candidatePath);
  const relative = path.relative(tempRoot, resolved);
  if (!relative || relative.startsWith(`..${path.sep}`) || relative === '..'
      || path.isAbsolute(relative)) {
    throw new Error('R5 candidate path is outside OS temp');
  }
  let cursor = tempRoot;
  for (const part of relative.split(path.sep)) {
    cursor = path.join(cursor, part);
    const status = fs.lstatSync(cursor);
    if (status.isSymbolicLink()) throw new Error('R5 candidate path contains a reparse point');
  }
  const beforePath = fs.lstatSync(resolved);
  if (!beforePath.isFile()) throw new Error('R5 candidate is not a plain file');
  const beforeReal = (fs.realpathSync.native || fs.realpathSync)(resolved);
  if (!isInside(tempRoot, beforeReal)) throw new Error('R5 candidate escapes OS temp');
  const flags = fs.constants.O_RDONLY | (fs.constants.O_NOFOLLOW || 0);
  const descriptor = fs.openSync(resolved, flags);
  try {
    const beforeDescriptor = fs.fstatSync(descriptor);
    if (!beforeDescriptor.isFile()
        || !sameFileIdentity(fileIdentity(beforePath), fileIdentity(beforeDescriptor))) {
      throw new Error('R5 candidate identity changed');
    }
    const textValue = fs.readFileSync(descriptor, 'utf8');
    const afterDescriptor = fs.fstatSync(descriptor);
    const afterPath = fs.lstatSync(resolved);
    const afterReal = (fs.realpathSync.native || fs.realpathSync)(resolved);
    if (afterReal !== beforeReal
        || !sameFileIdentity(fileIdentity(beforeDescriptor), fileIdentity(afterDescriptor))
        || !sameFileIdentity(fileIdentity(afterDescriptor), fileIdentity(afterPath))) {
      throw new Error('R5 candidate identity changed');
    }
    return Object.freeze({
      value: JSON.parse(textValue),
      realPath: beforeReal,
      identity: fileIdentity(afterDescriptor),
    });
  } finally {
    fs.closeSync(descriptor);
  }
}

function readBaseJson(repositoryRoot, relativePath) {
  return JSON.parse(execFileSync(
    'git',
    ['show', `${R5_BASE}:${relativePath}`],
    { cwd: repositoryRoot, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 },
  ));
}

function liveChangedPaths(repositoryRoot, executeGit = execFileSync) {
  const options = {
    cwd: repositoryRoot,
    encoding: 'utf8',
    maxBuffer: 16 * 1024 * 1024,
    stdio: ['ignore', 'pipe', 'pipe'],
  };
  const tracked = executeGit(
    'git',
    ['diff', '--no-renames', '--name-only', R5_BASE, '--'],
    options,
  ).split(/\r?\n/u).filter(Boolean);
  const untracked = executeGit(
    'git',
    ['ls-files', '--others', '--exclude-standard'],
    options,
  ).split(/\r?\n/u).filter(Boolean);
  return [...new Set([...tracked, ...untracked])].sort();
}

function readR12aManifest(repositoryRoot) {
  const manifestPath = path.join(
    repositoryRoot,
    'backend',
    'architecture',
    'r12a-backoffice-catalog-public-contracts.json',
  );
  return validateR12aManifest(JSON.parse(fs.readFileSync(manifestPath, 'utf8')));
}

function runCli(dependencies = {}) {
  const argv = dependencies.argv || process.argv.slice(2);
  const stdout = dependencies.stdout || ((message) => process.stdout.write(`${message}\n`));
  const stderr = dependencies.stderr || ((message) => process.stderr.write(`${message}\n`));
  try {
    const baselineMode = argv.length === 5
      && argv[0] === '--check'
      && argv[1] === '--dependency-candidate'
      && argv[3] === '--ownership-candidate';
    if (!((argv.length === 1 && argv[0] === '--check') || baselineMode)) {
      throw new Error('invalid arguments');
    }
    const repositoryRoot = path.resolve(__dirname, '../../..');
    const manifest = JSON.parse(fs.readFileSync(
      path.join(repositoryRoot, ...MANIFEST_PATH.split('/')),
      'utf8',
    ));
    const r12aManifest = dependencies.r12aManifest === undefined
      ? readR12aManifest(repositoryRoot)
      : validateR12aManifest(dependencies.r12aManifest);
    validateR5SecurityCheckpointScope({
      changedPaths: liveChangedPaths(repositoryRoot),
      packageJson: JSON.parse(fs.readFileSync(path.join(repositoryRoot, 'backend', 'package.json'), 'utf8')),
      packageLock: JSON.parse(fs.readFileSync(path.join(repositoryRoot, 'backend', 'package-lock.json'), 'utf8')),
    });
    const result = scanR5Identity({ repositoryRoot, manifest, r12aManifest });
    if (baselineMode) {
      const dependencyCandidate = readTempCandidateJson(argv[2]);
      const ownershipCandidate = readTempCandidateJson(argv[4]);
      if (dependencyCandidate.realPath === ownershipCandidate.realPath
          || (dependencyCandidate.identity.dev === ownershipCandidate.identity.dev
            && dependencyCandidate.identity.ino === ownershipCandidate.identity.ino)) {
        throw new Error('R5 candidate paths alias');
      }
      const readBase = dependencies.readBaseJson || ((relative) => (
        readBaseJson(repositoryRoot, relative)
      ));
      const baseline = verifyR5Baselines({
        baseDependency: readBase('backend/.dependency-cruiser-known-violations.json'),
        candidateDependency: dependencyCandidate.value,
        baseOwnership: readBase('backend/architecture/ownership-baseline.json'),
        candidateOwnership: ownershipCandidate.value,
        manifest,
        r12aManifest,
        repositoryRoot,
        readImmutableFile: dependencies.readImmutableFile,
      });
      stdout(`PASS - R5 baselines: dependency=${baseline.dependencyRecords}, retired=${baseline.retiredDependencyRecords}, ownership=${baseline.ownershipRecords}/${baseline.ownershipOccurrences}`);
    } else {
      stdout(`PASS - R5 Identity relocation: stage=${result.stage}, moves=${result.moves}`);
    }
    return 0;
  } catch {
    stderr('ERROR - R5 Identity relocation validation failed');
    return 2;
  }
}

module.exports = {
  MANIFEST_PATH,
  R5_BASE,
  STATIC_HASHES,
  STAGES,
  validateR5Manifest,
  scanR5Identity,
  validateR5AuthStage,
  validateR5ProfileStage,
  validateR5RetiredRoots,
  validateR5SecurityCheckpointScope,
  projectR6ArchitectureScriptsForR5Security,
  verifyR5QaHarnessCorrections,
  mapOwnershipRecordsForR5,
  applyR12aOwnershipProjection,
  normalizeR12aIdentityProviderRatingSource,
  expectedR5DependencyRecords,
  verifyR5Baselines,
  verifyR7DependencyHandoff,
  verifyR7HistoryOwnershipHandoff,
  verifyR7SharingOwnershipHandoff,
  liveChangedPaths,
  runCli,
};

if (require.main === module) process.exitCode = runCli();

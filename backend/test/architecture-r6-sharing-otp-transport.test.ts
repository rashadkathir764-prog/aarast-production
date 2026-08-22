import assert from 'node:assert/strict';
import {
  copyFileSync,
  existsSync,
  mkdirSync,
  mkdtempSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { afterEach, test } from 'node:test';
import {
  MODULE_METADATA,
  SELF_DECLARED_DEPS_METADATA,
} from '@nestjs/common/constants';
import { NestFactory } from '@nestjs/core';
import ts from 'typescript';

const backendRoot = path.resolve(__dirname, '..');
const repositoryRoot = path.resolve(backendRoot, '..');
const manifestPath = path.join(
  backendRoot,
  'architecture',
  'r6-sharing-otp-transport.json',
);
const scannerPath = path.join(
  backendRoot,
  'scripts',
  'architecture',
  'r6-sharing-otp-transport-scan.cjs',
);
const r6Base = 'ce0c0d19824bff79d91417e2fe4617914c6bcd70';

const expectedAllowedChangedPaths = [
  'ARCHITECTURE.md',
  'backend/architecture/r3-context-boundaries.json',
  'backend/architecture/r6-sharing-otp-transport.json',
  'backend/package.json',
  'backend/scripts/architecture/r3-context-scan.cjs',
  'backend/scripts/architecture/r3-scope.cjs',
  'backend/scripts/architecture/r5-identity-scan.cjs',
  'backend/scripts/architecture/r6-sharing-otp-transport-scan.cjs',
  'backend/scripts/security/prisma-config-merge-security.cjs',
  'backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts',
  'backend/src/modules/identity/identity.module.ts',
  'backend/src/modules/identity/internal/identity-transient-delivery.adapter.ts',
  'backend/src/modules/identity/internal/identity-transient-delivery.internal.module.ts',
  'backend/src/modules/identity/public/identity-transient-delivery-public.module.ts',
  'backend/src/modules/identity/public/identity-transient-delivery.port.ts',
  'backend/src/sharing/invitation-delivery.service.ts',
  'backend/test/architecture-ownership.test.ts',
  'backend/test/architecture-r1-baseline-relocation.test.ts',
  'backend/test/architecture-r1-layout.test.ts',
  'backend/test/architecture-r3-contexts.test.ts',
  'backend/test/architecture-r3-scope.test.ts',
  'backend/test/architecture-r4-planning-finance-boundary.test.ts',
  'backend/test/architecture-r5-identity-relocation.test.ts',
  'backend/test/architecture-r6-sharing-otp-transport.test.ts',
  'backend/test/invite-delivery.test.ts',
  'backend/test/prisma-dmmf-fingerprint.test.ts',
  'docs/README.md',
  'docs/SCRIPTS.md',
  'docs/project/DECISIONS.md',
  'docs/project/EXECUTION_PLAN.md',
  'docs/project/STATUS.md',
  'docs/qa/README.md',
  'docs/superpowers/plans/2026-08-22-modular-monolith-r6-sharing-otp-transport-port-completion.md',
  'docs/superpowers/plans/2026-08-22-modular-monolith-r6-sharing-otp-transport-port.md',
  'docs/superpowers/specs/2026-08-22-modular-monolith-r6-sharing-otp-transport-port-completion.md',
  'docs/superpowers/specs/2026-08-22-modular-monolith-r6-sharing-otp-transport-port-design.md',
];

type R6Manifest = {
  schemaVersion: number;
  baseRevision: string;
  stage: string;
  currentConcreteDependency: {
    consumer: string;
    transport: string;
    declarations: string[];
  };
  targetBoundary: {
    adapterPath: string;
    collaborationModulePath: string;
    consumerPath: string;
    identityModulePath: string;
    implementationToken: string;
    inputType: string;
    internalModulePath: string;
    portInterface: string;
    publicErrors: string[];
    publicModulePath: string;
    publicPortPath: string;
    token: string;
  };
  protectedFiles: Array<{ path: string; sha256: string }>;
  expectedBaselines: {
    dependencyRecords: number;
    ownershipRecords: number;
    ownershipOccurrences: number;
    concreteTransportImports: Record<string, number>;
  };
  allowedChangedPaths: string[];
};

type R6Scanner = {
  R6_BASE: string;
  STAGES: readonly string[];
  validateR6Manifest(value: unknown): R6Manifest;
  scanR6SharingOtpTransport(options: {
    repositoryRoot: string;
    manifest: unknown;
    readBaseFile?: (relativePath: string) => Buffer;
  }): {
    ok: boolean;
    stage: string;
    concreteImports: number;
    protectedFiles: number;
  };
  runCli(dependencies?: Record<string, unknown>): number;
};

const temporaryRoots: string[] = [];

function scanner(): R6Scanner {
  return require(scannerPath) as R6Scanner;
}

function readManifest(): R6Manifest {
  return JSON.parse(readFileSync(manifestPath, 'utf8')) as R6Manifest;
}

function copyProtectedFixture(root: string): void {
  for (const relativePath of [
    'backend/.dependency-cruiser-known-violations.json',
    'backend/architecture/ownership-baseline.json',
    'backend/src/platform/otp-transport/openwa-otp.channel.ts',
    'backend/src/platform/otp-transport/openwa-otp-config.ts',
    'backend/src/platform/otp-transport/openwa-transient-text.ts',
    'backend/src/modules/identity/internal/identity-transient-delivery.adapter.ts',
    'backend/src/modules/identity/internal/identity-transient-delivery.internal.module.ts',
    'backend/src/modules/identity/public/identity-transient-delivery-public.module.ts',
    'backend/src/modules/identity/public/identity-transient-delivery.port.ts',
    'backend/src/sharing/invitation-delivery.service.ts',
  ]) {
    const target = path.join(root, ...relativePath.split('/'));
    mkdirSync(path.dirname(target), { recursive: true });
    copyFileSync(path.join(repositoryRoot, ...relativePath.split('/')), target);
  }
}

afterEach(() => {
  for (const root of temporaryRoots.splice(0)) {
    rmSync(root, { recursive: true, force: true });
  }
});

test('R6 manifest pins the exact base, boundary, protected files, baselines, and scope', () => {
  const r6 = scanner();
  const manifest = r6.validateR6Manifest(readManifest());

  assert.equal(r6.R6_BASE, r6Base);
  assert.deepEqual(r6.STAGES, ['inventory', 'task-2', 'task-3', 'strict']);
  assert.equal(manifest.baseRevision, r6Base);
  assert.equal(manifest.stage, 'strict');
  assert.deepEqual(manifest.currentConcreteDependency, {
    consumer: 'backend/src/sharing/invitation-delivery.service.ts',
    transport: 'backend/src/platform/otp-transport/openwa-transient-text.ts',
    declarations: [
      'OpenWaTransientDeliveryRejectedError',
      'OpenWaTransientDeliveryUncertainError',
      'sendOpenWaTransientText',
    ],
  });
  assert.deepEqual(manifest.targetBoundary, {
    adapterPath: 'backend/src/modules/identity/internal/identity-transient-delivery.adapter.ts',
    collaborationModulePath:
      'backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts',
    consumerPath: 'backend/src/sharing/invitation-delivery.service.ts',
    identityModulePath: 'backend/src/modules/identity/identity.module.ts',
    implementationToken: 'IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION',
    inputType: 'IdentityTransientDeliveryInput',
    internalModulePath:
      'backend/src/modules/identity/internal/identity-transient-delivery.internal.module.ts',
    portInterface: 'IdentityTransientDeliveryPort',
    publicErrors: [
      'IdentityTransientDeliveryRejectedError',
      'IdentityTransientDeliveryUncertainError',
    ],
    publicModulePath:
      'backend/src/modules/identity/public/identity-transient-delivery-public.module.ts',
    publicPortPath:
      'backend/src/modules/identity/public/identity-transient-delivery.port.ts',
    token: 'IDENTITY_TRANSIENT_DELIVERY_PORT',
  });
  assert.deepEqual(manifest.protectedFiles, [
    {
      path: 'backend/src/platform/otp-transport/openwa-otp.channel.ts',
      sha256: '1f939561064a0d8c8bfe6142d9793c2b670557ff620bec1c0fec95669837fd50',
    },
    {
      path: 'backend/src/platform/otp-transport/openwa-transient-text.ts',
      sha256: '9b53d04193876cd0258dc367685fbf6bb8e6d23845bfc8a1e501512a2a68b5ac',
    },
  ]);
  assert.deepEqual(manifest.expectedBaselines, {
    dependencyRecords: 31,
    ownershipRecords: 385,
    ownershipOccurrences: 781,
    concreteTransportImports: {
      inventory: 1,
      'task-2': 1,
      'task-3': 0,
      strict: 0,
    },
  });
  assert.deepEqual(manifest.allowedChangedPaths, expectedAllowedChangedPaths);
});

test('R6 manifest rejects identity, shape, path, boundary, hash, and scope near-misses', () => {
  const r6 = scanner();
  const source = readManifest();
  const rejected: unknown[] = [];

  const unknownKey = structuredClone(source) as R6Manifest & { extra?: boolean };
  unknownKey.extra = true;
  rejected.push(unknownKey);

  const wrongBase = structuredClone(source);
  wrongBase.baseRevision = '0'.repeat(40);
  rejected.push(wrongBase);

  const wrongStage = structuredClone(source);
  wrongStage.stage = 'complete';
  rejected.push(wrongStage);

  const traversal = structuredClone(source);
  traversal.allowedChangedPaths[0] = '../outside.ts';
  rejected.push(traversal);

  const absolute = structuredClone(source);
  absolute.allowedChangedPaths[0] = 'C:/outside.ts';
  rejected.push(absolute);

  const wildcard = structuredClone(source);
  wildcard.allowedChangedPaths[0] = 'backend/src/**';
  rejected.push(wildcard);

  const duplicate = structuredClone(source);
  duplicate.allowedChangedPaths[1] = duplicate.allowedChangedPaths[0];
  rejected.push(duplicate);

  const reordered = structuredClone(source);
  [reordered.allowedChangedPaths[0], reordered.allowedChangedPaths[1]] = [
    reordered.allowedChangedPaths[1],
    reordered.allowedChangedPaths[0],
  ];
  rejected.push(reordered);

  const extraProductionPath = structuredClone(source);
  extraProductionPath.allowedChangedPaths.push('backend/src/app.module.ts');
  rejected.push(extraProductionPath);

  const changedToken = structuredClone(source);
  changedToken.targetBoundary.token = 'OPENWA_TRANSIENT_DELIVERY_PORT';
  rejected.push(changedToken);

  const changedHash = structuredClone(source);
  changedHash.protectedFiles[0].sha256 = '0'.repeat(64);
  rejected.push(changedHash);

  const changedDependencyBaseline = structuredClone(source);
  changedDependencyBaseline.expectedBaselines.dependencyRecords = 32;
  rejected.push(changedDependencyBaseline);

  const changedOwnershipBaseline = structuredClone(source);
  changedOwnershipBaseline.expectedBaselines.ownershipRecords = 384;
  rejected.push(changedOwnershipBaseline);

  const changedOwnershipOccurrences = structuredClone(source);
  changedOwnershipOccurrences.expectedBaselines.ownershipOccurrences = 780;
  rejected.push(changedOwnershipOccurrences);

  for (const value of rejected) {
    assert.throws(() => r6.validateR6Manifest(value));
  }

  const proxy = new Proxy(structuredClone(source), {});
  assert.throws(() => r6.validateR6Manifest(proxy), /plain|data/i);
});

test('R6 strict scan removes the Collaboration concrete import and keeps protected files', () => {
  const result = scanner().scanR6SharingOtpTransport({
    repositoryRoot,
    manifest: readManifest(),
  });
  assert.deepEqual(result, {
    ok: true,
    stage: 'strict',
    concreteImports: 0,
    protectedFiles: 2,
  });
});

test('R6 scan rejects a second Collaboration concrete transport import', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r6-transport-'));
  temporaryRoots.push(root);
  copyProtectedFixture(root);

  const extraPath = path.join(
    root,
    'backend',
    'src',
    'modules',
    'collaboration',
    'internal',
    'second-sender.ts',
  );
  mkdirSync(path.dirname(extraPath), { recursive: true });
  writeFileSync(
    extraPath,
    [
      "import { sendOpenWaTransientText } from '../../../platform/otp-transport/openwa-transient-text';",
      'export const secondSender = sendOpenWaTransientText;',
      '',
    ].join('\n'),
    'utf8',
  );

  assert.throws(
    () => scanner().scanR6SharingOtpTransport({
      repositoryRoot: root,
      manifest: readManifest(),
      readBaseFile: (relativePath: string) =>
        readFileSync(path.join(root, ...relativePath.split('/'))),
    }),
    /concrete.*import|transport.*import/i,
  );
});

test('R6 scan rejects any other Collaboration platform OTP transport import', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r6-other-transport-'));
  temporaryRoots.push(root);
  copyProtectedFixture(root);

  const extraPath = path.join(
    root,
    'backend',
    'src',
    'modules',
    'collaboration',
    'internal',
    'transport-config.ts',
  );
  mkdirSync(path.dirname(extraPath), { recursive: true });
  writeFileSync(
    extraPath,
    [
      "import '../../../platform/otp-transport/openwa-otp-config';",
      'export const importedTransportConfig = true;',
      '',
    ].join('\n'),
    'utf8',
  );

  assert.throws(
    () => scanner().scanR6SharingOtpTransport({
      repositoryRoot: root,
      manifest: readManifest(),
      readBaseFile: (relativePath: string) =>
        readFileSync(path.join(root, ...relativePath.split('/'))),
    }),
    /concrete.*import|transport.*import/i,
  );
});

test('R6 scan rejects protected OpenWA transport drift', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-r6-protected-'));
  temporaryRoots.push(root);
  copyProtectedFixture(root);
  const protectedPath = path.join(
    root,
    'backend',
    'src',
    'platform',
    'otp-transport',
    'openwa-otp.channel.ts',
  );
  writeFileSync(protectedPath, readFileSync(protectedPath, 'utf8') + '\n', 'utf8');

  assert.throws(
    () => scanner().scanR6SharingOtpTransport({
      repositoryRoot: root,
      manifest: readManifest(),
      readBaseFile: (relativePath: string) =>
        readFileSync(path.join(repositoryRoot, ...relativePath.split('/'))),
    }),
    /protected|hash|drift/i,
  );
});

test('R6 package scripts expose the standalone gate and keep every prior gate', () => {
  const packageJson = JSON.parse(
    readFileSync(path.join(backendRoot, 'package.json'), 'utf8'),
  ) as { scripts: Record<string, string> };
  assert.equal(
    packageJson.scripts['architecture:r6'],
    'node scripts/architecture/r6-sharing-otp-transport-scan.cjs --check',
  );
  assert.equal(
    packageJson.scripts.architecture,
    'npm run architecture:imports && npm run architecture:ownership && npm run architecture:ports && npm run architecture:r3 && npm run architecture:r4 && npm run architecture:r5 && npm run architecture:r6',
  );
});

test('R6 CLI accepts only check mode and reports one bounded result', () => {
  const output: string[] = [];
  const errors: string[] = [];
  const r6 = scanner();
  assert.equal(r6.runCli({
    argv: ['--check'],
    repositoryRoot,
    stdout: (message: string) => output.push(message),
    stderr: (message: string) => errors.push(message),
  }), 0);
  assert.equal(errors.length, 0);
  assert.deepEqual(output, [
    'PASS - R6 Sharing OTP transport: stage=strict, concrete-imports=0, protected=2',
  ]);

  assert.equal(r6.runCli({
    argv: ['--check', '--extra'],
    repositoryRoot,
    stdout: (message: string) => output.push(message),
    stderr: (message: string) => errors.push(message),
  }), 2);
  assert.equal(
    errors[errors.length - 1],
    'ERROR - R6 Sharing OTP transport validation failed',
  );
});

test('R6 Task 2 exposes the exact provider-neutral public contract', () => {
  const contractPath = path.join(
    backendRoot,
    'src/modules/identity/public/identity-transient-delivery.port.ts',
  );
  assert.equal(existsSync(contractPath), true, 'Identity transient delivery port must exist');

  const source = readFileSync(contractPath, 'utf8');
  const sourceFile = ts.createSourceFile(
    contractPath,
    source,
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.TS,
  );
  assert.deepEqual(
    sourceFile.statements.filter(ts.isImportDeclaration),
    [],
    'the public contract must have no concrete or framework imports',
  );

  const exportedNames = sourceFile.statements.flatMap((statement) => {
    const modifiers = ts.canHaveModifiers(statement)
      ? ts.getModifiers(statement)
      : undefined;
    const exported = modifiers?.some(
      (modifier) => modifier.kind === ts.SyntaxKind.ExportKeyword,
    );
    if (!exported) return [];
    if (
      ts.isTypeAliasDeclaration(statement)
      || ts.isInterfaceDeclaration(statement)
      || ts.isClassDeclaration(statement)
      || ts.isVariableStatement(statement)
    ) {
      if (ts.isVariableStatement(statement)) {
        return statement.declarationList.declarations.flatMap((declaration) =>
          ts.isIdentifier(declaration.name) ? [declaration.name.text] : []);
      }
      return statement.name ? [statement.name.text] : [];
    }
    return [];
  }).sort();
  assert.deepEqual(exportedNames, [
    'IDENTITY_TRANSIENT_DELIVERY_PORT',
    'IdentityTransientDeliveryInput',
    'IdentityTransientDeliveryPort',
    'IdentityTransientDeliveryRejectedError',
    'IdentityTransientDeliveryUncertainError',
  ]);

  const input = sourceFile.statements.find(
    (statement): statement is ts.TypeAliasDeclaration =>
      ts.isTypeAliasDeclaration(statement)
        && statement.name.text === 'IdentityTransientDeliveryInput',
  );
  assert.ok(input && ts.isTypeLiteralNode(input.type));
  assert.deepEqual(
    input.type.members.map((member) => member.getText(sourceFile)),
    ['phone: string;', 'text: string;'],
  );

  const port = sourceFile.statements.find(
    (statement): statement is ts.InterfaceDeclaration =>
      ts.isInterfaceDeclaration(statement)
        && statement.name.text === 'IdentityTransientDeliveryPort',
  );
  assert.ok(port);
  assert.deepEqual(
    port.members.map((member) => member.getText(sourceFile)),
    ['send(input: IdentityTransientDeliveryInput): Promise<void>;'],
  );

  const contract = require(contractPath);
  assert.deepEqual(Object.keys(contract).sort(), [
    'IDENTITY_TRANSIENT_DELIVERY_PORT',
    'IdentityTransientDeliveryRejectedError',
    'IdentityTransientDeliveryUncertainError',
  ]);
  assert.equal(typeof contract.IDENTITY_TRANSIENT_DELIVERY_PORT, 'symbol');
  assert.equal(
    contract.IDENTITY_TRANSIENT_DELIVERY_PORT,
    require(contractPath).IDENTITY_TRANSIENT_DELIVERY_PORT,
  );
});

test('R6 Task 2 adapter sends once, maps only known transport errors, and preserves unknown identity', async () => {
  const adapterPath = path.join(
    backendRoot,
    'src/modules/identity/internal/identity-transient-delivery.adapter',
  );
  assert.equal(existsSync(`${adapterPath}.ts`), true, 'Identity delivery adapter must exist');

  const transport = require(path.join(
    backendRoot,
    'src/platform/otp-transport/openwa-transient-text',
  ));
  const contract = require(path.join(
    backendRoot,
    'src/modules/identity/public/identity-transient-delivery.port',
  ));
  const { IdentityTransientDeliveryAdapter } = require(adapterPath);
  const adapter = new IdentityTransientDeliveryAdapter();
  const originalSender = transport.sendOpenWaTransientText;
  const input = { phone: '967700000001', text: 'دعوة اختبار' };

  const runWithSender = async (
    sender: (value: typeof input) => Promise<void>,
    exercise: () => Promise<void>,
  ) => {
    transport.sendOpenWaTransientText = sender;
    try {
      await exercise();
    } finally {
      transport.sendOpenWaTransientText = originalSender;
    }
  };

  let calls = 0;
  let received: unknown;
  await runWithSender(async (value) => {
    calls += 1;
    received = value;
  }, async () => adapter.send(input));
  assert.equal(calls, 1);
  assert.equal(received, input);
  assert.deepEqual(input, { phone: '967700000001', text: 'دعوة اختبار' });

  calls = 0;
  await runWithSender(async () => {
    calls += 1;
    throw new transport.OpenWaTransientDeliveryUncertainError();
  }, async () => {
    await assert.rejects(
      adapter.send(input),
      (error: unknown) =>
        error instanceof contract.IdentityTransientDeliveryUncertainError,
    );
  });
  assert.equal(calls, 1);

  calls = 0;
  await runWithSender(async () => {
    calls += 1;
    throw new transport.OpenWaTransientDeliveryRejectedError();
  }, async () => {
    await assert.rejects(
      adapter.send(input),
      (error: unknown) =>
        error instanceof contract.IdentityTransientDeliveryRejectedError,
    );
  });
  assert.equal(calls, 1);

  calls = 0;
  const unknown = { exact: 'unknown-error-identity' };
  await runWithSender(async () => {
    calls += 1;
    throw unknown;
  }, async () => {
    try {
      await adapter.send(input);
      assert.fail('unknown transport errors must be rethrown');
    } catch (error) {
      assert.equal(error, unknown);
    }
  });
  assert.equal(calls, 1);
});

test('R6 Task 2 binds one adapter singleton and exports only the public token', async () => {
  const requiredPaths = [
    'src/modules/identity/internal/identity-transient-delivery.internal.module.ts',
    'src/modules/identity/internal/identity-transient-delivery.adapter.ts',
    'src/modules/identity/public/identity-transient-delivery-public.module.ts',
    'src/modules/identity/public/identity-transient-delivery.port.ts',
  ];
  assert.equal(
    requiredPaths.every((relativePath) => existsSync(path.join(backendRoot, relativePath))),
    true,
    'Identity transient delivery modules must exist',
  );

  const internal = require(path.join(
    backendRoot,
    'src/modules/identity/internal/identity-transient-delivery.internal.module',
  ));
  const adapter = require(path.join(
    backendRoot,
    'src/modules/identity/internal/identity-transient-delivery.adapter',
  ));
  const publicBoundary = require(path.join(
    backendRoot,
    'src/modules/identity/public/identity-transient-delivery-public.module',
  ));
  const contract = require(path.join(
    backendRoot,
    'src/modules/identity/public/identity-transient-delivery.port',
  ));
  const identity = require(path.join(
    backendRoot,
    'src/modules/identity/identity.module',
  ));

  assert.deepEqual(
    Reflect.getMetadata(
      MODULE_METADATA.PROVIDERS,
      internal.IdentityTransientDeliveryInternalModule,
    ),
    [
      adapter.IdentityTransientDeliveryAdapter,
      {
        provide: internal.IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION,
        useExisting: adapter.IdentityTransientDeliveryAdapter,
      },
    ],
  );
  assert.deepEqual(
    Reflect.getMetadata(
      MODULE_METADATA.EXPORTS,
      internal.IdentityTransientDeliveryInternalModule,
    ),
    [internal.IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION],
  );
  assert.deepEqual(
    Reflect.getMetadata(
      MODULE_METADATA.IMPORTS,
      publicBoundary.IdentityTransientDeliveryPublicModule,
    ),
    [internal.IdentityTransientDeliveryInternalModule],
  );
  assert.deepEqual(
    Reflect.getMetadata(
      MODULE_METADATA.PROVIDERS,
      publicBoundary.IdentityTransientDeliveryPublicModule,
    ),
    [{
      provide: contract.IDENTITY_TRANSIENT_DELIVERY_PORT,
      useExisting: internal.IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION,
    }],
  );
  assert.deepEqual(
    Reflect.getMetadata(
      MODULE_METADATA.EXPORTS,
      publicBoundary.IdentityTransientDeliveryPublicModule,
    ),
    [contract.IDENTITY_TRANSIENT_DELIVERY_PORT],
  );

  const identityImports = Reflect.getMetadata(
    MODULE_METADATA.IMPORTS,
    identity.IdentityModule,
  ) as Function[];
  assert.equal(
    identityImports.filter(
      (entry) => entry === publicBoundary.IdentityTransientDeliveryPublicModule,
    ).length,
    1,
  );

  const context = await NestFactory.createApplicationContext(
    publicBoundary.IdentityTransientDeliveryPublicModule,
    { logger: false },
  );
  try {
    assert.equal(
      context.get(contract.IDENTITY_TRANSIENT_DELIVERY_PORT),
      context.get(adapter.IdentityTransientDeliveryAdapter),
    );
  } finally {
    await context.close();
  }
});

test('R6 Task 3 injects the canonical Identity port and imports only its public module', () => {
  const consumerPath = path.join(
    backendRoot,
    'src/sharing/invitation-delivery.service.ts',
  );
  const contractPath = path.join(
    backendRoot,
    'src/modules/identity/public/identity-transient-delivery.port.ts',
  );
  const service = require(consumerPath);
  const contract = require(contractPath);
  const collaboration = require(path.join(
    backendRoot,
    'src/modules/collaboration/internal/collaboration-services.internal.module',
  ));
  const publicBoundary = require(path.join(
    backendRoot,
    'src/modules/identity/public/identity-transient-delivery-public.module',
  ));
  const internalBoundary = require(path.join(
    backendRoot,
    'src/modules/identity/internal/identity-transient-delivery.internal.module',
  ));
  const identity = require(path.join(
    backendRoot,
    'src/modules/identity/identity.module',
  ));

  assert.deepEqual(
    Reflect.getMetadata(
      SELF_DECLARED_DEPS_METADATA,
      service.InvitationDeliveryService,
    ),
    [{ index: 0, param: contract.IDENTITY_TRANSIENT_DELIVERY_PORT }],
  );

  const collaborationImports = Reflect.getMetadata(
    MODULE_METADATA.IMPORTS,
    collaboration.CollaborationServicesInternalModule,
  ) as Function[];
  assert.equal(
    collaborationImports.filter(
      (entry) => entry === publicBoundary.IdentityTransientDeliveryPublicModule,
    ).length,
    1,
  );
  assert.equal(
    collaborationImports.includes(
      internalBoundary.IdentityTransientDeliveryInternalModule,
    ),
    false,
  );
  assert.equal(collaborationImports.includes(identity.IdentityModule), false);

  const collaborationProviders = Reflect.getMetadata(
    MODULE_METADATA.PROVIDERS,
    collaboration.CollaborationServicesInternalModule,
  ) as Function[];
  assert.equal(
    collaborationProviders.filter(
      (entry) => entry === service.InvitationDeliveryService,
    ).length,
    1,
  );
  assert.equal(
    collaborationProviders.includes(
      internalBoundary.IDENTITY_TRANSIENT_DELIVERY_IMPLEMENTATION,
    ),
    false,
  );
  assert.equal(
    collaborationProviders.includes(contract.IDENTITY_TRANSIENT_DELIVERY_PORT),
    false,
  );

  const program = ts.createProgram([consumerPath], {
    experimentalDecorators: true,
    module: ts.ModuleKind.CommonJS,
    moduleResolution: ts.ModuleResolutionKind.Node10,
    skipLibCheck: true,
    target: ts.ScriptTarget.ES2022,
  });
  const checker = program.getTypeChecker();
  const consumerSource = program.getSourceFile(consumerPath);
  const contractSource = program.getSourceFile(contractPath);
  assert.ok(consumerSource);
  assert.ok(contractSource);

  const resolvedSymbol = (node: ts.Node): ts.Symbol => {
    const symbol = checker.getSymbolAtLocation(node);
    assert.ok(symbol);
    return symbol.flags & ts.SymbolFlags.Alias
      ? checker.getAliasedSymbol(symbol)
      : symbol;
  };
  const contractDeclarations = new Map(
    contractSource.statements.flatMap((statement) => {
      if (ts.isVariableStatement(statement)) {
        const declaration = statement.declarationList.declarations[0];
        if (declaration && ts.isIdentifier(declaration.name)) {
          return [[
            declaration.name.text,
            resolvedSymbol(declaration.name),
          ] as const];
        }
      }
      if (
        (ts.isInterfaceDeclaration(statement) || ts.isClassDeclaration(statement))
        && statement.name
      ) {
        return [[statement.name.text, resolvedSymbol(statement.name)] as const];
      }
      return [];
    }),
  );

  const identityImport = consumerSource.statements.find(
    (statement): statement is ts.ImportDeclaration =>
      ts.isImportDeclaration(statement)
      && ts.isStringLiteral(statement.moduleSpecifier)
      && statement.moduleSpecifier.text.endsWith(
        'modules/identity/public/identity-transient-delivery.port',
      ),
  );
  assert.ok(identityImport);
  assert.ok(identityImport.importClause?.namedBindings);
  assert.ok(ts.isNamedImports(identityImport.importClause.namedBindings));
  const importedSymbols = identityImport.importClause.namedBindings.elements;
  assert.deepEqual(
    importedSymbols.map((element) => element.name.text).sort(),
    [
      'IDENTITY_TRANSIENT_DELIVERY_PORT',
      'IdentityTransientDeliveryPort',
      'IdentityTransientDeliveryRejectedError',
      'IdentityTransientDeliveryUncertainError',
    ],
  );
  for (const element of importedSymbols) {
    assert.equal(
      resolvedSymbol(element.name),
      contractDeclarations.get(element.name.text),
    );
  }

  const consumerClass = consumerSource.statements.find(
    (statement): statement is ts.ClassDeclaration =>
      ts.isClassDeclaration(statement)
      && statement.name?.text === 'InvitationDeliveryService',
  );
  assert.ok(consumerClass);
  const constructors = consumerClass.members.filter(ts.isConstructorDeclaration);
  assert.equal(constructors.length, 1);
  assert.equal(constructors[0].parameters.length, 1);
  const parameter = constructors[0].parameters[0];
  assert.ok(ts.isIdentifier(parameter.name));
  assert.equal(parameter.name.text, 'transientDelivery');
  assert.ok(parameter.type && ts.isTypeReferenceNode(parameter.type));
  assert.ok(ts.isIdentifier(parameter.type.typeName));
  assert.equal(
    resolvedSymbol(parameter.type.typeName),
    contractDeclarations.get('IdentityTransientDeliveryPort'),
  );

  const decorators = ts.getDecorators(parameter) ?? [];
  assert.equal(decorators.length, 1);
  assert.ok(ts.isCallExpression(decorators[0].expression));
  const injectCall = decorators[0].expression;
  assert.ok(ts.isIdentifier(injectCall.expression));
  assert.equal(injectCall.expression.text, 'Inject');
  assert.equal(injectCall.arguments.length, 1);
  assert.ok(ts.isIdentifier(injectCall.arguments[0]));
  assert.equal(
    resolvedSymbol(injectCall.arguments[0]),
    contractDeclarations.get('IDENTITY_TRANSIENT_DELIVERY_PORT'),
  );
});

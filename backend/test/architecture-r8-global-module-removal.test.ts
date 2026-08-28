import assert from 'node:assert/strict';
import {
  copyFileSync,
  mkdtempSync,
  mkdirSync,
  readFileSync,
  rmSync,
  symlinkSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { afterEach, test } from 'node:test';
import type { Program, TypeChecker } from 'typescript';

const backendRoot = path.resolve(__dirname, '..');
const manifestPath = path.join(
  backendRoot,
  'architecture',
  'r8-global-module-removal.json',
);
const scannerPath = path.join(
  backendRoot,
  'scripts',
  'architecture',
  'r8-global-module-removal-scan.cjs',
);
const temporaryRoots: string[] = [];

const expectedAllowedChangedPaths = [
  'ARCHITECTURE.md',
  'CHANGELOG.md',
  'backend/architecture/r8-global-module-removal.json',
  'backend/package.json',
  'backend/scripts/architecture/ports-scan.cjs',
  'backend/scripts/architecture/r3-context-scan.cjs',
  'backend/scripts/architecture/r3-scope.cjs',
  'backend/scripts/architecture/r5-identity-scan.cjs',
  'backend/scripts/architecture/r7-collaboration-relocation-scan.cjs',
  'backend/scripts/architecture/r8-global-module-removal-scan.cjs',
  'backend/scripts/security/prisma-config-merge-security.cjs',
  'backend/src/application-composition/application-outbox-runtime.module.ts',
  'backend/src/conversations/conversation-realtime.module.ts',
  'backend/src/platform/database/prisma.module.ts',
  'backend/test/architecture-ports.test.ts',
  'backend/test/architecture-r1-layout.test.ts',
  'backend/test/architecture-r3-composition.test.ts',
  'backend/test/architecture-r3-contexts.test.ts',
  'backend/test/architecture-r3-scope.test.ts',
  'backend/test/architecture-r4-planning-finance-boundary.test.ts',
  'backend/test/architecture-r5-identity-relocation.test.ts',
  'backend/test/architecture-r6-sharing-otp-transport.test.ts',
  'backend/test/architecture-r7-collaboration-relocation.test.ts',
  'backend/test/architecture-r8-global-module-removal.test.ts',
  'backend/test/prisma-config-merge-security.test.ts',
  'docs/README.md',
  'docs/SCRIPTS.md',
  'docs/backend/README.md',
  'docs/project/DECISIONS.md',
  'docs/project/EXECUTION_PLAN.md',
  'docs/project/STATUS.md',
  'docs/qa/README.md',
  'docs/superpowers/plans/2026-08-27-modular-monolith-r8-global-module-removal-completion.md',
  'docs/superpowers/plans/2026-08-27-modular-monolith-r8-global-module-removal.md',
  'docs/superpowers/specs/2026-08-27-modular-monolith-r8-global-module-removal-completion.md',
  'docs/superpowers/specs/2026-08-27-modular-monolith-r8-global-module-removal-design.md',
] as const;

type R8Manifest = {
  schemaVersion: number;
  baseRevision: string;
  stage: 'design' | 'strict';
  documents: {
    design: { path: string; sha256: string };
    plan: { path: string; sha256: string };
  };
  allowedChangedPaths: string[];
  projectProviders: {
    prisma: {
      modulePath: string;
      moduleClass: string;
      providerPath: string;
      providerClass: string;
      strictImporters: string[];
    };
    realtime: {
      modulePath: string;
      moduleClass: string;
      providerPath: string;
      providerClass: string;
      strictImporters: string[];
    };
  };
  messagingBindings: Array<{
    modulePath: string;
    providePath: string;
    provideName: string;
    useExistingPath: string;
    useExistingName: string;
  }>;
  r3Projection: {
    inventoryPath: string;
    globalTransitions: Array<{
      path: string;
      className: string;
      before: boolean;
      after: boolean;
    }>;
    importTransition: {
      path: string;
      className: string;
      before: string[];
      after: string[];
    };
  };
  externalGlobalIdentities: Array<{
    packageName: string;
    declaredRange: string;
    lockedVersion: string;
    resolved: string;
    integrity: string;
    importedClass: string;
    factoryMethod: string;
    sourcePath: string;
    callCount: number;
    installedEntrypoint: string;
    globalMechanism: string;
  }>;
  expectedCounts: {
    designProjectOwnedGlobals: number;
    strictProjectOwnedGlobals: number;
    designPrismaImporters: number;
    strictPrismaImporters: number;
    realtimeImporters: number;
    duplicateProviders: number;
    forwardRef: number;
    nestModuleCycles: number;
    dependencyRecords: number;
    ownershipRecords: number;
    ownershipOccurrences: number;
  };
};

type ProgramAnalysis = { program: Program; checker: TypeChecker };
type PrismaInspection = {
  importers: readonly string[];
  strictImporters: readonly string[];
  missingImporters: readonly string[];
  providerOwners: readonly string[];
  exportOwners: readonly string[];
  duplicateProviders: number;
};
type RealtimeInspection = {
  importers: readonly string[];
  providerOwners: readonly string[];
  exportOwners: readonly string[];
  duplicateProviders: number;
  bindings: readonly string[];
};
type R8Scanner = {
  R8_BASE: string;
  EXPECTED_ALLOWED_PATHS: readonly string[];
  collectDirectPrismaConsumers(
    program: Program,
    checker: TypeChecker,
    repositoryRoot: string,
  ): PrismaInspection;
  collectProjectGlobalActivations(
    program: Program,
    checker: TypeChecker,
    repositoryRoot: string,
  ): {
    projectOwnedGlobals: number;
    globalPaths: readonly string[];
    forwardRef: number;
    nestModuleCycles: number;
  };
  collectRealtimeComposition(
    program: Program,
    checker: TypeChecker,
    repositoryRoot: string,
  ): RealtimeInspection;
  createProgram(repositoryRoot: string): ProgramAnalysis;
  projectR3InventoryForR8(inventory: unknown, manifest: unknown): unknown;
  runCli(options?: {
    argv?: string[];
    repositoryRoot?: string;
    stdout?: (message: string) => void;
    stderr?: (message: string) => void;
  }): number;
  scanR8GlobalRemoval(options: {
    repositoryRoot: string;
    manifest: unknown;
  }): unknown;
  validateR8Manifest(value: unknown): Readonly<R8Manifest>;
  validateR8ScanResult(value: unknown): unknown;
  verifyExternalGlobalIdentities(repositoryRoot: string, manifest: unknown): unknown;
};

function scanner(modulePath = scannerPath): R8Scanner {
  return require(modulePath) as R8Scanner;
}

function manifest(): R8Manifest {
  return JSON.parse(readFileSync(manifestPath, 'utf8')) as R8Manifest;
}

const repositoryRoot = path.resolve(backendRoot, '..');
const strictPrismaImporters = [
  'backend/src/app.module.ts',
  'backend/src/application-composition/application-outbox-runtime.module.ts',
  'backend/src/modules/backoffice/internal/backoffice-services.internal.module.ts',
  'backend/src/modules/catalog/internal/catalog-services.internal.module.ts',
  'backend/src/modules/collaboration/internal/collaboration-history.internal.module.ts',
  'backend/src/modules/collaboration/internal/collaboration-permission.internal.module.ts',
  'backend/src/modules/collaboration/internal/collaboration-services.internal.module.ts',
  'backend/src/modules/finance/internal/finance-services.internal.module.ts',
  'backend/src/modules/guests/internal/guests-service.internal.module.ts',
  'backend/src/modules/identity/internal/identity-auth.internal.module.ts',
  'backend/src/modules/identity/internal/identity-profile.internal.module.ts',
  'backend/src/modules/insights/internal/insights-services.internal.module.ts',
  'backend/src/modules/marketplace/internal/marketplace-services.internal.module.ts',
  'backend/src/modules/media/internal/media-storage.internal.module.ts',
  'backend/src/modules/messaging/internal/messaging-conversations.internal.module.ts',
  'backend/src/modules/notifications/internal/notifications-service.internal.module.ts',
  'backend/src/modules/notifications/internal/push-installations.internal.module.ts',
  'backend/src/modules/notifications/internal/push-transport.internal.module.ts',
  'backend/src/modules/planning/internal/planning-services.internal.module.ts',
  'backend/src/modules/tasks/internal/tasks-service.internal.module.ts',
  'backend/src/platform/outbox/outbox-core.module.ts',
] as const;
const strictRealtimeImporters = [
  'backend/src/modules/messaging/internal/messaging-conversations.internal.module.ts',
  'backend/src/modules/messaging/internal/messaging-realtime.internal.module.ts',
] as const;
const expectedExternalIdentities = [
  {
    packageName: '@nestjs/schedule',
    declaredRange: '^6.1.3',
    lockedVersion: '6.1.3',
    resolved: 'https://registry.npmjs.org/@nestjs/schedule/-/schedule-6.1.3.tgz',
    integrity: 'sha512-RflMFOpR16Dwd1jAUbeB4mfGTCh65fvEdL4mSjQPJChpkRGRjIXjb+6YQcK2faQrVT60c9DmLmoVR7/ONCtuYQ==',
    importedClass: 'ScheduleModule',
    factoryMethod: 'forRoot',
    sourcePath: 'backend/src/app.module.ts',
    callCount: 1,
    installedEntrypoint: 'dist/index.js',
    globalMechanism: 'dynamic-module-global',
  },
  {
    packageName: '@nestjs/throttler',
    declaredRange: '^6.5.0',
    lockedVersion: '6.5.0',
    resolved: 'https://registry.npmjs.org/@nestjs/throttler/-/throttler-6.5.0.tgz',
    integrity: 'sha512-9j0ZRfH0QE1qyrj9JjIRDz5gQLPqq9yVC2nHsrosDVAfI5HHw08/aUAWx9DZLSdQf4HDkmhTTEGLrRFHENvchQ==',
    importedClass: 'ThrottlerModule',
    factoryMethod: 'forRootAsync',
    sourcePath: 'backend/src/app.module.ts',
    callCount: 1,
    installedEntrypoint: 'dist/index.js',
    globalMechanism: 'global-decorator',
  },
] as const;

function manifestWithContract(): R8Manifest {
  return {
    ...manifest(),
    projectProviders: {
      prisma: {
        modulePath: 'backend/src/platform/database/prisma.module.ts',
        moduleClass: 'PrismaModule',
        providerPath: 'backend/src/platform/database/prisma.service.ts',
        providerClass: 'PrismaService',
        strictImporters: [...strictPrismaImporters],
      },
      realtime: {
        modulePath: 'backend/src/conversations/conversation-realtime.module.ts',
        moduleClass: 'ConversationRealtimeModule',
        providerPath: 'backend/src/conversations/conversation-realtime.publisher.ts',
        providerClass: 'ConversationRealtimePublisher',
        strictImporters: [...strictRealtimeImporters],
      },
    },
    messagingBindings: [
      {
        modulePath: 'backend/src/modules/messaging/internal/messaging-realtime.internal.module.ts',
        providePath: 'backend/src/modules/messaging/internal/messaging-realtime.implementation-token.ts',
        provideName: 'MESSAGING_REALTIME_IMPLEMENTATION',
        useExistingPath: 'backend/src/conversations/conversation-realtime.publisher.ts',
        useExistingName: 'ConversationRealtimePublisher',
      },
      {
        modulePath: 'backend/src/modules/messaging/public/messaging-realtime-public.module.ts',
        providePath: 'backend/src/modules/messaging/public/messaging-realtime.port.ts',
        provideName: 'MESSAGING_REALTIME_PORT',
        useExistingPath: 'backend/src/modules/messaging/internal/messaging-realtime.implementation-token.ts',
        useExistingName: 'MESSAGING_REALTIME_IMPLEMENTATION',
      },
    ],
    r3Projection: {
      inventoryPath: 'backend/architecture/r3-context-boundaries.json',
      globalTransitions: [
        {
          path: 'backend/src/conversations/conversation-realtime.module.ts',
          className: 'ConversationRealtimeModule',
          before: true,
          after: false,
        },
        {
          path: 'backend/src/platform/database/prisma.module.ts',
          className: 'PrismaModule',
          before: true,
          after: false,
        },
      ],
      importTransition: {
        path: 'backend/src/application-composition/application-outbox-runtime.module.ts',
        className: 'ApplicationOutboxRuntimeModule',
        before: [
          'MessagingRealtimePublicModule',
          'OutboxCoreModule',
          'PushDeliveryPublicModule',
        ],
        after: [
          'MessagingRealtimePublicModule',
          'OutboxCoreModule',
          'PrismaModule',
          'PushDeliveryPublicModule',
        ],
      },
    },
    externalGlobalIdentities: expectedExternalIdentities.map((entry) => ({ ...entry })),
    expectedCounts: {
      designProjectOwnedGlobals: 2,
      strictProjectOwnedGlobals: 0,
      designPrismaImporters: 20,
      strictPrismaImporters: 21,
      realtimeImporters: 2,
      duplicateProviders: 0,
      forwardRef: 0,
      nestModuleCycles: 0,
      dependencyRecords: 22,
      ownershipRecords: 385,
      ownershipOccurrences: 781,
    },
  };
}

function assertR8Failure(action: () => unknown, pattern: RegExp): void {
  assert.throws(action, (error: unknown) => (
    error instanceof Error
    && !/not a function/u.test(error.message)
    && pattern.test(error.message)
  ));
}

function writeFixtureFile(root: string, relativePath: string, contents: string): void {
  const absolutePath = path.join(root, ...relativePath.split('/'));
  mkdirSync(path.dirname(absolutePath), { recursive: true });
  writeFileSync(absolutePath, contents, 'utf8');
}

function sourceFixture(files: Record<string, string>): string {
  const root = mkdtempSync(path.join(backendRoot, '.r8-architecture-fixture-'));
  temporaryRoots.push(root);
  writeFixtureFile(root, 'backend/tsconfig.json', JSON.stringify({
    compilerOptions: {
      module: 'commonjs',
      target: 'ES2021',
      moduleResolution: 'node',
      experimentalDecorators: true,
      emitDecoratorMetadata: true,
      strict: true,
      skipLibCheck: true,
      noEmit: true,
    },
    include: ['src/**/*.ts'],
  }));
  for (const [relativePath, contents] of Object.entries(files)) {
    writeFixtureFile(root, relativePath, contents);
  }
  return root;
}

function inspectFixtureGlobals(files: Record<string, string>): ReturnType<
  R8Scanner['collectProjectGlobalActivations']
> {
  const r8 = scanner();
  const root = sourceFixture(files);
  const { program, checker } = r8.createProgram(root);
  return r8.collectProjectGlobalActivations(program, checker, root);
}

function inspectPrismaFixture(files: Record<string, string>): PrismaInspection {
  const r8 = scanner();
  const root = sourceFixture({
    'backend/src/platform/database/prisma.service.ts': `
      export class PrismaService {}
    `,
    'backend/src/platform/database/prisma.module.ts': `
      import { Module } from '@nestjs/common';
      import { PrismaService } from './prisma.service';
      @Module({ providers: [PrismaService], exports: [PrismaService] })
      export class PrismaModule {}
    `,
    ...files,
  });
  const { program, checker } = r8.createProgram(root);
  return r8.collectDirectPrismaConsumers(program, checker, root);
}

function inspectRealtimeFixture(files: Record<string, string> = {}): RealtimeInspection {
  const r8 = scanner();
  const root = sourceFixture({
    'backend/src/conversations/conversation-realtime.publisher.ts': `
      export class ConversationRealtimePublisher {}
    `,
    'backend/src/conversations/conversation-realtime.module.ts': `
      import { Module } from '@nestjs/common';
      import { ConversationRealtimePublisher } from './conversation-realtime.publisher';
      @Module({
        providers: [ConversationRealtimePublisher],
        exports: [ConversationRealtimePublisher],
      })
      export class ConversationRealtimeModule {}
    `,
    'backend/src/conversations/conversations.service.ts': `
      import { ConversationRealtimePublisher } from './conversation-realtime.publisher';
      export class ConversationsService {
        constructor(readonly realtime: ConversationRealtimePublisher) {}
      }
    `,
    'backend/src/modules/messaging/internal/messaging-realtime.implementation-token.ts': `
      export const MESSAGING_REALTIME_IMPLEMENTATION = Symbol('MESSAGING_REALTIME_IMPLEMENTATION');
    `,
    'backend/src/modules/messaging/public/messaging-realtime.port.ts': `
      export const MESSAGING_REALTIME_PORT = Symbol('MESSAGING_REALTIME_PORT');
    `,
    'backend/src/modules/messaging/internal/messaging-conversations.internal.module.ts': `
      import { Module } from '@nestjs/common';
      import { ConversationRealtimeModule } from '../../../conversations/conversation-realtime.module';
      import { ConversationsService } from '../../../conversations/conversations.service';
      @Module({ imports: [ConversationRealtimeModule], providers: [ConversationsService] })
      export class MessagingConversationsInternalModule {}
    `,
    'backend/src/modules/messaging/internal/messaging-realtime.internal.module.ts': `
      import { Module } from '@nestjs/common';
      import { ConversationRealtimeModule } from '../../../conversations/conversation-realtime.module';
      import { ConversationRealtimePublisher } from '../../../conversations/conversation-realtime.publisher';
      import { MESSAGING_REALTIME_IMPLEMENTATION } from './messaging-realtime.implementation-token';
      @Module({
        imports: [ConversationRealtimeModule],
        providers: [{
          provide: MESSAGING_REALTIME_IMPLEMENTATION,
          useExisting: ConversationRealtimePublisher,
        }],
        exports: [MESSAGING_REALTIME_IMPLEMENTATION],
      })
      export class MessagingRealtimeInternalModule {}
    `,
    'backend/src/modules/messaging/public/messaging-realtime-public.module.ts': `
      import { Module } from '@nestjs/common';
      import { MessagingRealtimeInternalModule } from '../internal/messaging-realtime.internal.module';
      import { MESSAGING_REALTIME_IMPLEMENTATION } from '../internal/messaging-realtime.implementation-token';
      import { MESSAGING_REALTIME_PORT } from './messaging-realtime.port';
      @Module({
        imports: [MessagingRealtimeInternalModule],
        providers: [{
          provide: MESSAGING_REALTIME_PORT,
          useExisting: MESSAGING_REALTIME_IMPLEMENTATION,
        }],
        exports: [MESSAGING_REALTIME_PORT],
      })
      export class MessagingRealtimePublicModule {}
    `,
    ...files,
  });
  const { program, checker } = r8.createProgram(root);
  return r8.collectRealtimeComposition(program, checker, root);
}

function externalFixture(): string {
  const root = sourceFixture({
    'backend/src/app.module.ts': readFileSync(path.join(backendRoot, 'src', 'app.module.ts'), 'utf8'),
  });
  copyFileSync(path.join(backendRoot, 'package.json'), path.join(root, 'backend', 'package.json'));
  copyFileSync(path.join(backendRoot, 'package-lock.json'), path.join(root, 'backend', 'package-lock.json'));
  return root;
}

afterEach(() => {
  for (const root of temporaryRoots.splice(0)) rmSync(root, { recursive: true, force: true });
});

test('R8 design-stage manifest is exact, hash-bound, and deeply immutable', () => {
  const r8 = scanner();
  const value = manifest();
  const validated = r8.validateR8Manifest(value);

  assert.equal(r8.R8_BASE, 'c2b728bfe54304562923facfb6094e0de04c0b27');
  assert.deepEqual(r8.EXPECTED_ALLOWED_PATHS, expectedAllowedChangedPaths);
  assert.deepEqual(Object.keys(value), [
    'schemaVersion',
    'baseRevision',
    'stage',
    'documents',
    'allowedChangedPaths',
    'projectProviders',
    'messagingBindings',
    'r3Projection',
    'externalGlobalIdentities',
    'expectedCounts',
  ]);
  assert.equal(validated.schemaVersion, 1);
  assert.equal(validated.baseRevision, 'c2b728bfe54304562923facfb6094e0de04c0b27');
  assert.equal(validated.stage, 'design');
  assert.deepEqual(validated.documents, {
    design: {
      path: 'docs/superpowers/specs/2026-08-27-modular-monolith-r8-global-module-removal-design.md',
      sha256: 'ad6f3bb46aca7b24d240fcfa011489756aa08e6ef9f000a002ea350c5625cb64',
    },
    plan: {
      path: 'docs/superpowers/plans/2026-08-27-modular-monolith-r8-global-module-removal.md',
      sha256: '0eeabbe5c33a48f310e40c2ed2283704180362ff31e97030b948578624ba1220',
    },
  });
  assert.deepEqual(validated.allowedChangedPaths, expectedAllowedChangedPaths);
  assert.deepEqual(validated.projectProviders.prisma, {
    modulePath: 'backend/src/platform/database/prisma.module.ts',
    moduleClass: 'PrismaModule',
    providerPath: 'backend/src/platform/database/prisma.service.ts',
    providerClass: 'PrismaService',
    strictImporters: strictPrismaImporters,
  });
  assert.deepEqual(validated.projectProviders.realtime, {
    modulePath: 'backend/src/conversations/conversation-realtime.module.ts',
    moduleClass: 'ConversationRealtimeModule',
    providerPath: 'backend/src/conversations/conversation-realtime.publisher.ts',
    providerClass: 'ConversationRealtimePublisher',
    strictImporters: strictRealtimeImporters,
  });
  assert.deepEqual(validated.externalGlobalIdentities, expectedExternalIdentities);
  assert.deepEqual(validated.expectedCounts, {
    designProjectOwnedGlobals: 2,
    strictProjectOwnedGlobals: 0,
    designPrismaImporters: 20,
    strictPrismaImporters: 21,
    realtimeImporters: 2,
    duplicateProviders: 0,
    forwardRef: 0,
    nestModuleCycles: 0,
    dependencyRecords: 22,
    ownershipRecords: 385,
    ownershipOccurrences: 781,
  });
  assert.equal(Object.isFrozen(validated), true);
  assert.equal(Object.isFrozen(validated.documents), true);
  assert.equal(Object.isFrozen(validated.documents.design), true);
  assert.equal(Object.isFrozen(validated.documents.plan), true);
  assert.equal(Object.isFrozen(validated.allowedChangedPaths), true);
  assert.equal(Object.isFrozen(validated.projectProviders), true);
  assert.equal(Object.isFrozen(validated.projectProviders.prisma.strictImporters), true);
  assert.equal(Object.isFrozen(validated.externalGlobalIdentities), true);
  assert.equal(Object.isFrozen(validated.externalGlobalIdentities[0]), true);

  value.allowedChangedPaths[0] = 'docs/attacker.md';
  value.documents.design.sha256 = '0'.repeat(64);
  assert.deepEqual(validated.allowedChangedPaths, expectedAllowedChangedPaths);
  assert.equal(
    validated.documents.design.sha256,
    'ad6f3bb46aca7b24d240fcfa011489756aa08e6ef9f000a002ea350c5625cb64',
  );

  const strict = manifest();
  strict.stage = 'strict';
  assert.equal(r8.validateR8Manifest(strict).stage, 'strict');
});

test('R8 validator rejects non-plain, sparse, accessor, and unknown-key data', () => {
  const r8 = scanner();
  const valid = manifest();
  const sparse = structuredClone(valid);
  sparse.allowedChangedPaths = new Array(expectedAllowedChangedPaths.length);
  const accessor = structuredClone(valid) as R8Manifest & { extra?: boolean };
  Object.defineProperty(accessor, 'stage', { get: () => 'design', enumerable: true });
  const arrayAccessor = structuredClone(valid);
  Object.defineProperty(arrayAccessor.allowedChangedPaths, '0', {
    get: () => expectedAllowedChangedPaths[0],
    enumerable: true,
  });
  const unknown = structuredClone(valid) as R8Manifest & { extra?: boolean };
  unknown.extra = true;

  for (const candidate of [
    null,
    [],
    new Date(),
    new Proxy(valid, {}),
    sparse,
    accessor,
    arrayAccessor,
    unknown,
  ]) {
    assert.throws(() => r8.validateR8Manifest(candidate), /R8 manifest|plain|dense|accessor|key/i);
  }
});

test('R8 validator rejects a junction in an allowed-path ancestry', () => {
  const fixtureRoot = mkdtempSync(path.join(tmpdir(), 'aarast-r8-manifest-junction-'));
  const outsideRoot = mkdtempSync(path.join(tmpdir(), 'aarast-r8-manifest-outside-'));
  temporaryRoots.push(fixtureRoot, outsideRoot);
  const fixtureScannerPath = path.join(
    fixtureRoot,
    'backend',
    'scripts',
    'architecture',
    'r8-global-module-removal-scan.cjs',
  );
  mkdirSync(path.dirname(fixtureScannerPath), { recursive: true });
  copyFileSync(scannerPath, fixtureScannerPath);
  symlinkSync(outsideRoot, path.join(fixtureRoot, 'docs'), process.platform === 'win32' ? 'junction' : 'dir');

  assert.throws(
    () => scanner(fixtureScannerPath).validateR8Manifest(manifest()),
    /reparse|junction|symbolic/i,
  );
});

test('R8 design scan reports the exact live global and DI closure', () => {
  const r8 = scanner();
  assert.deepEqual(
    r8.scanR8GlobalRemoval({ repositoryRoot, manifest: manifest() }),
    {
      ok: true,
      stage: 'design',
      projectOwnedGlobals: 2,
      prismaImporters: 20,
      missingPrismaImporters: [
        'backend/src/application-composition/application-outbox-runtime.module.ts',
      ],
      realtimeImporters: 2,
      duplicateProviders: 0,
      forwardRef: 0,
      nestModuleCycles: 0,
      dependencyRecords: 22,
      ownershipRecords: 385,
      ownershipOccurrences: 781,
    },
  );
});

test('R8 live provider owners, importer projection, and Messaging aliases are exact', () => {
  const r8 = scanner();
  const { program, checker } = r8.createProgram(repositoryRoot);
  const prisma = r8.collectDirectPrismaConsumers(program, checker, repositoryRoot);
  const realtime = r8.collectRealtimeComposition(program, checker, repositoryRoot);

  assert.deepEqual(prisma.providerOwners, [
    'backend/src/platform/database/prisma.module.ts#PrismaModule',
  ]);
  assert.deepEqual(prisma.exportOwners, [
    'backend/src/platform/database/prisma.module.ts#PrismaModule',
  ]);
  assert.deepEqual(prisma.strictImporters, strictPrismaImporters);
  assert.deepEqual(prisma.importers, strictPrismaImporters.filter(
    (entry) => entry !== 'backend/src/application-composition/application-outbox-runtime.module.ts',
  ));
  assert.deepEqual(prisma.missingImporters, [
    'backend/src/application-composition/application-outbox-runtime.module.ts',
  ]);
  assert.equal(prisma.duplicateProviders, 0);

  assert.deepEqual(realtime.providerOwners, [
    'backend/src/conversations/conversation-realtime.module.ts#ConversationRealtimeModule',
  ]);
  assert.deepEqual(realtime.exportOwners, [
    'backend/src/conversations/conversation-realtime.module.ts#ConversationRealtimeModule',
  ]);
  assert.deepEqual(realtime.importers, strictRealtimeImporters);
  assert.deepEqual(realtime.bindings, [
    'backend/src/modules/messaging/internal/messaging-realtime.internal.module.ts#MESSAGING_REALTIME_IMPLEMENTATION->ConversationRealtimePublisher',
    'backend/src/modules/messaging/public/messaging-realtime-public.module.ts#MESSAGING_REALTIME_PORT->MESSAGING_REALTIME_IMPLEMENTATION',
  ]);
  assert.equal(realtime.duplicateProviders, 0);
});

test('R8 projects only the exact strict R3 global and Outbox import transitions', () => {
  const r8 = scanner();
  const historical = JSON.parse(readFileSync(
    path.join(backendRoot, 'architecture', 'r3-context-boundaries.json'),
    'utf8',
  ));
  const strict = manifest();
  strict.stage = 'strict';
  const projected = r8.projectR3InventoryForR8(historical, strict) as {
    legacyModules: Array<Record<string, unknown>>;
  };
  const byPath = new Map(projected.legacyModules.map((entry) => [entry.path, entry]));
  assert.equal(byPath.get('backend/src/platform/database/prisma.module.ts')?.global, false);
  assert.equal(byPath.get('backend/src/conversations/conversation-realtime.module.ts')?.global, false);
  assert.deepEqual(
    byPath.get('backend/src/application-composition/application-outbox-runtime.module.ts')?.imports,
    [
      'MessagingRealtimePublicModule',
      'OutboxCoreModule',
      'PrismaModule',
      'PushDeliveryPublicModule',
    ],
  );
  assert.throws(
    () => r8.projectR3InventoryForR8(historical, manifest()),
    /strict|projection/i,
  );
});

test('R8 live external global identities prove the exact calls and installed locks', () => {
  const r8 = scanner();
  assert.deepEqual(
    r8.verifyExternalGlobalIdentities(repositoryRoot, manifest()),
    {
      identities: 2,
      packages: ['@nestjs/schedule@6.1.3', '@nestjs/throttler@6.5.0'],
    },
  );
});

test('R8 CLI and result validator are fixed, bounded, and sanitized', () => {
  const r8 = scanner();
  const stdout: string[] = [];
  const stderr: string[] = [];
  assert.equal(r8.runCli({
    argv: ['--check'],
    repositoryRoot,
    stdout: (message) => stdout.push(message),
    stderr: (message) => stderr.push(message),
  }), 0);
  assert.equal(stdout.length, 1);
  assert.match(stdout[0], /^PASS - R8 global removal: stage=design, globals=2, Prisma=20\/21, missing=1, Realtime=2, duplicates=0, forwardRef=0, cycles=0, dependency=22, ownership=385\/781$/u);
  assert.deepEqual(stderr, []);

  const invalidOut: string[] = [];
  const invalidErr: string[] = [];
  assert.equal(r8.runCli({
    argv: ['--unknown'],
    repositoryRoot,
    stdout: (message) => invalidOut.push(message),
    stderr: (message) => invalidErr.push(message),
  }), 2);
  assert.deepEqual(invalidOut, []);
  assert.deepEqual(invalidErr, ['ERROR - R8 global removal validation failed']);
  assert.doesNotMatch(invalidErr.join('\n'), /(?:[A-Za-z]:\\|file:\/\/|Error:|\n\s+at\s)/u);

  const validResult = {
    stage: 'design',
    globals: { projectOwnedGlobals: 2, forwardRef: 0, nestModuleCycles: 0 },
    prisma: {
      importers: strictPrismaImporters.slice(1),
      missingImporters: [strictPrismaImporters[1]],
      duplicateProviders: 0,
    },
    realtime: { importers: strictRealtimeImporters, duplicateProviders: 0 },
    external: { identities: 2 },
    dependencyRecords: 22,
    ownershipRecords: 385,
    ownershipOccurrences: 781,
  };
  assert.doesNotThrow(() => r8.validateR8ScanResult(validResult));
  for (const mutation of [
    { ...validResult, extra: true },
    { ...validResult, stage: 'relocated' },
    { ...validResult, dependencyRecords: -1 },
    { ...validResult, external: { identities: 3 } },
  ]) {
    assert.throws(() => r8.validateR8ScanResult(mutation), /R8|scan|result|schema/i);
  }
});

test('R8 resolves direct, aliased, namespace, re-exported, and computed Nest Global', async (t) => {
  const variants: Array<[string, Record<string, string>]> = [
    ['direct', {
      'backend/src/direct.ts': `
        import { Global, Module } from '@nestjs/common';
        @Global() @Module({}) export class DirectModule {}
      `,
    }],
    ['aliased', {
      'backend/src/aliased.ts': `
        import { Global as ProjectGlobal, Module } from '@nestjs/common';
        @ProjectGlobal() @Module({}) export class AliasedModule {}
      `,
    }],
    ['namespace', {
      'backend/src/namespace.ts': `
        import * as Nest from '@nestjs/common';
        @Nest.Global() @Nest.Module({}) export class NamespaceModule {}
      `,
    }],
    ['re-exported', {
      'backend/src/nest-reexport.ts': `export { Global as ProjectGlobal, Module } from '@nestjs/common';`,
      'backend/src/reexported.ts': `
        import { ProjectGlobal, Module } from './nest-reexport';
        @ProjectGlobal() @Module({}) export class ReexportedModule {}
      `,
    }],
    ['computed', {
      'backend/src/computed.ts': `
        import * as Nest from '@nestjs/common';
        const ComputedGlobal = Nest['Global'];
        const ComputedModuleDecorator = Nest['Module'];
        @ComputedGlobal() @ComputedModuleDecorator({}) export class ComputedModule {}
      `,
    }],
  ];
  for (const [name, files] of variants) {
    await t.test(name, () => {
      const result = inspectFixtureGlobals(files);
      assert.equal(result.projectOwnedGlobals, 1);
      assert.equal(result.globalPaths.length, 1);
    });
  }
});

test('R8 detects finite project DynamicModule global metadata and fails closed when unresolved', async (t) => {
  const variants: Array<[string, Record<string, string>]> = [
    ['literal', {
      'backend/src/literal.ts': `
        import { DynamicModule } from '@nestjs/common';
        export class LiteralModule {
          static register(): DynamicModule { return { module: LiteralModule, global: true }; }
        }
      `,
    }],
    ['local alias', {
      'backend/src/local-alias.ts': `
        import { DynamicModule } from '@nestjs/common';
        export class LocalAliasModule {
          static register(): DynamicModule {
            const metadata = { module: LocalAliasModule, global: true };
            return metadata;
          }
        }
      `,
    }],
    ['cross-file alias', {
      'backend/src/cross-metadata.ts': `
        export class CrossTargetModule {}
        export const crossMetadata = { module: CrossTargetModule, global: true } as const;
      `,
      'backend/src/cross.ts': `
        import { DynamicModule } from '@nestjs/common';
        import { crossMetadata } from './cross-metadata';
        export class CrossModule { static register(): DynamicModule { return crossMetadata; } }
      `,
    }],
    ['object spread', {
      'backend/src/spread.ts': `
        import { DynamicModule } from '@nestjs/common';
        const activation = { global: true } as const;
        export class SpreadModule {
          static register(): DynamicModule { return { module: SpreadModule, ...activation }; }
        }
      `,
    }],
    ['computed key', {
      'backend/src/computed-key.ts': `
        import { DynamicModule } from '@nestjs/common';
        const key = 'global' as const;
        export class ComputedKeyModule {
          static register(): DynamicModule { return { module: ComputedKeyModule, [key]: true }; }
        }
      `,
    }],
    ['inferred direct return', {
      'backend/src/inferred-direct.ts': `
        import { Module } from '@nestjs/common';
        @Module({})
        export class InferredDirectModule {
          static register() { return { module: InferredDirectModule, global: true }; }
        }
      `,
    }],
    ['inferred local alias return', {
      'backend/src/inferred-local-alias.ts': `
        import { Module } from '@nestjs/common';
        @Module({})
        export class InferredLocalAliasModule {
          static register() {
            const metadata = { module: InferredLocalAliasModule, global: true } as const;
            return metadata;
          }
        }
      `,
    }],
    ['inferred object spread return', {
      'backend/src/inferred-spread.ts': `
        import { Module } from '@nestjs/common';
        const activation = { global: true } as const;
        @Module({})
        export class InferredSpreadModule {
          static register() { return { module: InferredSpreadModule, ...activation }; }
        }
      `,
    }],
    ['inferred computed return', {
      'backend/src/inferred-computed.ts': `
        import { Module } from '@nestjs/common';
        const activation = 'global' as const;
        @Module({})
        export class InferredComputedModule {
          static register() { return { module: InferredComputedModule, [activation]: true }; }
        }
      `,
    }],
  ];
  for (const [name, files] of variants) {
    await t.test(name, () => {
      const result = inspectFixtureGlobals(files);
      assert.equal(result.projectOwnedGlobals, 1);
    });
  }

  await t.test('unresolved return metadata', () => {
    assert.throws(() => inspectFixtureGlobals({
      'backend/src/unresolved.ts': `
        import { DynamicModule } from '@nestjs/common';
        declare function metadata(): DynamicModule;
        export class UnresolvedModule {
          static register(): DynamicModule { return metadata(); }
        }
      `,
    }), /DynamicModule|metadata|resolve/i);
  });

  await t.test('same-name local interface is not a Nest DynamicModule', () => {
    assert.equal(inspectFixtureGlobals({
      'backend/src/decoy.ts': `
        interface DynamicModule { global: boolean }
        export function decoy(): DynamicModule { return { global: true }; }
      `,
    }).projectOwnedGlobals, 0);
  });

  await t.test('ordinary object-returning helper is not a Nest module factory', () => {
    assert.equal(inspectFixtureGlobals({
      'backend/src/ordinary-helper.ts': `
        export class OrdinaryClass {}
        export function ordinaryHelper() {
          return { module: OrdinaryClass, global: true };
        }
      `,
    }).projectOwnedGlobals, 0);
  });

  const unresolvedFactoryNames = [
    'forFeature', 'forFeatureAsync', 'forRoot', 'forRootAsync', 'register', 'registerAsync',
  ];
  for (const factoryName of unresolvedFactoryNames) {
    await t.test(`unresolved inferred ${factoryName} factory fails closed`, () => {
      assert.throws(() => inspectFixtureGlobals({
        'backend/src/unresolved-inferred.module.ts': `
          import { Module } from '@nestjs/common';
          declare function buildMetadata(): unknown;
          @Module({})
          export class UnresolvedInferredModule {
            static ${factoryName}() { return buildMetadata(); }
          }
        `,
      }), /DynamicModule|metadata|global/i);
    });
  }

  assert.doesNotThrow(() => inspectFixtureGlobals({
    'backend/src/unrelated-static.module.ts': `
      import { Module } from '@nestjs/common';
      declare function buildMetadata(): unknown;
      @Module({})
      export class UnrelatedStaticModule {
        static healthProbe() { return buildMetadata(); }
      }
    `,
    'backend/src/unrelated-class.ts': `
      declare function buildMetadata(): unknown;
      export class UnrelatedClass {
        static register() { return buildMetadata(); }
      }
    `,
  }));

  assert.throws(() => inspectFixtureGlobals({
    'backend/src/computed-factory.module.ts': `
      import { Module } from '@nestjs/common';
      const factoryName = 'register';
      declare function buildMetadata(): unknown;
      @Module({})
      export class ComputedFactoryModule {
        static [factoryName] = () => buildMetadata();
      }
    `,
  }), /DynamicModule|metadata|global/i);

  await t.test('unresolved inferred direct function-expression factory fails closed', () => {
    assert.throws(() => inspectFixtureGlobals({
      'backend/src/function-expression-factory.module.ts': `
        import { Module } from '@nestjs/common';
        declare function buildMetadata(): unknown;
        @Module({})
        export class FunctionExpressionFactoryModule {
          static register = function () { return buildMetadata(); };
        }
      `,
    }), /DynamicModule|metadata|global/i);
  });

  await t.test('unresolved inferred computed function-expression factory fails closed', () => {
    assert.throws(() => inspectFixtureGlobals({
      'backend/src/computed-function-expression-factory.module.ts': `
        import { Module } from '@nestjs/common';
        const factoryName = 'registerAsync';
        declare function buildMetadata(): unknown;
        @Module({})
        export class ComputedFunctionExpressionFactoryModule {
          static [factoryName] = function () { return buildMetadata(); };
        }
      `,
    }), /DynamicModule|metadata|global/i);
  });

  assert.doesNotThrow(() => inspectFixtureGlobals({
    'backend/src/finite-utility.module.ts': `
      import { Module } from '@nestjs/common';
      @Module({})
      export class FiniteUtilityModule {
        static register() { return { enabled: true }; }
      }
    `,
    'backend/src/non-callable-and-accessor.module.ts': `
      import { Module } from '@nestjs/common';
      declare function buildMetadata(): unknown;
      @Module({})
      export class NonCallableModule {
        static register = buildMetadata();
      }
      @Module({})
      export class AccessorModule {
        static get register() { return buildMetadata(); }
      }
      @Module({})
      export class FiniteFunctionExpressionModule {
        static register = function () { return { enabled: true }; };
      }
    `,
  }));
});

test('R8 rejects external DynamicModule factory global options and unresolved source options', async (t) => {
  const variants: Array<[string, string]> = [
    ['global literal', `{ global: true, useFactory: () => ({ secret: 'x' }) }`],
    ['isGlobal alias', `options`],
    ['spread', `{ ...activation, useFactory: () => ({ secret: 'x' }) }`],
    ['computed', `{ [key]: true, useFactory: () => ({ secret: 'x' }) }`],
  ];
  for (const [name, expression] of variants) {
    await t.test(name, () => {
      const declarations = name === 'isGlobal alias'
        ? `const options = { isGlobal: true, useFactory: () => ({ secret: 'x' }) };`
        : name === 'spread'
          ? `const activation = { global: true };`
          : name === 'computed'
            ? `const key = 'isGlobal' as const;`
            : '';
      assert.throws(() => inspectFixtureGlobals({
        'backend/src/external.ts': `
          import { Module } from '@nestjs/common';
          import { JwtModule } from '@nestjs/jwt';
          ${declarations}
          @Module({ imports: [JwtModule.registerAsync(${expression})] })
          export class ExternalModule {}
        `,
      }), /external|global|factory|option/i);
    });
  }

  await t.test('unresolved source options', () => {
    assert.throws(() => inspectFixtureGlobals({
      'backend/src/unresolved-external.ts': `
        import { Module } from '@nestjs/common';
        import { JwtModule } from '@nestjs/jwt';
        declare function options(): unknown;
        @Module({ imports: [JwtModule.registerAsync(options() as never)] })
        export class ExternalModule {}
      `,
    }), /external|metadata|option|resolve/i);
  });
});

test('R8 Prisma DI inspection distinguishes registered consumers from pure helpers', () => {
  const inspection = inspectPrismaFixture({
    'backend/src/consumer.ts': `
      import { PrismaService } from './platform/database/prisma.service';
      export class DirectConsumer { constructor(readonly prisma: PrismaService) {} }
      export function pureHelper(prisma: PrismaService): PrismaService { return prisma; }
    `,
    'backend/src/consumer.module.ts': `
      import { Module } from '@nestjs/common';
      import { PrismaModule } from './platform/database/prisma.module';
      import { DirectConsumer } from './consumer';
      @Module({ imports: [PrismaModule], providers: [DirectConsumer] })
      export class ConsumerModule {}
    `,
  });
  assert.deepEqual(inspection.importers, ['backend/src/consumer.module.ts']);
  assert.deepEqual(inspection.strictImporters, ['backend/src/consumer.module.ts']);
  assert.deepEqual(inspection.missingImporters, []);
  assert.equal(inspection.duplicateProviders, 0);

  const helperOnly = inspectPrismaFixture({
    'backend/src/helper.ts': `
      import { PrismaService } from './platform/database/prisma.service';
      export function pureHelper(prisma: PrismaService): PrismaService { return prisma; }
    `,
  });
  assert.deepEqual(helperOnly.strictImporters, []);
  assert.deepEqual(helperOnly.missingImporters, []);
});

test('R8 detects missing direct Prisma imports, including transitive and wrong-symbol decoys', async (t) => {
  await t.test('direct consumer without owner module import', () => {
    const result = inspectPrismaFixture({
      'backend/src/direct.ts': `
        import { PrismaService } from './platform/database/prisma.service';
        export class DirectConsumer { constructor(readonly prisma: PrismaService) {} }
      `,
      'backend/src/direct.module.ts': `
        import { Module } from '@nestjs/common';
        import { DirectConsumer } from './direct';
        @Module({ providers: [DirectConsumer] }) export class DirectModule {}
      `,
    });
    assert.deepEqual(result.missingImporters, ['backend/src/direct.module.ts']);
  });

  await t.test('transitive import does not satisfy the direct consumer', () => {
    const result = inspectPrismaFixture({
      'backend/src/transitive.module.ts': `
        import { Module } from '@nestjs/common';
        import { PrismaModule } from './platform/database/prisma.module';
        @Module({ imports: [PrismaModule] }) export class TransitiveModule {}
      `,
      'backend/src/transitive-consumer.ts': `
        import { PrismaService } from './platform/database/prisma.service';
        export class TransitiveConsumer { constructor(readonly prisma: PrismaService) {} }
      `,
      'backend/src/transitive-consumer.module.ts': `
        import { Module } from '@nestjs/common';
        import { TransitiveModule } from './transitive.module';
        import { TransitiveConsumer } from './transitive-consumer';
        @Module({ imports: [TransitiveModule], providers: [TransitiveConsumer] })
        export class TransitiveConsumerModule {}
      `,
    });
    assert.deepEqual(result.missingImporters, ['backend/src/transitive-consumer.module.ts']);
  });

  await t.test('same-name module from the wrong symbol does not satisfy the consumer', () => {
    const result = inspectPrismaFixture({
      'backend/src/decoy.module.ts': `export class PrismaModule {}`,
      'backend/src/decoy-consumer.ts': `
        import { PrismaService } from './platform/database/prisma.service';
        export class DecoyConsumer { constructor(readonly prisma: PrismaService) {} }
      `,
      'backend/src/decoy-consumer.module.ts': `
        import { Module } from '@nestjs/common';
        import { PrismaModule } from './decoy.module';
        import { DecoyConsumer } from './decoy-consumer';
        @Module({ imports: [PrismaModule], providers: [DecoyConsumer] })
        export class DecoyConsumerModule {}
      `,
    });
    assert.deepEqual(result.missingImporters, ['backend/src/decoy-consumer.module.ts']);
  });

  await t.test('factory inject array is a direct consumer', () => {
    const result = inspectPrismaFixture({
      'backend/src/factory.module.ts': `
        import { Module } from '@nestjs/common';
        import { PrismaService } from './platform/database/prisma.service';
        @Module({ providers: [{
          provide: 'FACTORY',
          useFactory: (prisma: PrismaService) => prisma,
          inject: [PrismaService],
        }] })
        export class FactoryModule {}
      `,
    });
    assert.deepEqual(result.missingImporters, ['backend/src/factory.module.ts']);
  });
});

test('R8 rejects protected Prisma provider replacement and construction bypasses', async (t) => {
  const variants: Array<[string, Record<string, string>]> = [
    ['duplicate provider', {
      'backend/src/duplicate.module.ts': `
        import { Module } from '@nestjs/common';
        import { PrismaService } from './platform/database/prisma.service';
        @Module({ providers: [PrismaService] }) export class DuplicateModule {}
      `,
    }],
    ['manual construction', {
      'backend/src/manual.ts': `
        import { PrismaService } from './platform/database/prisma.service';
        export const prisma = new PrismaService();
      `,
    }],
    ['useClass replacement', {
      'backend/src/use-class.module.ts': `
        import { Module } from '@nestjs/common';
        import { PrismaService } from './platform/database/prisma.service';
        class Replacement {}
        @Module({ providers: [{ provide: PrismaService, useClass: Replacement }] })
        export class UseClassModule {}
      `,
    }],
    ['factory replacement', {
      'backend/src/factory-replacement.module.ts': `
        import { Module } from '@nestjs/common';
        import { PrismaService } from './platform/database/prisma.service';
        @Module({ providers: [{ provide: PrismaService, useFactory: () => ({}) }] })
        export class FactoryReplacementModule {}
      `,
    }],
    ['value replacement', {
      'backend/src/value.module.ts': `
        import { Module } from '@nestjs/common';
        import { PrismaService } from './platform/database/prisma.service';
        @Module({ providers: [{ provide: PrismaService, useValue: {} }] })
        export class ValueModule {}
      `,
    }],
    ['subclass', {
      'backend/src/subclass.module.ts': `
        import { Module } from '@nestjs/common';
        import { PrismaService } from './platform/database/prisma.service';
        class PrismaSubclass extends PrismaService {}
        @Module({ providers: [PrismaSubclass] }) export class SubclassModule {}
      `,
    }],
    ['wrapper replacement', {
      'backend/src/wrapper.module.ts': `
        import { Module } from '@nestjs/common';
        import { PrismaService } from './platform/database/prisma.service';
        class PrismaWrapper { constructor(readonly inner: PrismaService) {} }
        @Module({ providers: [{ provide: PrismaService, useClass: PrismaWrapper }] })
        export class WrapperModule {}
      `,
    }],
    ['token lookalike', {
      'backend/src/lookalike.module.ts': `
        import { Module } from '@nestjs/common';
        @Module({ providers: [{ provide: 'PrismaService', useValue: {} }] })
        export class LookalikeModule {}
      `,
    }],
    ['Symbol token lookalike', {
      'backend/src/symbol-lookalike.module.ts': `
        import { Module } from '@nestjs/common';
        @Module({ providers: [{ provide: Symbol('PrismaService'), useValue: {} }] })
        export class SymbolLookalikeModule {}
      `,
    }],
    ['finite Symbol token lookalike', {
      'backend/src/finite-symbol-lookalike.module.ts': `
        import { Module } from '@nestjs/common';
        const prefix = 'Prisma';
        const description = prefix + 'Service';
        const token = Symbol(description);
        @Module({ providers: [{ provide: token, useValue: {} }] })
        export class FiniteSymbolLookalikeModule {}
      `,
    }],
  ];
  for (const [name, files] of variants) {
    await t.test(name, () => {
      assert.throws(() => inspectPrismaFixture(files), /Prisma|provider|construction|identity/i);
    });
  }

  assert.doesNotThrow(() => inspectPrismaFixture({
    'backend/src/unrelated-symbol.module.ts': `
      import { Module } from '@nestjs/common';
      @Module({ providers: [{ provide: Symbol('UnrelatedToken'), useValue: {} }] })
      export class UnrelatedSymbolModule {}
    `,
  }));
});

test('R8 Realtime composition keeps exactly two direct importers and two useExisting bindings', () => {
  const result = inspectRealtimeFixture();
  assert.deepEqual(result.importers, strictRealtimeImporters);
  assert.deepEqual(result.providerOwners, [
    'backend/src/conversations/conversation-realtime.module.ts#ConversationRealtimeModule',
  ]);
  assert.deepEqual(result.exportOwners, [
    'backend/src/conversations/conversation-realtime.module.ts#ConversationRealtimeModule',
  ]);
  assert.deepEqual(result.bindings, [
    'backend/src/modules/messaging/internal/messaging-realtime.internal.module.ts#MESSAGING_REALTIME_IMPLEMENTATION->ConversationRealtimePublisher',
    'backend/src/modules/messaging/public/messaging-realtime-public.module.ts#MESSAGING_REALTIME_PORT->MESSAGING_REALTIME_IMPLEMENTATION',
  ]);
  assert.equal(result.duplicateProviders, 0);
});

test('R8 rejects changed or duplicated Messaging bindings and concrete cross-context imports', async (t) => {
  const changedInternal = `
    import { Module } from '@nestjs/common';
    import { ConversationRealtimeModule } from '../../../conversations/conversation-realtime.module';
    import { ConversationRealtimePublisher } from '../../../conversations/conversation-realtime.publisher';
    import { MESSAGING_REALTIME_IMPLEMENTATION } from './messaging-realtime.implementation-token';
    @Module({
      imports: [ConversationRealtimeModule],
      providers: [{ provide: MESSAGING_REALTIME_IMPLEMENTATION, useClass: ConversationRealtimePublisher }],
      exports: [MESSAGING_REALTIME_IMPLEMENTATION],
    }) export class MessagingRealtimeInternalModule {}
  `;
  const duplicatedPublic = `
    import { Module } from '@nestjs/common';
    import { MessagingRealtimeInternalModule } from '../internal/messaging-realtime.internal.module';
    import { MESSAGING_REALTIME_IMPLEMENTATION } from '../internal/messaging-realtime.implementation-token';
    import { MESSAGING_REALTIME_PORT } from './messaging-realtime.port';
    @Module({
      imports: [MessagingRealtimeInternalModule],
      providers: [
        { provide: MESSAGING_REALTIME_PORT, useExisting: MESSAGING_REALTIME_IMPLEMENTATION },
        { provide: MESSAGING_REALTIME_PORT, useExisting: MESSAGING_REALTIME_IMPLEMENTATION },
      ],
      exports: [MESSAGING_REALTIME_PORT],
    }) export class MessagingRealtimePublicModule {}
  `;
  const variants: Array<[string, Record<string, string>]> = [
    ['changed internal binding', {
      'backend/src/modules/messaging/internal/messaging-realtime.internal.module.ts': changedInternal,
    }],
    ['duplicated public binding', {
      'backend/src/modules/messaging/public/messaging-realtime-public.module.ts': duplicatedPublic,
    }],
    ['cross-context concrete import', {
      'backend/src/modules/tasks/internal/foreign.ts': `
        import { ConversationRealtimePublisher } from '../../../conversations/conversation-realtime.publisher';
        export class ForeignConsumer { constructor(readonly realtime: ConversationRealtimePublisher) {} }
      `,
    }],
    ['cross-context namespace publisher reference', {
      'backend/src/modules/tasks/internal/namespace-foreign.ts': `
        import * as Conversations from '../../../conversations/conversation-realtime.publisher';
        export const realtime = Conversations.ConversationRealtimePublisher;
      `,
    }],
    ['cross-context default publisher reference', {
      'backend/src/conversations/conversation-realtime.publisher.ts': `
        export class ConversationRealtimePublisher {}
        export default ConversationRealtimePublisher;
      `,
      'backend/src/modules/tasks/internal/default-foreign.ts': `
        import Publisher from '../../../conversations/conversation-realtime.publisher';
        export const realtime = Publisher;
      `,
    }],
    ['cross-context import-equals publisher reference', {
      'backend/src/modules/tasks/internal/import-equals-foreign.ts': `
        import Conversations = require('../../../conversations/conversation-realtime.publisher');
        export const realtime = Conversations.ConversationRealtimePublisher;
      `,
    }],
  ];
  for (const [name, files] of variants) {
    await t.test(name, () => {
      assert.throws(() => inspectRealtimeFixture(files), /Realtime|publisher|binding|cross-context|useExisting/i);
    });
  }
});

test('R8 rejects publisher duplication, manual construction, replacement, subclass, wrapper, and token lookalikes', async (t) => {
  const variants: Array<[string, Record<string, string>]> = [
    ['duplicate provider', {
      'backend/src/modules/messaging/internal/duplicate.module.ts': `
        import { Module } from '@nestjs/common';
        import { ConversationRealtimePublisher } from '../../../conversations/conversation-realtime.publisher';
        @Module({ providers: [ConversationRealtimePublisher] }) export class DuplicateModule {}
      `,
    }],
    ['manual construction', {
      'backend/src/conversations/manual.ts': `
        import { ConversationRealtimePublisher } from './conversation-realtime.publisher';
        export const realtime = new ConversationRealtimePublisher();
      `,
    }],
    ['useValue replacement', {
      'backend/src/modules/messaging/internal/value.module.ts': `
        import { Module } from '@nestjs/common';
        import { ConversationRealtimePublisher } from '../../../conversations/conversation-realtime.publisher';
        @Module({ providers: [{ provide: ConversationRealtimePublisher, useValue: {} }] })
        export class ValueModule {}
      `,
    }],
    ['subclass', {
      'backend/src/modules/messaging/internal/subclass.module.ts': `
        import { Module } from '@nestjs/common';
        import { ConversationRealtimePublisher } from '../../../conversations/conversation-realtime.publisher';
        class PublisherSubclass extends ConversationRealtimePublisher {}
        @Module({ providers: [PublisherSubclass] }) export class SubclassModule {}
      `,
    }],
    ['wrapper replacement', {
      'backend/src/modules/messaging/internal/wrapper.module.ts': `
        import { Module } from '@nestjs/common';
        import { ConversationRealtimePublisher } from '../../../conversations/conversation-realtime.publisher';
        class PublisherWrapper { constructor(readonly inner: ConversationRealtimePublisher) {} }
        @Module({ providers: [{ provide: ConversationRealtimePublisher, useClass: PublisherWrapper }] })
        export class WrapperModule {}
      `,
    }],
    ['token lookalike', {
      'backend/src/modules/messaging/internal/lookalike.module.ts': `
        import { Module } from '@nestjs/common';
        @Module({ providers: [{ provide: 'ConversationRealtimePublisher', useValue: {} }] })
        export class LookalikeModule {}
      `,
    }],
    ['Symbol token lookalike', {
      'backend/src/modules/messaging/internal/symbol-lookalike.module.ts': `
        import { Module } from '@nestjs/common';
        @Module({ providers: [{ provide: Symbol('ConversationRealtimePublisher'), useValue: {} }] })
        export class SymbolLookalikeModule {}
      `,
    }],
    ['finite Symbol token lookalike', {
      'backend/src/modules/messaging/internal/finite-symbol-lookalike.module.ts': `
        import { Module } from '@nestjs/common';
        const prefix = 'ConversationRealtime';
        const description = prefix + 'Publisher';
        const token = Symbol(description);
        @Module({ providers: [{ provide: token, useValue: {} }] })
        export class FiniteSymbolLookalikeModule {}
      `,
    }],
  ];
  for (const [name, files] of variants) {
    await t.test(name, () => {
      assert.throws(() => inspectRealtimeFixture(files), /Realtime|publisher|provider|construction|identity/i);
    });
  }

  assert.doesNotThrow(() => inspectRealtimeFixture({
    'backend/src/modules/messaging/internal/unrelated-symbol.module.ts': `
      import { Module } from '@nestjs/common';
      @Module({ providers: [{ provide: Symbol('UnrelatedToken'), useValue: {} }] })
      export class UnrelatedSymbolModule {}
    `,
  }));
});

test('R8 manifest rejects every external identity drift and any broad dependency exception', () => {
  const r8 = scanner();
  const mutations: R8Manifest[] = [];
  const fields: Array<[keyof R8Manifest['externalGlobalIdentities'][number], unknown]> = [
    ['packageName', '@attacker/schedule'],
    ['declaredRange', '*'],
    ['lockedVersion', '0.0.0'],
    ['resolved', 'file:../schedule'],
    ['integrity', 'sha512-attacker'],
    ['importedClass', 'AttackerModule'],
    ['factoryMethod', 'register'],
    ['sourcePath', 'backend/src/attacker.module.ts'],
    ['callCount', 2],
    ['installedEntrypoint', 'node_modules/index.js'],
    ['globalMechanism', 'generic-node_modules-exception'],
  ];
  for (const [field, replacement] of fields) {
    const mutation = structuredClone(manifestWithContract());
    (mutation.externalGlobalIdentities[0] as Record<string, unknown>)[field] = replacement;
    mutations.push(mutation);
  }
  const third = structuredClone(manifestWithContract());
  third.externalGlobalIdentities.push(structuredClone(third.externalGlobalIdentities[0]));
  mutations.push(third);
  const generic = structuredClone(manifestWithContract()) as R8Manifest & { allowNodeModules?: string };
  generic.allowNodeModules = 'node_modules/**';
  mutations.push(generic);

  for (const mutation of mutations) {
    assert.throws(
      () => r8.validateR8Manifest(mutation),
      /R8|external|identity|key|schema/i,
    );
  }
});

test('R8 external verifier rejects package declaration and complete lock identity drift', async (t) => {
  const mutations: Array<[
    string,
    (packageJson: Record<string, any>, packageLock: Record<string, any>) => void,
  ]> = [
    ['declared range', (packageJson) => {
      packageJson.dependencies['@nestjs/schedule'] = '*';
    }],
    ['root lock range', (_packageJson, packageLock) => {
      packageLock.packages[''].dependencies['@nestjs/throttler'] = '*';
    }],
    ['locked version', (_packageJson, packageLock) => {
      packageLock.packages['node_modules/@nestjs/schedule'].version = '0.0.0';
    }],
    ['resolved tarball', (_packageJson, packageLock) => {
      packageLock.packages['node_modules/@nestjs/throttler'].resolved = 'file:../throttler';
    }],
    ['integrity', (_packageJson, packageLock) => {
      packageLock.packages['node_modules/@nestjs/schedule'].integrity = 'sha512-attacker';
    }],
    ['linked package', (_packageJson, packageLock) => {
      packageLock.packages['node_modules/@nestjs/throttler'].link = true;
    }],
  ];
  for (const [name, mutate] of mutations) {
    await t.test(name, () => {
      const root = externalFixture();
      const packagePath = path.join(root, 'backend', 'package.json');
      const lockPath = path.join(root, 'backend', 'package-lock.json');
      const packageJson = JSON.parse(readFileSync(packagePath, 'utf8'));
      const packageLock = JSON.parse(readFileSync(lockPath, 'utf8'));
      mutate(packageJson, packageLock);
      writeFileSync(packagePath, JSON.stringify(packageJson), 'utf8');
      writeFileSync(lockPath, JSON.stringify(packageLock), 'utf8');
      assertR8Failure(
        () => scanner().verifyExternalGlobalIdentities(root, manifestWithContract()),
        /external|package|lock|identity/i,
      );
    });
  }
});

test('R8 external verifier requires the exact locked installed entrypoint', async (t) => {
  const variants: Array<[string, Record<string, unknown>]> = [
    ['main', { main: './dist/alternate.js' }],
    ['exports', {
      main: './dist/index.js',
      exports: { '.': './dist/alternate.js', './dist/index.js': './dist/index.js' },
    }],
  ];
  for (const [name, entrypointFields] of variants) {
    await t.test(name, () => {
      const root = externalFixture();
      const packageRoot = 'backend/node_modules/@nestjs/schedule';
      const runtime = `
        class ScheduleModule {
          static forRoot() { return { global: true }; }
        }
        module.exports = { ScheduleModule };
      `;
      writeFixtureFile(root, `${packageRoot}/package.json`, JSON.stringify({
        name: '@nestjs/schedule',
        version: '6.1.3',
        types: './index.d.ts',
        ...entrypointFields,
      }));
      writeFixtureFile(root, `${packageRoot}/index.d.ts`, `
        export declare class ScheduleModule {
          static forRoot(): { global: true };
        }
      `);
      writeFixtureFile(root, `${packageRoot}/dist/index.js`, runtime);
      writeFixtureFile(root, `${packageRoot}/dist/alternate.js`, `
        module.exports = require('./index.js');
      `);
      assertR8Failure(
        () => scanner().verifyExternalGlobalIdentities(root, manifestWithContract()),
        /external|installed|entrypoint|identity|Schedule/i,
      );
    });
  }
});

test('R8 external verifier accepts only the locked Schedule root forwarding shim', () => {
  const root = externalFixture();
  const packageRoot = 'backend/node_modules/@nestjs/schedule';
  const runtime = `
    class ScheduleModule {
      static forRoot() { return { global: true }; }
    }
    module.exports = { ScheduleModule };
  `;
  writeFixtureFile(root, `${packageRoot}/package.json`, JSON.stringify({
    name: '@nestjs/schedule',
    version: '6.1.3',
    types: './index.d.ts',
  }));
  writeFixtureFile(root, `${packageRoot}/index.d.ts`, `
    export declare class ScheduleModule {
      static forRoot(): { global: true };
    }
  `);
  writeFixtureFile(root, `${packageRoot}/index.js`, readFileSync(
    path.join(backendRoot, 'node_modules', '@nestjs', 'schedule', 'index.js'),
    'utf8',
  ));
  writeFixtureFile(root, `${packageRoot}/dist/index.js`, runtime);
  assert.doesNotThrow(() => scanner().verifyExternalGlobalIdentities(root, manifestWithContract()));
});

test('R8 external verifier rejects a forwarding Throttler root entrypoint', () => {
  const root = externalFixture();
  const packageRoot = 'backend/node_modules/@nestjs/throttler';
  const runtime = `
    require('reflect-metadata');
    const { GLOBAL_MODULE_METADATA } = require('@nestjs/common/constants');
    class ThrottlerModule {
      static forRootAsync() { return {}; }
    }
    Reflect.defineMetadata(GLOBAL_MODULE_METADATA, true, ThrottlerModule);
    module.exports = { ThrottlerModule };
  `;
  writeFixtureFile(root, `${packageRoot}/package.json`, JSON.stringify({
    name: '@nestjs/throttler',
    version: expectedExternalIdentities[1].lockedVersion,
    main: './dist/alternate.js',
    types: './index.d.ts',
  }));
  writeFixtureFile(root, `${packageRoot}/index.d.ts`, `
    export declare class ThrottlerModule {
      static forRootAsync(): unknown;
    }
  `);
  writeFixtureFile(root, `${packageRoot}/dist/index.js`, runtime);
  writeFixtureFile(root, `${packageRoot}/dist/alternate.js`, `
    module.exports = require('./index.js');
  `);
  assertR8Failure(
    () => scanner().verifyExternalGlobalIdentities(root, manifestWithContract()),
    /external|installed|entrypoint|identity/i,
  );
});

test('R8 external verifier rejects imported class, method, source path, and call-count drift', async (t) => {
  const variants: Array<[string, (source: string) => string]> = [
    ['imported class', (source) => source
      .replace('import { ScheduleModule } from "@nestjs/schedule";', 'import { SchedulerRegistry } from "@nestjs/schedule";')
      .replace('ScheduleModule.forRoot()', 'SchedulerRegistry.forRoot()')],
    ['factory method', (source) => source.replace('ScheduleModule.forRoot()', 'ScheduleModule.forRootAsync({})')],
    ['missing call', (source) => source.replace('ScheduleModule.forRoot(),', '')],
    ['duplicate call', (source) => source.replace('ScheduleModule.forRoot(),', 'ScheduleModule.forRoot(), ScheduleModule.forRoot(),')],
  ];
  for (const [name, mutate] of variants) {
    await t.test(name, () => {
      const root = externalFixture();
      const appPath = path.join(root, 'backend', 'src', 'app.module.ts');
      writeFileSync(appPath, mutate(readFileSync(appPath, 'utf8')), 'utf8');
      assertR8Failure(
        () => scanner().verifyExternalGlobalIdentities(root, manifestWithContract()),
        /external|call|class|method|identity/i,
      );
    });
  }

  await t.test('canonical source path is required', () => {
    const root = externalFixture();
    const source = readFileSync(path.join(root, 'backend', 'src', 'app.module.ts'), 'utf8');
    rmSync(path.join(root, 'backend', 'src', 'app.module.ts'));
    writeFixtureFile(root, 'backend/src/renamed.module.ts', source);
    assertR8Failure(
      () => scanner().verifyExternalGlobalIdentities(root, manifestWithContract()),
      /external|source|identity|app/i,
    );
  });
});

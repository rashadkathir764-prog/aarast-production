import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import {
  mkdirSync,
  mkdtempSync,
  rmSync,
  writeFileSync,
} from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { afterEach, test } from 'node:test';

type DiagnosticKind =
  | 'forward-ref'
  | 'unapproved-global'
  | 'missing-r0-global'
  | 'non-public-cross-module-import'
  | 'domain-runtime-import'
  | 'platform-business-import'
  | 'shared-kernel-direction-import'
  | 'nest-module-cycle'
  | 'unresolved-module-import';

type ArchitectureDiagnostic = {
  kind: DiagnosticKind;
  path: string;
  line: number;
  message: string;
  cycle?: string;
};

type ScanResult = {
  diagnostics: ArchitectureDiagnostic[];
  counts: {
    forwardRef: number;
    globals: number;
    illegalFutureImports: number;
    nestModuleCycles: number;
  };
};

type ScanOptions = { repoRoot: string; backendRoot: string };
type CliDependencies = {
  argv: string[];
  scan: () => ScanResult;
  stdout: (message: string) => void;
  stderr: (message: string) => void;
};

const {
  scanPorts,
  runCli,
} = require('../scripts/architecture/ports-scan.cjs') as {
  scanPorts: (options: ScanOptions) => ScanResult;
  runCli: (dependencies: CliDependencies) => number;
};

const backendRoot = path.resolve(__dirname, '..');
const repoRoot = path.resolve(backendRoot, '..');
const temporaryRoots: string[] = [];

function write(root: string, relativePath: string, content: string) {
  const target = path.join(root, relativePath);
  mkdirSync(path.dirname(target), { recursive: true });
  writeFileSync(target, content, 'utf8');
}

function nestImports(style: 'direct' | 'alias' | 'namespace') {
  if (style === 'direct') {
    return { importLine: "import { Global, Module } from '@nestjs/common';", global: 'Global', module: 'Module' };
  }
  if (style === 'alias') {
    return {
      importLine: "import { Global as NestGlobal, Module as NestModule } from '@nestjs/common';",
      global: 'NestGlobal',
      module: 'NestModule',
    };
  }
  return {
    importLine: "import * as Nest from '@nestjs/common';",
    global: 'Nest.Global',
    module: 'Nest.Module',
  };
}

function globalModule(style: 'direct' | 'alias' | 'namespace', className: string, includeGlobal = true) {
  const names = nestImports(style);
  return `${names.importLine}\n${includeGlobal ? `@${names.global}()\n` : ''}@${names.module}({})\nexport class ${className} {}\n`;
}

function fixtureProject(
  files: Record<string, string>,
  options: {
    globalStyle?: 'direct' | 'alias' | 'namespace';
    omitGlobalDecoratorFrom?: string;
    includeGlobals?: boolean;
  } = {},
): ScanOptions {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-ports-'));
  temporaryRoots.push(root);
  const fixtureBackend = path.join(root, 'backend');
  write(root, 'backend/tsconfig.json', `${JSON.stringify({
    compilerOptions: {
      module: 'commonjs',
      moduleResolution: 'node',
      target: 'ES2022',
      experimentalDecorators: true,
      strict: false,
      skipLibCheck: true,
    },
    include: ['src/**/*.ts'],
  }, null, 2)}\n`);
  write(root, 'backend/node_modules/@nestjs/common/index.d.ts', [
    'export declare function Global(): ClassDecorator;',
    'export declare function Module(metadata: any): ClassDecorator;',
    'export declare function forwardRef(callback: () => unknown): unknown;',
  ].join('\n'));
  write(root, 'backend/node_modules/@nestjs/schedule/index.d.ts', [
    'export declare class ScheduleModule {',
    '  static forRoot(): unknown;',
    '}',
  ].join('\n'));
  write(root, 'backend/node_modules/@nestjs/jwt/index.d.ts', [
    'export declare class JwtModule {',
    '  static registerAsync(options: unknown): unknown;',
    '}',
  ].join('\n'));
  if (options.includeGlobals !== false) {
    const style = options.globalStyle || 'direct';
    const prismaPath = 'backend/src/prisma/prisma.module.ts';
    const realtimePath = 'backend/src/conversations/conversation-realtime.module.ts';
    write(root, prismaPath, globalModule(style, 'PrismaModule', options.omitGlobalDecoratorFrom !== prismaPath));
    write(root, realtimePath, globalModule(
      style,
      'ConversationRealtimeModule',
      options.omitGlobalDecoratorFrom !== realtimePath,
    ));
  }
  for (const [relativePath, content] of Object.entries(files)) write(root, relativePath, content);
  return { repoRoot: root, backendRoot: fixtureBackend };
}

function diagnosticsOfKind(result: ScanResult, kind: DiagnosticKind) {
  return result.diagnostics.filter((diagnostic) => diagnostic.kind === kind);
}

function scanSingle(files: Record<string, string>, kind: DiagnosticKind) {
  return diagnosticsOfKind(scanPorts(fixtureProject(files)), kind);
}

afterEach(() => {
  for (const root of temporaryRoots.splice(0)) rmSync(root, { recursive: true, force: true });
});

test('forwardRef is forbidden through direct, aliased, and namespace imports', () => {
  const fixtures: string[] = [
    "import { forwardRef } from '@nestjs/common';\nforwardRef(() => class Target {});\n",
    "import { forwardRef as nestForwardRef } from '@nestjs/common';\nnestForwardRef(() => class Target {});\n",
    "import * as Nest from '@nestjs/common';\nNest.forwardRef(() => class Target {});\n",
  ];
  for (const source of fixtures) {
    const diagnostics = scanSingle({ 'backend/src/tasks/forward.ts': source }, 'forward-ref');
    assert.equal(diagnostics.length, 1);
    assert.equal(diagnostics[0].path, 'backend/src/tasks/forward.ts');
    assert.match(diagnostics[0].message, /@nestjs\/common/);
  }
});

test('forwardRef const initializer alias chains are forbidden without homonym false positives', () => {
  const fixtures: Record<string, string>[] = [
    {
      'backend/src/tasks/hidden-forward.ts': [
        "import { forwardRef } from '@nestjs/common';",
        'const first = forwardRef;',
        'const hiddenForward = first;',
        'hiddenForward(() => class Target {});',
      ].join('\n'),
    },
    {
      'backend/src/tasks/hidden-forward.ts': [
        "import * as Nest from '@nestjs/common';",
        'const first = Nest.forwardRef;',
        'const hiddenForward = first;',
        'hiddenForward(() => class Target {});',
      ].join('\n'),
    },
    {
      'backend/src/tasks/nest-barrel.ts': "export { forwardRef } from '@nestjs/common';\n",
      'backend/src/tasks/hidden-forward.ts': [
        "import { forwardRef as importedForward } from './nest-barrel';",
        'const first = importedForward;',
        'const hiddenForward = first;',
        'hiddenForward(() => class Target {});',
      ].join('\n'),
    },
  ];
  for (const files of fixtures) {
    const hidden = scanPorts(fixtureProject(files));
    assert.equal(diagnosticsOfKind(hidden, 'forward-ref').length, 1);
  }

  const local = scanPorts(fixtureProject({
    'backend/src/tasks/local-forward.ts': [
      'const forwardRef = (callback: () => unknown) => callback();',
      'const first = forwardRef;',
      'const hiddenForward = first;',
      'hiddenForward(() => class Target {});',
      'const cycleA = cycleB;',
      'const cycleB = cycleA;',
      'void cycleA;',
    ].join('\n'),
  }));
  assert.equal(diagnosticsOfKind(local, 'forward-ref').length, 0);
});

test('the R0 global set is exact for direct, aliased, and namespace decorators', () => {
  const allowed = [
    'backend/src/prisma/prisma.module.ts',
    'backend/src/conversations/conversation-realtime.module.ts',
  ];
  for (const style of ['direct', 'alias', 'namespace'] as const) {
    const passing = scanPorts(fixtureProject({}, { globalStyle: style }));
    assert.deepEqual(passing.diagnostics, []);
    assert.equal(passing.counts.globals, 2);

    const names = nestImports(style);
    const rogue = scanPorts(fixtureProject({
      'backend/src/auth/rogue-global.module.ts': `${names.importLine}\n@${names.global}()\n@${names.module}({})\nexport class RogueGlobalModule {}\n`,
    }, { globalStyle: style }));
    assert.deepEqual(diagnosticsOfKind(rogue, 'unapproved-global').map((item) => item.path), [
      'backend/src/auth/rogue-global.module.ts',
    ]);

    for (const missing of allowed) {
      const result = scanPorts(fixtureProject({}, {
        globalStyle: style,
        omitGlobalDecoratorFrom: missing,
      }));
      assert.deepEqual(diagnosticsOfKind(result, 'missing-r0-global').map((item) => item.path), [missing]);
    }
  }
});

test('Global const initializer alias chains preserve the exact R0 allowlist', () => {
  const result = scanPorts(fixtureProject({
    'backend/src/prisma/prisma.module.ts': [
      "import * as Nest from '@nestjs/common';",
      'const first = Nest.Global;',
      'const hiddenGlobal = first;',
      '@hiddenGlobal()',
      '@Nest.Module({})',
      'export class PrismaModule {}',
    ].join('\n'),
    'backend/src/conversations/nest-barrel.ts': "export { Global, Module } from '@nestjs/common';\n",
    'backend/src/conversations/conversation-realtime.module.ts': [
      "import { Global, Module } from './nest-barrel';",
      'const hiddenGlobal = Global;',
      '@hiddenGlobal()',
      '@Module({})',
      'export class ConversationRealtimeModule {}',
    ].join('\n'),
  }, { includeGlobals: false }));
  assert.deepEqual(result.diagnostics, []);
  assert.equal(result.counts.globals, 2);

  const rogue = scanPorts(fixtureProject({
    'backend/src/auth/hidden-global.module.ts': [
      "import { Global, Module } from '@nestjs/common';",
      'const hiddenGlobal = Global;',
      '@hiddenGlobal()',
      '@Module({})',
      'export class HiddenGlobalModule {}',
    ].join('\n'),
  }));
  assert.deepEqual(diagnosticsOfKind(rogue, 'unapproved-global').map((item) => item.path), [
    'backend/src/auth/hidden-global.module.ts',
  ]);
});

test('future modules import another context through public only', () => {
  const internal = scanSingle({
    'backend/src/modules/tasks/application/use-case.ts': "import '../../guests/internal/guest.service';\n",
    'backend/src/modules/guests/internal/guest.service.ts': 'export const guest = true;\n',
  }, 'non-public-cross-module-import');
  assert.equal(internal.length, 1);
  assert.equal(internal[0].path, 'backend/src/modules/tasks/application/use-case.ts');

  const publicResult = scanPorts(fixtureProject({
    'backend/src/modules/tasks/application/use-case.ts': "import '../../guests/public/guest.port';\n",
    'backend/src/modules/guests/public/guest.port.ts': 'export const guestPort = true;\n',
  }));
  assert.deepEqual(publicResult.diagnostics, []);
});

test('mixed legacy and future business boundaries are closed without reporting legacy-only debt', () => {
  const cases: Array<{ files: Record<string, string>; expected: number }> = [
    {
      files: {
        'backend/src/modules/tasks/application/use.ts': "import '../../../guests/legacy';\n",
        'backend/src/guests/legacy.ts': 'export const guest = true;\n',
      },
      expected: 1,
    },
    {
      files: {
        'backend/src/tasks/use.ts': "import '../modules/guests/internal/secret';\n",
        'backend/src/modules/guests/internal/secret.ts': 'export const secret = true;\n',
      },
      expected: 1,
    },
    {
      files: {
        'backend/src/tasks/use.ts': "import '../modules/guests/public/guest.port';\n",
        'backend/src/modules/guests/public/guest.port.ts': 'export const guestPort = true;\n',
      },
      expected: 0,
    },
    {
      files: {
        'backend/src/tasks/use.ts': "import '../guests/legacy';\n",
        'backend/src/guests/legacy.ts': 'export const guest = true;\n',
      },
      expected: 0,
    },
  ];
  for (const fixture of cases) {
    const result = scanPorts(fixtureProject(fixture.files));
    assert.equal(diagnosticsOfKind(result, 'non-public-cross-module-import').length, fixture.expected);
  }
});

test('legacy and future platform code cannot reach future business modules and future platform cannot reach legacy business', () => {
  const cases = [
    {
      source: 'backend/src/common/use.ts',
      importLine: "import '../modules/tasks/public/task.port';\n",
      target: 'backend/src/modules/tasks/public/task.port.ts',
    },
    {
      source: 'backend/src/platform/use.ts',
      importLine: "import '../modules/tasks/public/task.port';\n",
      target: 'backend/src/modules/tasks/public/task.port.ts',
    },
    {
      source: 'backend/src/platform/use.ts',
      importLine: "import '../guests/legacy';\n",
      target: 'backend/src/guests/legacy.ts',
    },
  ];
  for (const fixture of cases) {
    const result = scanPorts(fixtureProject({
      [fixture.source]: fixture.importLine,
      [fixture.target]: 'export const value = true;\n',
    }));
    assert.equal(diagnosticsOfKind(result, 'platform-business-import').length, 1);
  }
});

test('future domain code cannot import Nest runtime, PrismaService, or another business module', () => {
  const nest = scanSingle({
    'backend/src/modules/tasks/domain/nest.ts': "import { Module } from '@nestjs/common';\nexport const value = Module;\n",
  }, 'domain-runtime-import');
  assert.equal(nest.length, 1);

  const prisma = scanSingle({
    'backend/src/modules/tasks/domain/prisma.ts': "import { PrismaService } from '../../../prisma/prisma.service';\nexport type Value = PrismaService;\n",
    'backend/src/prisma/prisma.service.ts': 'export class PrismaService {}\n',
  }, 'domain-runtime-import');
  assert.equal(prisma.length, 1);

  const foreign = scanSingle({
    'backend/src/modules/tasks/domain/foreign.ts': "import '../../guests/public/guest.port';\n",
    'backend/src/modules/guests/public/guest.port.ts': 'export const guestPort = true;\n',
  }, 'domain-runtime-import');
  assert.equal(foreign.length, 1);
});

test('future domain code traces PrismaService through named and namespace barrel imports', () => {
  const cases: Array<{ name: string; files: Record<string, string>; source: string }> = [
    {
      name: 'named import',
      source: 'backend/src/modules/tasks/domain/named-prisma.ts',
      files: {
        'backend/src/modules/tasks/domain/named-prisma.ts': "import { PrismaService } from '../../../prisma';\nexport type Database = PrismaService;\n",
        'backend/src/prisma/index.ts': "export { PrismaService } from './prisma.service';\n",
        'backend/src/prisma/prisma.service.ts': 'export class PrismaService {}\n',
      },
    },
    {
      name: 'namespace import',
      source: 'backend/src/modules/tasks/domain/namespace-prisma.ts',
      files: {
        'backend/src/modules/tasks/domain/namespace-prisma.ts': "import * as Database from '../../../prisma';\nexport type DatabaseService = typeof Database.PrismaService;\n",
        'backend/src/prisma/index.ts': "export { PrismaService } from './prisma.service';\n",
        'backend/src/prisma/prisma.service.ts': 'export class PrismaService {}\n',
      },
    },
  ];
  for (const fixture of cases) {
    const diagnostics = diagnosticsOfKind(scanPorts(fixtureProject(fixture.files)), 'domain-runtime-import');
    assert.equal(diagnostics.length, 1, fixture.name);
    assert.equal(diagnostics[0].path, fixture.source, fixture.name);
  }
});

test('future domain code traces named aliased and namespace Nest runtime imports through local barrels', () => {
  const cases: Array<{ name: string; files: Record<string, string>; source: string }> = [
    {
      name: 'named aliased import',
      source: 'backend/src/modules/tasks/domain/named-nest.ts',
      files: {
        'backend/src/modules/tasks/domain/named-nest.ts': "import { NestRuntime as Runtime } from '../../../runtime';\nexport const decorator = Runtime;\n",
        'backend/src/runtime/index.ts': "export { Module as NestRuntime } from '@nestjs/common';\n",
      },
    },
    {
      name: 'namespace import',
      source: 'backend/src/modules/tasks/domain/namespace-nest.ts',
      files: {
        'backend/src/modules/tasks/domain/namespace-nest.ts': "import * as Runtime from '../../../runtime';\nexport const decorator = Runtime.Module;\n",
        'backend/src/runtime/index.ts': "export * from '@nestjs/common';\n",
      },
    },
  ];
  for (const fixture of cases) {
    const diagnostics = diagnosticsOfKind(scanPorts(fixtureProject(fixture.files)), 'domain-runtime-import');
    assert.equal(diagnostics.length, 1, fixture.name);
    assert.equal(diagnostics[0].path, fixture.source, fixture.name);
  }
});

test('future domain code traces forbidden runtime provenance through transitive re-export chains', () => {
  const source = 'backend/src/modules/tasks/domain/transitive-runtime.ts';
  const result = scanPorts(fixtureProject({
    [source]: "import * as Runtime from '../../../runtime';\nexport const decorator = Runtime.Module;\n",
    'backend/src/runtime/index.ts': "export * from './public';\n",
    'backend/src/runtime/public.ts': "export * from './nest-runtime';\n",
    'backend/src/runtime/nest-runtime.ts': "export { Module } from '@nestjs/common';\n",
  }));
  const diagnostics = diagnosticsOfKind(result, 'domain-runtime-import');
  assert.equal(diagnostics.length, 1);
  assert.equal(diagnostics[0].path, source);
});

test('future domain code does not reject innocent local runtime homonyms', () => {
  const result = scanPorts(fixtureProject({
    'backend/src/modules/tasks/domain/innocent-consumer.ts': "import * as Runtime from './innocent-runtime';\nexport const values = [Runtime.PrismaService, Runtime.NestModule];\n",
    'backend/src/modules/tasks/domain/innocent-runtime.ts': 'export class PrismaService {}\nexport class NestModule {}\n',
  }));
  assert.equal(diagnosticsOfKind(result, 'domain-runtime-import').length, 0);
});

test('public and unclassified code cannot import another future module internal slice', () => {
  const publicSource = scanSingle({
    'backend/src/modules/tasks/public/task.port.ts': "import '../../guests/internal/secret';\n",
    'backend/src/modules/guests/internal/secret.ts': 'export const secret = true;\n',
  }, 'non-public-cross-module-import');
  assert.equal(publicSource.length, 1);

  const unclassifiedSource = scanSingle({
    'backend/src/bootstrap/use.ts': "import '../modules/guests/internal/secret';\n",
    'backend/src/modules/guests/internal/secret.ts': 'export const secret = true;\n',
  }, 'non-public-cross-module-import');
  assert.equal(unclassifiedSource.length, 1);
});

test('shared-kernel remains foundational', () => {
  const result = scanPorts(fixtureProject({
    'backend/src/shared-kernel/use.ts': "import '../modules/tasks/public/task.port';\n",
    'backend/src/modules/tasks/public/task.port.ts': 'export const taskPort = true;\n',
  }));
  assert.equal(diagnosticsOfKind(result, 'shared-kernel-direction-import').length, 1);
});

test('the live Nest module import graph is acyclic and cycles are normalized', () => {
  const live = scanPorts({ repoRoot, backendRoot });
  assert.deepEqual(live.diagnostics, []);

  const cycle = scanPorts(fixtureProject({
    'backend/src/cycle/a.module.ts': "import { Module } from '@nestjs/common';\nimport { BModule } from './b.module';\n@Module({ imports: [BModule] })\nexport class AModule {}\n",
    'backend/src/cycle/b.module.ts': "import { Module } from '@nestjs/common';\nimport { CModule } from './c.module';\n@Module({ imports: [CModule] })\nexport class BModule {}\n",
    'backend/src/cycle/c.module.ts': "import { Module } from '@nestjs/common';\nimport { AModule } from './a.module';\n@Module({ imports: [AModule] })\nexport class CModule {}\n",
  }));
  const diagnostics = diagnosticsOfKind(cycle, 'nest-module-cycle');
  assert.equal(diagnostics.length, 1);
  assert.equal(
    diagnostics[0].cycle,
    'backend/src/cycle/a.module.ts -> backend/src/cycle/b.module.ts -> backend/src/cycle/c.module.ts -> backend/src/cycle/a.module.ts',
  );
});

test('external dynamic modules are leaves', () => {
  const result = scanPorts(fixtureProject({
    'backend/src/external/app.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { ScheduleModule } from '@nestjs/schedule';",
      "import { JwtModule } from '@nestjs/jwt';",
      '@Module({ imports: [ScheduleModule.forRoot(), JwtModule.registerAsync({})] })',
      'export class AppModule {}',
    ].join('\n'),
  }));
  assert.deepEqual(result.diagnostics, []);
});

test('internal dynamic modules create graph edges and reciprocal edges report a cycle', () => {
  const oneWay = scanPorts(fixtureProject({
    'backend/src/dynamic/a.module.ts': "import { Module } from '@nestjs/common';\nimport { BModule } from './b.module';\n@Module({ imports: [BModule.register()] })\nexport class AModule {}\n",
    'backend/src/dynamic/b.module.ts': "import { Module } from '@nestjs/common';\n@Module({})\nexport class BModule { static register() { return {}; } }\n",
  }));
  assert.deepEqual(oneWay.diagnostics, []);

  const reciprocal = scanPorts(fixtureProject({
    'backend/src/dynamic/a.module.ts': "import { Module } from '@nestjs/common';\nimport { BModule } from './b.module';\n@Module({ imports: [BModule.register()] })\nexport class AModule {}\n",
    'backend/src/dynamic/b.module.ts': "import { Module } from '@nestjs/common';\nimport { AModule } from './a.module';\n@Module({ imports: [AModule] })\nexport class BModule { static register() { return {}; } }\n",
  }));
  const cycles = diagnosticsOfKind(reciprocal, 'nest-module-cycle');
  assert.equal(cycles.length, 1);
  assert.equal(
    cycles[0].cycle,
    'backend/src/dynamic/a.module.ts -> backend/src/dynamic/b.module.ts -> backend/src/dynamic/a.module.ts',
  );
});

test('statically resolvable const arrays and spreads contribute module edges', () => {
  const result = scanPorts(fixtureProject({
    'backend/src/static/a.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { BModule } from './b.module';",
      'const direct = BModule;',
      'const nested = [direct] as const;',
      'const imports = [...nested];',
      '@Module({ imports })',
      'export class AModule {}',
    ].join('\n'),
    'backend/src/static/b.module.ts': "import { Module } from '@nestjs/common';\nimport { AModule } from './a.module';\n@Module({ imports: [AModule] })\nexport class BModule {}\n",
  }));
  const cycles = diagnosticsOfKind(result, 'nest-module-cycle');
  assert.equal(cycles.length, 1);
  assert.equal(
    cycles[0].cycle,
    'backend/src/static/a.module.ts -> backend/src/static/b.module.ts -> backend/src/static/a.module.ts',
  );
});

test('unresolved spread, identifier, conditional, mutable alias, and helper call fail closed', () => {
  const expressions = [
    '...unknownSpread',
    'unknownIdentifier',
    'condition ? BModule : CModule',
    'mutableImports',
    'makeImports()',
  ];
  for (const expression of expressions) {
    const declarations = expression === 'mutableImports'
      ? 'let mutableImports = [BModule];\n'
      : expression === 'makeImports()'
        ? 'function makeImports() { return [BModule]; }\n'
        : '';
    const result = scanPorts(fixtureProject({
      'backend/src/unresolved/a.module.ts': [
        "import { Module } from '@nestjs/common';",
        "import { BModule } from './b.module';",
        "import { CModule } from './c.module';",
        declarations,
        `@Module({ imports: [${expression}] })`,
        'export class AModule {}',
      ].join('\n'),
      'backend/src/unresolved/b.module.ts': "import { Module } from '@nestjs/common';\n@Module({})\nexport class BModule {}\n",
      'backend/src/unresolved/c.module.ts': "import { Module } from '@nestjs/common';\n@Module({})\nexport class CModule {}\n",
    }));
    assert.equal(diagnosticsOfKind(result, 'unresolved-module-import').length, 1, expression);
  }
});

test('real unresolved-module diagnostics never reflect source expressions or literals', () => {
  const fixtures = [
    {
      name: 'string literal',
      declarations: '',
      expression: "'http://%file:///srv/private/exit1-real-scan.ts'",
      forbidden: ['http://%', 'file://', '/srv/private/exit1-real-scan.ts'],
    },
    {
      name: 'helper call with secret-shaped argument',
      declarations: 'function unresolvedHelper(value: string) { return value; }\n',
      expression: "unresolvedHelper('TOKEN=exit1-secret')",
      forbidden: ['unresolvedHelper', 'TOKEN=exit1-secret'],
    },
    {
      name: 'template literal',
      declarations: '',
      expression: '`file:///opt/private/exit1-template.ts`',
      forbidden: ['file://', '/opt/private/exit1-template.ts'],
    },
    {
      name: 'malformed URL',
      declarations: '',
      expression: "'https:////exit1-server/private/exit1-malformed.ts'",
      forbidden: ['https:////', 'exit1-malformed.ts'],
    },
    {
      name: 'multiline path families',
      declarations: '',
      expression: '`exit1-source-prefix\n/srv/private/exit1-posix.ts\nC:\\private\\exit1-drive.ts\n\\\\exit1-server\\private\\exit1-unc.ts\n\\\\?\\UNC\\exit1-server\\private\\exit1-extended.ts`',
      forbidden: ['exit1-source-prefix', 'exit1-posix', 'exit1-drive', 'exit1-unc', 'exit1-extended'],
    },
  ];

  for (const [index, fixture] of fixtures.entries()) {
    const source = `backend/src/unresolved/exit1-${index}.module.ts`;
    const scanResult = scanPorts(fixtureProject({
      [source]: [
        "import { Module } from '@nestjs/common';",
        fixture.declarations,
        `@Module({ imports: [${fixture.expression}] })`,
        `export class ExitOne${index}Module {}`,
      ].join('\n'),
    }));
    const diagnostics = diagnosticsOfKind(scanResult, 'unresolved-module-import');
    assert.equal(diagnostics.length, 1, fixture.name);
    assert.equal(
      diagnostics[0].message,
      'cannot statically resolve Nest module import expression',
      fixture.name,
    );

    const stdout: string[] = [];
    const stderr: string[] = [];
    assert.equal(runCli({
      argv: ['--check'],
      scan: () => scanResult,
      stdout: (message: string) => stdout.push(message),
      stderr: (message: string) => stderr.push(message),
    }), 1, fixture.name);
    assert.deepEqual(stdout, [], fixture.name);
    assert.deepEqual(stderr, [
      `${source}:${diagnostics[0].line} [unresolved-module-import] cannot statically resolve Nest module import expression`,
    ], fixture.name);
    for (const forbidden of fixture.forbidden) {
      assert.equal(stderr[0].includes(forbidden), false, `${fixture.name}: ${forbidden}`);
    }
  }
});

test('other exit-one diagnostics expose only fixed reasons and safe repository paths', () => {
  const domainSource = 'backend/src/modules/tasks/domain/exit1-domain.ts';
  const domainResult = scanPorts(fixtureProject({
    [domainSource]: [
      "import value from '@nestjs/TOKEN=exit1-domain-secret';",
      'export default value;',
    ].join('\n'),
  }));
  const domainDiagnostics = diagnosticsOfKind(domainResult, 'domain-runtime-import');
  assert.equal(domainDiagnostics.length, 1);
  assert.equal(
    domainDiagnostics[0].message,
    'domain code cannot import Nest runtime or a foreign business context',
  );

  const cycleResult = scanPorts(fixtureProject({
    'backend/src/cycle-safe/a.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { TOKEN_exit1_cycle_B } from './b.module';",
      '@Module({ imports: [TOKEN_exit1_cycle_B] })',
      'export class TOKEN_exit1_cycle_A {}',
    ].join('\n'),
    'backend/src/cycle-safe/b.module.ts': [
      "import { Module } from '@nestjs/common';",
      "import { TOKEN_exit1_cycle_A } from './a.module';",
      '@Module({ imports: [TOKEN_exit1_cycle_A] })',
      'export class TOKEN_exit1_cycle_B {}',
    ].join('\n'),
  }));
  const cycleDiagnostics = diagnosticsOfKind(cycleResult, 'nest-module-cycle');
  assert.equal(cycleDiagnostics.length, 1);
  assert.equal(cycleDiagnostics[0].message, 'Nest module import cycle detected');
  assert.equal(
    cycleDiagnostics[0].cycle,
    'backend/src/cycle-safe/a.module.ts -> backend/src/cycle-safe/b.module.ts -> backend/src/cycle-safe/a.module.ts',
  );

  for (const [result, forbidden] of [
    [domainResult, ['TOKEN=exit1-domain-secret', '@nestjs/TOKEN']],
    [cycleResult, ['TOKEN_exit1_cycle_A', 'TOKEN_exit1_cycle_B']],
  ] as const) {
    const output: string[] = [];
    assert.equal(runCli({
      argv: ['--check'],
      scan: () => result,
      stdout: (message: string) => output.push(message),
      stderr: (message: string) => output.push(message),
    }), 1);
    for (const sourceText of forbidden) assert.equal(output.join('\n').includes(sourceText), false);
  }

  const injectedOutput: string[] = [];
  assert.equal(runCli({
    argv: ['--check'],
    scan: () => ({
      diagnostics: [{
        kind: 'forward-ref',
        path: 'backend/src/tasks/use.ts',
        line: 7,
        message: 'TOKEN=exit1-injected-secret file:///srv/private/exit1-injected.ts',
      }],
      counts: { forwardRef: 1, globals: 2, illegalFutureImports: 0, nestModuleCycles: 0 },
    }),
    stdout: (message: string) => injectedOutput.push(message),
    stderr: (message: string) => injectedOutput.push(message),
  }), 1);
  assert.deepEqual(injectedOutput, [
    'backend/src/tasks/use.ts:7 [forward-ref] forwardRef resolved to @nestjs/common is forbidden',
  ]);
});

test('runCli validates the exact count schema before rendering success', () => {
  const validCounts = {
    forwardRef: 0,
    globals: 2,
    illegalFutureImports: 0,
    nestModuleCycles: 0,
  };
  const invalidCounts: Array<{ name: string; counts: unknown }> = [
    {
      name: 'attacker-controlled string',
      counts: { ...validCounts, forwardRef: 'TOKEN=exit0-secret file:///srv/private/counts.ts' },
    },
    { name: 'missing key', counts: { forwardRef: 0, globals: 2, illegalFutureImports: 0 } },
    { name: 'extra key', counts: { ...validCounts, cycles: 0 } },
    { name: 'negative integer', counts: { ...validCounts, globals: -1 } },
    { name: 'fraction', counts: { ...validCounts, globals: 1.5 } },
    { name: 'infinity', counts: { ...validCounts, globals: Number.POSITIVE_INFINITY } },
    { name: 'unsafe integer', counts: { ...validCounts, globals: Number.MAX_SAFE_INTEGER + 1 } },
    { name: 'bigint', counts: { ...validCounts, globals: 2n } },
    { name: 'symbol', counts: { ...validCounts, globals: Symbol('TOKEN=exit0-symbol') } },
    { name: 'array', counts: [0, 2, 0, 0] },
    { name: 'inherited values', counts: Object.create(validCounts) },
    {
      name: 'throwing value getter',
      counts: Object.defineProperty({ ...validCounts }, 'globals', {
        enumerable: true,
        get() { throw new Error('TOKEN=exit0-getter'); },
      }),
    },
    {
      name: 'toString trap',
      counts: {
        ...validCounts,
        globals: { toString() { throw new Error('TOKEN=exit0-tostring'); } },
      },
    },
  ];

  for (const fixture of invalidCounts) {
    const output: string[] = [];
    assert.equal(runCli({
      argv: ['--check'],
      scan: () => ({ diagnostics: [], counts: fixture.counts }) as unknown as ScanResult,
      stdout: (message: string) => output.push(message),
      stderr: (message: string) => output.push(message),
    }), 2, fixture.name);
    assert.deepEqual(output, ['ERROR - architecture ports scan failed'], fixture.name);
  }
});

test('runCli validates and renders a diagnostic batch atomically', () => {
  const output: string[] = [];
  assert.equal(runCli({
    argv: ['--check'],
    scan: () => ({
      diagnostics: [
        {
          kind: 'forward-ref',
          path: 'backend/src/tasks/valid.ts',
          line: 1,
          message: 'safe-looking first diagnostic',
        },
        {
          kind: 'forward-ref',
          path: 'backend/src/tasks/z/C:/late-invalid.ts',
          line: 2,
          message: 'TOKEN=late-invalid file:///srv/private/late.ts',
        },
      ],
      counts: { forwardRef: 2, globals: 2, illegalFutureImports: 0, nestModuleCycles: 0 },
    }),
    stdout: (message: string) => output.push(message),
    stderr: (message: string) => output.push(message),
  }), 2);
  assert.deepEqual(output, ['ERROR - architecture ports scan failed']);
});

test('runCli accepts only canonical diagnostic kinds, paths, and safe integer lines', () => {
  const invalidDiagnostics: Array<{ name: string; diagnostic: unknown }> = [
    { name: 'empty path', diagnostic: { kind: 'forward-ref', path: '', line: 1 } },
    { name: 'absolute path', diagnostic: { kind: 'forward-ref', path: '/srv/private/exit1.ts', line: 1 } },
    { name: 'drive marker', diagnostic: { kind: 'forward-ref', path: 'backend/src/C:/private/exit1.ts', line: 1 } },
    { name: 'URL scheme', diagnostic: { kind: 'forward-ref', path: 'backend/src/file://srv/private/exit1.ts', line: 1 } },
    { name: 'backslash', diagnostic: { kind: 'forward-ref', path: 'backend/src/tasks\\exit1.ts', line: 1 } },
    { name: 'dot segment', diagnostic: { kind: 'forward-ref', path: 'backend/src/./tasks/exit1.ts', line: 1 } },
    { name: 'parent segment', diagnostic: { kind: 'forward-ref', path: 'backend/src/tasks/../private/exit1.ts', line: 1 } },
    { name: 'empty segment', diagnostic: { kind: 'forward-ref', path: 'backend/src//tasks/exit1.ts', line: 1 } },
    { name: 'NUL', diagnostic: { kind: 'forward-ref', path: 'backend/src/tasks/exit1\u0000.ts', line: 1 } },
    { name: 'newline', diagnostic: { kind: 'forward-ref', path: 'backend/src/tasks/exit1\nTOKEN=x.ts', line: 1 } },
    { name: 'oversized path', diagnostic: { kind: 'forward-ref', path: `backend/src/tasks/${'x'.repeat(4096)}.ts`, line: 1 } },
    { name: 'unknown kind', diagnostic: { kind: 'TOKEN=exit1-kind', path: 'backend/src/tasks/exit1.ts', line: 1 } },
    { name: 'zero line', diagnostic: { kind: 'forward-ref', path: 'backend/src/tasks/exit1.ts', line: 0 } },
    { name: 'fraction line', diagnostic: { kind: 'forward-ref', path: 'backend/src/tasks/exit1.ts', line: 1.5 } },
    { name: 'unsafe line', diagnostic: { kind: 'forward-ref', path: 'backend/src/tasks/exit1.ts', line: 1e100 } },
    { name: 'bigint line', diagnostic: { kind: 'forward-ref', path: 'backend/src/tasks/exit1.ts', line: 1n } },
    { name: 'array diagnostic', diagnostic: ['forward-ref', 'backend/src/tasks/exit1.ts', 1] },
    { name: 'inherited diagnostic', diagnostic: Object.create({ kind: 'forward-ref', path: 'backend/src/tasks/exit1.ts', line: 1 }) },
  ];

  for (const fixture of invalidDiagnostics) {
    const output: string[] = [];
    assert.equal(runCli({
      argv: ['--check'],
      scan: () => ({
        diagnostics: [fixture.diagnostic],
        counts: { forwardRef: 1, globals: 2, illegalFutureImports: 0, nestModuleCycles: 0 },
      }) as unknown as ScanResult,
      stdout: (message: string) => output.push(message),
      stderr: (message: string) => output.push(message),
    }), 2, fixture.name);
    assert.deepEqual(output, ['ERROR - architecture ports scan failed'], fixture.name);
  }
});

test('runCli rejects non-plain scan data and accessors without reflecting traps', () => {
  const validCounts = {
    forwardRef: 0,
    globals: 2,
    illegalFutureImports: 0,
    nestModuleCycles: 0,
  };
  const inheritedResult = Object.create({ diagnostics: [], counts: validCounts });
  const arrayResult = Object.assign([], { diagnostics: [], counts: validCounts });
  const throwingResult = Object.defineProperty({ counts: validCounts }, 'diagnostics', {
    enumerable: true,
    get() { throw new Error('TOKEN=result-getter file:///srv/private/result.ts'); },
  });
  const diagnosticsSubclass = new (class extends Array<unknown> {})();
  const hugeSparseDiagnostics = new Array(0xffff_ffff);
  const proxiedResult = new Proxy({ diagnostics: [], counts: validCounts }, {});
  const proxiedCounts = new Proxy({ ...validCounts }, {});
  const proxiedDiagnostics = new Proxy([] as unknown[], {});
  const throwingDiagnostic = Object.defineProperty({
    path: 'backend/src/tasks/exit1.ts',
    line: 1,
  }, 'kind', {
    enumerable: true,
    get() { throw new Error('TOKEN=diagnostic-getter file:///srv/private/diagnostic.ts'); },
  });
  const fixtures: Array<{ name: string; result: unknown }> = [
    { name: 'result array', result: arrayResult },
    { name: 'inherited result', result: inheritedResult },
    { name: 'proxied result', result: proxiedResult },
    { name: 'throwing result getter', result: throwingResult },
    { name: 'missing result key', result: { diagnostics: [] } },
    { name: 'extra result key', result: { diagnostics: [], counts: validCounts, extra: 'TOKEN=result-extra' } },
    { name: 'diagnostics object', result: { diagnostics: {}, counts: validCounts } },
    { name: 'diagnostics subclass', result: { diagnostics: diagnosticsSubclass, counts: validCounts } },
    { name: 'huge sparse diagnostics', result: { diagnostics: hugeSparseDiagnostics, counts: validCounts } },
    { name: 'proxied diagnostics', result: { diagnostics: proxiedDiagnostics, counts: validCounts } },
    { name: 'proxied counts', result: { diagnostics: [], counts: proxiedCounts } },
    { name: 'throwing diagnostic getter', result: { diagnostics: [throwingDiagnostic], counts: { ...validCounts, forwardRef: 1 } } },
  ];

  for (const fixture of fixtures) {
    const output: string[] = [];
    assert.equal(runCli({
      argv: ['--check'],
      scan: () => fixture.result as ScanResult,
      stdout: (message: string) => output.push(message),
      stderr: (message: string) => output.push(message),
    }), 2, fixture.name);
    assert.deepEqual(output, ['ERROR - architecture ports scan failed'], fixture.name);
  }

  const ignoredTrap = Object.defineProperties({
    kind: 'forward-ref',
    path: 'backend/src/tasks/exit1.ts',
    line: 1,
  }, {
    message: {
      enumerable: true,
      get() { throw new Error('TOKEN=ignored-message-getter'); },
    },
    cycle: {
      enumerable: true,
      get() { throw new Error('TOKEN=ignored-cycle-getter'); },
    },
  });
  const safeOutput: string[] = [];
  assert.equal(runCli({
    argv: ['--check'],
    scan: () => ({
      diagnostics: [ignoredTrap],
      counts: { ...validCounts, forwardRef: 1 },
    }) as unknown as ScanResult,
    stdout: (message: string) => safeOutput.push(message),
    stderr: (message: string) => safeOutput.push(message),
  }), 1);
  assert.deepEqual(safeOutput, [
    'backend/src/tasks/exit1.ts:1 [forward-ref] forwardRef resolved to @nestjs/common is forbidden',
  ]);
});

test('a syntactically invalid TypeScript program fails the scan instead of producing a partial graph', () => {
  const options = fixtureProject({
    'backend/src/tasks/broken.ts': 'export const broken = ;\n',
  });
  assert.throws(() => scanPorts(options), /TypeScript program/);
});

test('runCli returns deterministic exits 0, 1, and 2', () => {
  const stdout: string[] = [];
  const stderr: string[] = [];
  const passing: ScanResult = {
    diagnostics: [],
    counts: { forwardRef: 0, globals: 2, illegalFutureImports: 0, nestModuleCycles: 0 },
  };
  const dependencies: CliDependencies = {
    argv: ['--check'],
    scan: () => passing,
    stdout: (message) => stdout.push(message),
    stderr: (message) => stderr.push(message),
  };
  assert.equal(runCli(dependencies), 0);
  assert.deepEqual(stdout, [
    'PASS - architecture ports: forwardRef=0, globals=2, illegal future imports=0, Nest module cycles=0',
  ]);

  assert.equal(runCli({
    ...dependencies,
    scan: () => ({
      ...passing,
      diagnostics: [{
        kind: 'forward-ref',
        path: 'backend/src/tasks/use.ts',
        line: 1,
        message: 'forwardRef resolved to @nestjs/common is forbidden',
      }],
    }),
  }), 1);
  assert.equal(runCli({ ...dependencies, argv: ['--unknown'] }), 2);
  assert.equal(runCli({
    ...dependencies,
    scan: () => { throw new Error('program failed at C:\\private\\source.ts\nstack'); },
  }), 2);
  assert.equal(stderr[stderr.length - 1], 'ERROR - architecture ports scan failed');
});

test('ports CLI never reflects scanner exceptions containing absolute paths', () => {
  const passing: ScanResult = {
    diagnostics: [],
    counts: { forwardRef: 0, globals: 2, illegalFutureImports: 0, nestModuleCycles: 0 },
  };
  const failures = [
    'scan failed [/srv/private/ports-posix.ts',
    'scan failed "/opt/private/ports-opt.ts"',
    "scan failed='/tmp/private/ports-tmp.ts'",
    'scan failed (/workspace/aarast/backend/ports-repo.ts)',
    'scan failed at C:\\private\\ports-drive.ts',
    'scan failed =D:/private/ports-forward-drive.ts',
    'scan failed {\\\\ports-server\\private\\ports-unc.ts}',
    'scan failed [\\\\?\\C:\\private\\ports-extended-drive.ts]',
    'scan failed "\\\\?\\UNC\\ports-server\\private\\ports-extended-unc.ts"',
  ];
  for (const [index, failure] of failures.entries()) {
    const output: string[] = [];
    const exitCode = runCli({
      argv: ['--check'],
      scan: () => { throw new Error(`${failure}${index % 2 ? '\n' : '\r\n'}stack detail`); },
      stdout: (message: string) => output.push(message),
      stderr: (message: string) => output.push(message),
    });
    assert.equal(exitCode, 2);
    assert.deepEqual(output, ['ERROR - architecture ports scan failed']);
  }
  assert.deepEqual(passing.diagnostics, []);

  const urlOutput: string[] = [];
  assert.equal(runCli({
    argv: ['--check'],
    scan: () => { throw new Error('scan failed at https://example.test/docs/path\nstack detail'); },
    stdout: (message: string) => urlOutput.push(message),
    stderr: (message: string) => urlOutput.push(message),
  }), 2);
  assert.deepEqual(urlOutput, ['ERROR - architecture ports scan failed']);
});

test('ports CLI never reflects file, web, malformed URL, secret, or sentinel text', () => {
  const reflectedInputs = [
    'file:///srv/private/ports-file-posix.ts',
    'file://ports-server/private/ports-file-unc.ts',
    'file://ports-server/share/private/ports-file-share.ts',
    'file:///C:/private/ports-file-drive.ts',
    'file://localhost/C:/private/ports-file-localhost.ts',
    'file:///%5C%5C%3F%5CC%3A%5Cprivate%5Cports-file-extended-drive.ts',
    'file:///%5C%5C%3F%5CUNC%5Cports-server%5Cshare%5Cports-file-extended-unc.ts',
    'https://example.test/docs/C:/safe-guide',
    'http://example.test/docs/ordinary-guide',
    'http:/malformed.example/private/ports-malformed.ts',
    'https:////ports-server/private/ports-malformed-unc.ts',
    '\u0000architecture-web-url-0-attacker-sentinel\u0000',
    'TOKEN=ports-attacker-secret',
  ];
  for (const reflectedInput of reflectedInputs) {
    const output: string[] = [];
    assert.equal(runCli({
      argv: ['--check'],
      scan: () => { throw new Error(`scan failed [${reflectedInput}\r\nstack detail`); },
      stdout: (message: string) => output.push(message),
      stderr: (message: string) => output.push(message),
    }), 2);
    assert.deepEqual(output, ['ERROR - architecture ports scan failed']);
  }
});

test('the real CLI sanitizes unknown-argument failures', () => {
  const cli = path.join(backendRoot, 'scripts', 'architecture', 'ports-scan.cjs');
  const result = spawnSync(process.execPath, [cli, '--unknown'], {
    cwd: backendRoot,
    encoding: 'utf8',
  });
  assert.equal(result.status, 2);
  const output = `${result.stdout}\n${result.stderr}`;
  assert.match(output, /usage: ports-scan\.cjs --check/);
  assert.doesNotMatch(output, /[A-Za-z]:[\\/]/);
  assert.doesNotMatch(output, /\n\s*at\s+/);
});

test('the real CLI never reflects TypeChecker alias resolution failures', () => {
  const root = mkdtempSync(path.join(tmpdir(), 'aarast-ports-alias-error-'));
  temporaryRoots.push(root);
  const preload = path.join(root, 'throwing-alias-checker.cjs');
  const failureMessage = [
    'ports-attacker-message',
    'https://example.test/docs/C:/safe-guide',
    'file:///srv/private/ports-real.ts',
    'http:/malformed.example/private/ports-malformed.ts',
    '\u0000architecture-web-url-0-attacker-sentinel\u0000',
    'TOKEN=ports-real-secret',
    '\nstack detail',
  ].join(' ');
  writeFileSync(preload, [
    "const Module = require('node:module');",
    'const originalLoad = Module._load;',
    'Module._load = function patchedLoad(request, parent, isMain) {',
    '  const loaded = originalLoad.call(this, request, parent, isMain);',
    "  if (request !== 'typescript') return loaded;",
    '  return {',
    '    ...loaded,',
    '    createProgram(...args) {',
    '      const program = loaded.createProgram(...args);',
    '      const getTypeChecker = program.getTypeChecker.bind(program);',
    '      return new Proxy(program, {',
    '        get(target, property, receiver) {',
    "          if (property === 'getTypeChecker') {",
    '            return () => {',
    '              const checker = getTypeChecker();',
    '              return new Proxy(checker, {',
    '                get(checkerTarget, checkerProperty, checkerReceiver) {',
    "                  if (checkerProperty === 'getAliasedSymbol') {",
    `                    return () => { throw new Error(${JSON.stringify(failureMessage)}); };`,
    '                  }',
    '                  const value = Reflect.get(checkerTarget, checkerProperty, checkerReceiver);',
    "                  return typeof value === 'function' ? value.bind(checkerTarget) : value;",
    '                },',
    '              });',
    '            };',
    '          }',
    '          const value = Reflect.get(target, property, receiver);',
    "          return typeof value === 'function' ? value.bind(target) : value;",
    '        },',
    '      });',
    '    },',
    '  };',
    '};',
  ].join('\n'), 'utf8');

  const cli = path.join(backendRoot, 'scripts', 'architecture', 'ports-scan.cjs');
  const result = spawnSync(process.execPath, ['-r', preload, cli, '--check'], {
    cwd: backendRoot,
    encoding: 'utf8',
  });
  const output = `${result.stdout}\n${result.stderr}`;
  assert.equal(result.status, 2);
  assert.equal(result.stderr.trim(), 'ERROR - architecture ports scan failed');
  assert.doesNotMatch(output, /PASS - architecture ports|\[missing-r0-global\]/);
  assert.doesNotMatch(output, /ports-attacker-message|example\.test|ports-real|file:|malformed|attacker-sentinel|ports-real-secret|stack detail|\n\s*at\s+/i);
});

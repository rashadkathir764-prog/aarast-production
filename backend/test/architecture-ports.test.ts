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
  const fixtures = [
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
  assert.equal(diagnostics[0].cycle, 'AModule -> BModule -> CModule -> AModule');
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
  assert.equal(cycles[0].cycle, 'AModule -> BModule -> AModule');
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
  assert.equal(cycles[0].cycle, 'AModule -> BModule -> AModule');
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
  assert.doesNotMatch(stderr.join('\n'), /C:\\private|\nstack/);
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

import 'reflect-metadata';

import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import { Module } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import ts from 'typescript';

const sourceRoot = join(process.cwd(), 'src');

function source(path: string): string {
  return readFileSync(join(sourceRoot, path), 'utf8');
}

function requiredSource(path: string): string {
  assert.equal(existsSync(join(sourceRoot, path)), true, `${path} must exist`);
  return source(path);
}

function sourceFile(path: string): ts.SourceFile {
  return ts.createSourceFile(
    path,
    requiredSource(path),
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.TS,
  );
}

function interfaceMethods(path: string, name: string): string[] {
  const file = sourceFile(path);
  const declaration = file.statements.find(
    (statement): statement is ts.InterfaceDeclaration =>
      ts.isInterfaceDeclaration(statement) && statement.name.text === name,
  );
  assert.ok(declaration, `${name} must be declared in ${path}`);
  return declaration.members
    .filter(ts.isMethodSignature)
    .map((member) => member.name.getText(file))
    .sort();
}

function exportedTypeNames(path: string): string[] {
  return sourceFile(path).statements
    .filter(
      (statement): statement is
        | ts.InterfaceDeclaration
        | ts.TypeAliasDeclaration =>
        (ts.isInterfaceDeclaration(statement) ||
          ts.isTypeAliasDeclaration(statement)) &&
        statement.modifiers?.some(
          (modifier) => modifier.kind === ts.SyntaxKind.ExportKeyword,
        ) === true,
    )
    .map((statement) => statement.name.text)
    .sort();
}

test('Task 5 publishes the exact identity auth and access-token contracts', () => {
  const path = 'modules/identity/public/identity-auth.port.ts';
  assert.deepEqual(interfaceMethods(path, 'IdentityAuthPort'), [
    'requestInviteOtp',
    'verifyInviteOtp',
  ]);
  assert.deepEqual(interfaceMethods(path, 'IdentityAccessTokenVerifier'), [
    'verifyAsync',
  ]);
  assert.deepEqual(exportedTypeNames(path), [
    'IdentityAccessTokenVerifier',
    'IdentityAuthPort',
    'InviteOtpRequestResponse',
    'InviteOtpVerifyInput',
    'InviteOtpVerifyResponse',
    'OtpDispatchContext',
  ]);
});

test('Task 5 public tokens resolve to the exact AuthService and JwtService instances', async () => {
  const {
    IdentityAuthPublicModule,
  } = require('../src/modules/identity/public/identity-auth-public.module');
  const {
    IDENTITY_ACCESS_TOKEN_VERIFIER,
    IDENTITY_AUTH_PORT,
  } = require('../src/modules/identity/public/identity-auth.port');
  const { AuthService } = require('../src/auth/auth.service');
  const { JwtService } = require('@nestjs/jwt');
  const { PrismaService } = require('../src/platform/database/prisma.service');

  class IdentityPortTestModule {}
  Module({ imports: [IdentityAuthPublicModule] })(IdentityPortTestModule);
  const originalSecret = process.env.JWT_SECRET;
  const originalInit = PrismaService.prototype.onModuleInit;
  const originalDestroy = PrismaService.prototype.onModuleDestroy;
  process.env.JWT_SECRET = 'Z8!pQ2xK7vN4mR9cT6yL3wF1hJ5sB0dG';
  PrismaService.prototype.onModuleInit = async () => undefined;
  PrismaService.prototype.onModuleDestroy = async () => undefined;
  let context: Awaited<ReturnType<typeof NestFactory.createApplicationContext>> | undefined;
  try {
    const moduleRef = await NestFactory.createApplicationContext(
      IdentityPortTestModule,
      { logger: false, abortOnError: false },
    );
    context = moduleRef;
    assert.equal(
      moduleRef.get(IDENTITY_AUTH_PORT, { strict: false }),
      moduleRef.get(AuthService, { strict: false }),
    );
    assert.equal(
      moduleRef.get(IDENTITY_ACCESS_TOKEN_VERIFIER, { strict: false }),
      moduleRef.get(JwtService, { strict: false }),
    );
  } finally {
    await context?.close();
    PrismaService.prototype.onModuleInit = originalInit;
    PrismaService.prototype.onModuleDestroy = originalDestroy;
    if (originalSecret === undefined) delete process.env.JWT_SECRET;
    else process.env.JWT_SECRET = originalSecret;
  }
});

test('Task 5 migrates the exact InviteAccess and WebSocket DI consumers', () => {
  const invite = source('sharing/invite-access.service.ts');
  assert.doesNotMatch(invite, /AuthService|auth\/auth\.service/);
  assert.match(invite, /@Inject\(IDENTITY_AUTH_PORT\)/);
  assert.match(invite, /IdentityAuthPort/);
  assert.match(invite, /modules\/identity\/public\/identity-auth\.port/);

  const gateway = source('conversations/conversations.gateway.ts');
  assert.doesNotMatch(gateway, /\bJwtService\b|from ['"]@nestjs\/jwt['"]/);
  assert.match(gateway, /@Inject\(IDENTITY_ACCESS_TOKEN_VERIFIER\)/);
  assert.match(gateway, /IdentityAccessTokenVerifier/);
  assert.match(gateway, /modules\/identity\/public\/identity-auth\.port/);
});

test('Task 5 AuthModule edges remain retired through the Task 6 cutover', () => {
  const retiredModules = [
    'budget-categories/budget-categories.module.ts',
    'contribution-history/contribution-history.module.ts',
    'guests/guests.module.ts',
    'money/money.module.ts',
    'onboarding/onboarding.module.ts',
    'sharing/sharing.module.ts',
    'tasks/tasks.module.ts',
    'wedding-costs/wedding-costs.module.ts',
    'wedding-plans/wedding-plans.module.ts',
  ];
  for (const path of retiredModules) {
    assert.equal(existsSync(join(sourceRoot, path)), false, path);
  }
  for (const path of [
    'conversations/conversations.module.ts',
    'notifications/notifications.module.ts',
    'push/push.module.ts',
    'timeline/timeline.module.ts',
  ]) {
    const text = source(path);
    assert.doesNotMatch(text, /auth\/auth\.module|\bAuthModule\b/, path);
    assert.match(text, /IdentityAuthPublicModule/, path);
  }
});

test('Task 5 keeps Auth controller and lifecycle providers in one owner path', () => {
  const full = source('modules/identity/identity.module.ts');
  const internal = requiredSource(
    'modules/identity/internal/identity-auth.internal.module.ts',
  );
  const publicModule = requiredSource(
    'modules/identity/public/identity-auth-public.module.ts',
  );
  assert.match(full, /AuthController/);
  assert.match(full, /IdentityAuthInternalModule/);
  assert.match(full, /IdentityAuthPublicModule/);
  assert.doesNotMatch(full, /providers:\s*\[[^\]]*AuthService/);
  for (const provider of [
    'AuthService',
    'JwtStrategy',
    'LoginThrottleCleanupScheduler',
    'OtpDispatchQuotaCleanupScheduler',
    'AuthChallengeCleanupScheduler',
  ]) {
    assert.match(internal, new RegExp(`\\b${provider}\\b`), provider);
  }
  assert.doesNotMatch(internal, /AuthController/);
  assert.doesNotMatch(publicModule, /AuthService|JwtStrategy|AuthController/);
  assert.match(internal, /exports:\s*\[[\s\S]*JwtModule/);
});

test('Task 5 composes identity secret validation with exact precedence and count', () => {
  const {
    validateRuntimeEnvironment,
  } = require('../src/platform/config/runtime-environment') as {
    validateRuntimeEnvironment: (
      environment: NodeJS.ProcessEnv,
      validateIdentitySecret: (environment: NodeJS.ProcessEnv) => void,
    ) => void;
  };
  let calls = 0;
  assert.throws(
    () =>
      validateRuntimeEnvironment(
        { DATABASE_URL: '', JWT_SECRET: '' },
        () => {
          calls += 1;
        },
      ),
    /Missing required environment variables/,
  );
  assert.equal(calls, 0);

  const identityFailure = new Error('identity-secret-callback-first');
  assert.throws(
    () =>
      validateRuntimeEnvironment(
        {
          DATABASE_URL: 'postgresql://runtime.invalid/aarast',
          JWT_SECRET: 'identity-task-five-valid-secret-value-8Z!pQ2xK',
          AUTH_OTP_MODE: 'invalid-mode',
        },
        () => {
          calls += 1;
          throw identityFailure;
        },
      ),
    (error) => error === identityFailure,
  );
  assert.equal(calls, 1);

  validateRuntimeEnvironment(
    {
      DATABASE_URL: 'postgresql://runtime.invalid/aarast',
      JWT_SECRET: 'identity-task-five-valid-secret-value-8Z!pQ2xK',
      AUTH_OTP_MODE: 'disabled',
    },
    () => {
      calls += 1;
    },
  );
  assert.equal(calls, 2);
});

test('Task 5 advances the live manifest and removes the final platform debt', () => {
  const manifest = JSON.parse(
    readFileSync(join(process.cwd(), 'architecture/r3-context-boundaries.json'), 'utf8'),
  ) as { stage: string };
  assert.equal(manifest.stage, 'task-6');
  const scanner = require('../scripts/architecture/r3-context-scan.cjs') as {
    scanR3Contexts: (options: Record<string, unknown>) => {
      diagnostics: unknown[];
      counts: Record<string, number>;
    };
  };
  const result = scanner.scanR3Contexts({
    repoRoot: join(process.cwd(), '..'),
    backendRoot: process.cwd(),
    manifestPath: join(process.cwd(), 'architecture/r3-context-boundaries.json'),
    stage: 'task-6',
  });
  assert.deepEqual(result.diagnostics, []);
  assert.equal(result.counts.remainingPlatformDebts, 0);
  assert.equal(result.counts.remainingRetiredLegacyProviderEdges, 2);
});

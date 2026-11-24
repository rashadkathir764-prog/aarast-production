import 'reflect-metadata';

import type { Server } from 'node:http';
import { type Provider, type Type, Module, ValidationPipe } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { JwtStrategy } from '../../src/modules/identity/internal/auth/jwt.strategy';
import { GlobalExceptionFilter } from '../../src/platform/http/global-exception.filter';
import { StripNulPipe } from '../../src/platform/http/strip-nul.pipe';
import { PrismaService } from '../../src/platform/database/prisma.service';

// HTTP for the routes that no database is needed to answer (RA-TS-28).
//
// The repo has no @nestjs/testing or supertest, and a route's guards and
// validation only run behind a real HTTP server. So a test builds a small
// Nest module out of the REAL controller, the REAL guards (`JwtAuthGuard`,
// `AdminGuard`, `AdminPermissionGuard`), the REAL passport strategy
// (`JwtStrategy`, on a fake Prisma that holds users and sessions) and the
// same global pipes and filter `main.ts` installs; only the service behind
// the controller is the test's own, so what it was called with is what the
// route let through. Requests go over `fetch` to a port the OS picks.

export const E2E_JWT_SECRET = 'e2e-5b1f0c9a7d3e48a2b6c4f8e1d07a39b5';

export type FakeAccount = {
  id: string;
  role?: 'USER' | 'ADMIN';
  adminRole?: 'SUPER_ADMIN' | 'OPERATIONS' | 'MODERATOR' | 'SUPPORT' | null;
  deletionScheduledFor?: Date | null;
};

export type TestApp = {
  url: string;
  /** An access token of a live session: the application's, or an admin's. */
  tokenFor(account: FakeAccount, scope?: 'application' | 'admin'): string;
  request(
    method: string,
    path: string,
    options?: { token?: string; body?: unknown; rawBody?: string },
  ): Promise<{ status: number; body: any; headers: Headers }>;
  close(): Promise<void>;
};

export async function startHttpApp(
  controllers: Type<unknown>[],
  providers: Provider[],
): Promise<TestApp> {
  process.env.JWT_SECRET = E2E_JWT_SECRET;
  const users = new Map<string, Record<string, unknown>>();
  const sessions = new Set<string>();
  const now = new Date('2026-01-01T00:00:00.000Z');
  const prisma = {
    user: { findUnique: async ({ where }: any) => users.get(where.id) ?? null },
    refreshToken: {
      findFirst: async ({ where }: any) =>
        sessions.has(`${where.userId}:${where.id}:${where.scope}`)
          ? { id: where.id }
          : null,
    },
  };

  @Module({
    imports: [PassportModule],
    controllers,
    providers: [
      ...providers,
      { provide: PrismaService, useValue: prisma },
      JwtStrategy,
    ],
  })
  class E2eModule {}

  const app = await NestFactory.create(E2eModule, { logger: false });
  // The same pipes and filter as main.ts.
  app.useGlobalPipes(
    new StripNulPipe(),
    new ValidationPipe({
      whitelist: true,
      forbidNonWhitelisted: true,
      transform: true,
    }),
  );
  app.useGlobalFilters(new GlobalExceptionFilter());
  await app.listen(0, '127.0.0.1');
  const server = app.getHttpServer() as Server;
  const address = server.address();
  if (!address || typeof address === 'string') throw new Error('no port');
  const url = `http://127.0.0.1:${address.port}`;
  const jwt = new JwtService({ secret: E2E_JWT_SECRET });

  return {
    url,
    tokenFor(account, scope = 'application') {
      const admin = scope === 'admin';
      const sessionId = `session-${account.id}-${scope}`;
      users.set(account.id, {
        id: account.id,
        name: 'Test',
        phone: '+967777000000',
        email: null,
        role: account.role ?? (admin ? 'ADMIN' : 'USER'),
        adminRole: account.adminRole ?? null,
        appRole: 'GROOM',
        status: 'ACTIVE',
        phoneVerifiedAt: now,
        appAccountActivatedAt: now,
        lastLoginAt: null,
        avatarUrl: null,
        locale: 'ar',
        activeWeddingPlanId: null,
        onboardingPath: null,
        persona: null,
        onboardingCompletedAt: null,
        passwordHash: null,
        appPasswordHash: null,
        deletionRequestedAt: account.deletionScheduledFor ? now : null,
        deletionScheduledFor: account.deletionScheduledFor ?? null,
        createdAt: now,
        updatedAt: now,
      });
      sessions.add(`${account.id}:${sessionId}:${admin ? 'ADMIN' : 'APPLICATION'}`);
      return jwt.sign({
        sub: account.id,
        phone: '+967777000000',
        scope,
        sid: sessionId,
        ...(admin ? { amr: 'admin_mfa' } : {}),
      });
    },
    async request(method, path, options = {}) {
      const response = await fetch(`${url}${path}`, {
        method,
        headers: {
          ...(options.token ? { Authorization: `Bearer ${options.token}` } : {}),
          ...(options.body !== undefined || options.rawBody !== undefined
            ? { 'Content-Type': 'application/json' }
            : {}),
        },
        body:
          options.rawBody ??
          (options.body === undefined ? undefined : JSON.stringify(options.body)),
      });
      const text = await response.text();
      let body: any = text;
      try {
        body = text ? JSON.parse(text) : null;
      } catch {
        // a non-JSON body stays text
      }
      return { status: response.status, body, headers: response.headers };
    },
    close: () => app.close(),
  };
}

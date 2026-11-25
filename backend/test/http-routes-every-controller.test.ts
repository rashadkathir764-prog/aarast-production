import 'reflect-metadata';

import assert from 'node:assert/strict';
import { readdirSync, statSync } from 'node:fs';
import { join, resolve } from 'node:path';
import test, { after, before } from 'node:test';
import { getMetadataStorage } from 'class-validator';
import { type TestApp, startHttpApp } from './support/http-app';

// RA-TS-28, last part: EVERY route of EVERY controller in `src` is sent an
// HTTP request, whatever its owner, through the real controller, guards,
// passport strategy and global pipes (support/http-app.ts). The services
// behind the controllers are recorders built from their own classes, so a
// request that gets past the guards and the pipes shows up as a call.
//
// For each route the controller's own guards decide what is asked:
//   - a route behind a session guard (`JwtAuthGuard`, `JwtSessionGuard`) is
//     asked with no session, with a token that is no token, and with a token
//     of the other realm (an admin's on the couple's route and the reverse):
//     401, and the service is never reached;
//   - a route behind the admin guards is asked by the couple's own session:
//     403;
//   - a route with a body DTO is sent a field the DTO does not declare, by a
//     session the route lets in: 400, and the service is never reached.
// The routes' own rules (permissions per role, each field's limits, the
// service's arguments) are in the other `http-routes-*` files; this one is
// the floor under every route, and it fails on a controller that cannot be
// reached at all (a route with no guard that should have one is read from
// the list the last test prints for review).

const UUID = '3f8e2d6a-9b1c-4e57-8a42-5c0d7e91b2f3';
const PATH = 'path';
const METHOD = 'method';
const ROUTE_ARGS = '__routeArguments__';
const GUARDS = '__guards__';
const BODY = 3; // RouteParamtypes.BODY
const METHODS = ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'ALL', 'OPTIONS', 'HEAD'];

const SESSION_GUARDS = new Set(['JwtAuthGuard', 'JwtSessionGuard']);
const ADMIN_GUARDS = new Set(['AdminGuard', 'AdminPermissionGuard']);
const REAL_GUARDS = new Set([...SESSION_GUARDS, ...ADMIN_GUARDS]);

type Ctor = new (...args: never[]) => object;
type Route = {
  controller: Ctor;
  handler: string;
  method: string;
  path: string;
  guards: string[];
  hasBodyDto: boolean;
};

function files(dir: string, out: string[] = []): string[] {
  for (const name of readdirSync(dir)) {
    const full = join(dir, name);
    if (statSync(full).isDirectory()) files(full, out);
    else if (name.endsWith('.controller.ts')) out.push(full);
  }
  return out;
}

const controllers: Ctor[] = [];
for (const file of files(resolve(__dirname, '../src'))) {
  const exported = require(file) as Record<string, unknown>;
  for (const value of Object.values(exported)) {
    if (typeof value === 'function' && Reflect.hasMetadata(PATH, value)) {
      controllers.push(value as Ctor);
    }
  }
}

function guardNames(target: object, handler?: string): string[] {
  const own = (Reflect.getMetadata(GUARDS, target) ?? []) as { name: string }[];
  const route = handler
    ? ((Reflect.getMetadata(GUARDS, (target as { prototype: object }).prototype[handler as never]) ?? []) as { name: string }[])
    : [];
  return [...own, ...route].map((guard) => guard.name);
}

function routesOf(controller: Ctor): Route[] {
  const prefix = String(Reflect.getMetadata(PATH, controller) ?? '');
  const prototype = controller.prototype as Record<string, unknown>;
  const found: Route[] = [];
  for (const handler of Object.getOwnPropertyNames(prototype)) {
    const fn = prototype[handler];
    if (handler === 'constructor' || typeof fn !== 'function') continue;
    const verb = Reflect.getMetadata(METHOD, fn) as number | undefined;
    if (verb === undefined) continue;
    const sub = String(Reflect.getMetadata(PATH, fn) ?? '');
    const path = `/${prefix}/${sub}`.replace(/\/+/g, '/').replace(/\/$/, '');
    const args = (Reflect.getMetadata(ROUTE_ARGS, controller, handler) ?? {}) as Record<string, { index: number }>;
    const types = (Reflect.getMetadata('design:paramtypes', prototype, handler) ?? []) as unknown[];
    const bodyKey = Object.keys(args).find((key) => key.startsWith(`${BODY}:`));
    const bodyType = bodyKey === undefined ? undefined : types[args[bodyKey].index];
    const hasBodyDto =
      typeof bodyType === 'function' &&
      ![String, Number, Boolean, Object, Array].includes(bodyType as never) &&
      getMetadataStorage().getTargetValidationMetadatas(bodyType as never, undefined as never, false, false).length > 0;
    found.push({
      controller,
      handler,
      method: METHODS[verb] ?? 'GET',
      path,
      guards: guardNames(controller, handler),
      hasBodyDto,
    });
  }
  return found;
}

// The public surface: the only routes with no session or admin guard of their
// own. It is written out, so a route that loses its guard (or a new one that
// never had it) fails the test below until someone decides it is public.
const PUBLIC_ROUTES = new Set(`
GET /api/v1/catalogs/bootstrap
GET /api/v1/cities
GET /api/v1/data-exports/:token
GET /api/v1/districts/:id/localities
GET /api/v1/governorates
GET /api/v1/governorates/:id/districts
GET /api/v1/provider-categories
GET /api/v1/providers
GET /api/v1/providers/category-counts
GET /api/v1/providers/:id
GET /api/v1/providers/:id/packages
GET /api/v1/providers/:id/reviews
GET /api/v1/providers/:id/services
GET /api/v1/public/rsvp/:token
GET /api/v1/public/rsvp/:token/card-photo
GET /api/v1/public/rsvp/:token/preview
GET /api/v1/services
GET /api/v1/services/:id
GET /health
GET /live
GET /metrics
GET /ready
GET /ready/core
POST /api/v1/auth/admin/login
POST /api/v1/auth/admin/login/complete
POST /api/v1/auth/admin/logout
POST /api/v1/auth/admin/password-reset/confirm
POST /api/v1/auth/admin/password-reset/request
POST /api/v1/auth/admin/password-reset/verify
POST /api/v1/auth/admin/refresh
POST /api/v1/auth/login
POST /api/v1/auth/otp/request
POST /api/v1/auth/otp/verify
POST /api/v1/auth/password-reset/confirm
POST /api/v1/auth/password-reset/request
POST /api/v1/auth/refresh
POST /api/v1/auth/register
POST /api/v1/auth/register/complete
POST /api/v1/invites/:token/request-otp
POST /api/v1/invites/:token/verify-otp
POST /api/v1/providers/:id/views
POST /api/v1/public/account-deletion/code
POST /api/v1/public/account-deletion/confirm
POST /api/v1/public/rsvp/:token
POST /api/v1/public/rsvp/:token/opened
`.split('\n').filter(Boolean));

const routes = controllers.flatMap(routesOf);

type Call = { method: string };
const calls: Call[] = [];

function recorderFor(type: { prototype: object }) {
  return Object.fromEntries(
    Object.getOwnPropertyNames(type.prototype)
      .filter((name) => name !== 'constructor')
      .map((name) => [
        name,
        async () => {
          calls.push({ method: name });
          return { ok: true };
        },
      ]),
  );
}

function dependenciesOf(type: Ctor, seen = new Set<unknown>()): Ctor[] {
  const own = (Reflect.getMetadata('design:paramtypes', type) ?? []) as unknown[];
  const out: Ctor[] = [];
  for (const dep of own) {
    if (typeof dep !== 'function' || seen.has(dep)) continue;
    if ([String, Number, Boolean, Object, Array, Function].includes(dep as never)) continue;
    seen.add(dep);
    out.push(dep as Ctor);
  }
  return out;
}


let app: TestApp;

before(async () => {
  const seen = new Set<unknown>();
  const providers: { provide: unknown; useValue: unknown }[] = [];
  for (const controller of controllers) {
    for (const dependency of dependenciesOf(controller, seen)) {
      providers.push({ provide: dependency, useValue: recorderFor(dependency) });
    }
  }
  app = await startHttpApp(controllers, providers as never);
});

after(async () => {
  await app.close();
});

const concrete = (path: string) =>
  path.replace(/:date\b/g, '2030-01-01').replace(/:\w+/g, UUID);

const adminToken = () => app.tokenFor({ id: 'admin-root', adminRole: 'SUPER_ADMIN' }, 'admin');
const appToken = () => app.tokenFor({ id: 'user-sweep' });

test('the sweep found the controllers and their routes', () => {
  assert.ok(controllers.length >= 40, `controllers: ${controllers.length}`);
  assert.ok(routes.length >= 300, `routes: ${routes.length}`);
  assert.ok(routes.every((route) => route.method !== 'ALL' || route.path.length > 0));
});

for (const route of routes) {
  const label = `${route.method} ${route.path} (${route.controller.name}.${route.handler})`;
  const sessionGuarded = route.guards.some((name) => SESSION_GUARDS.has(name));
  const adminGuarded = route.guards.some((name) => ADMIN_GUARDS.has(name));
  const path = concrete(route.path);
  const body = route.method === 'GET' || route.method === 'DELETE' ? undefined : {};

  if (sessionGuarded) {
    test(`${label}: no session, a false token, and the other realm's token are 401`, async () => {
      calls.length = 0;
      assert.equal((await app.request(route.method, path, { body })).status, 401, 'no session');
      assert.equal((await app.request(route.method, path, { body, token: 'not-a-token' })).status, 401, 'false token');
      const other = adminGuarded ? appToken() : adminToken();
      const status = (await app.request(route.method, path, { body, token: other })).status;
      assert.ok(adminGuarded ? status === 403 : status === 401, `the other realm: ${status}`);
      assert.equal(calls.length, 0, 'the service is never reached');
    });
  }

  if (route.hasBodyDto) {
    test(`${label}: a field the DTO does not declare is 400`, async () => {
      calls.length = 0;
      const token = adminGuarded ? adminToken() : sessionGuarded ? appToken() : undefined;
      const response = await app.request(route.method, path, {
        token,
        body: { notDeclaredByAnyDto: 1 },
      });
      assert.equal(response.status, 400);
      assert.equal(calls.length, 0, 'the service is never reached');
    });
  }
}

test('routes with no session guard answer without a session, and are all mounted', async () => {
  // The public routes (and the ones a guard further in decides): each is
  // asked once with no session (a refresh or a logout may well answer 401
  // with none: that is its own rule). The service behind is a recorder whose
  // answer is not a real one, so all that is judged is that the route is
  // there (Nest's «Cannot GET» answer is the one that it is not).
  const open = routes.filter((route) => !route.guards.some((name) => REAL_GUARDS.has(name)));
  assert.deepEqual(
    open.map((route) => `${route.method} ${route.path}`).sort(),
    [...PUBLIC_ROUTES].sort(),
    'the routes with no guard are exactly the public ones',
  );
  for (const route of open) {
    const response = await app.request(route.method, concrete(route.path), {
      body: route.method === 'GET' || route.method === 'DELETE' ? undefined : {},
    });
    // Nest answers a route it does not have with «Cannot GET /path».
    assert.ok(
      !/^Cannot (GET|POST|PUT|PATCH|DELETE) /.test(String(response.body?.message ?? '')),
      `${route.method} ${route.path} is not mounted`,
    );
  }
});

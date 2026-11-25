import 'reflect-metadata';

import assert from 'node:assert/strict';
import { readdirSync, readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';
import { Reflector } from '@nestjs/core';
import {
  ThrottlerException,
  ThrottlerGuard,
  ThrottlerStorageService,
} from '@nestjs/throttler';
import { AuthController } from '../src/modules/identity/api/auth.controller';
import { PushController } from '../src/push/push.controller';
import {
  DEVICE_SHARE_THROTTLER,
  deviceShareThrottler,
} from '../src/platform/http/route-throttle';

// RA-BE-144: a mobile network puts many phones behind one address (CGNAT).
// Each route's limit stays the address's ceiling, as before; inside it a
// phone that sends its id (`X-Aarast-Device`, the key the code limits count
// by) has half of it, so one phone cannot spend the address's minute for the
// others behind it. The id is only the phone's word: rotating it never
// passes the address's ceiling, and a request without one counts against the
// address alone, as before.

const DEVICE_A = '3f2b8c1e-5a7d-4e2f-9b1c-0d6e7f8a9b0c';
const DEVICE_B = '9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d';

function contextFor(handler: object, controller: object, ip: string, device?: string) {
  const request = { ip, headers: device ? { 'x-aarast-device': device } : {} };
  const response = { header: () => undefined };
  return {
    getHandler: () => handler,
    getClass: () => controller,
    switchToHttp: () => ({ getRequest: () => request, getResponse: () => response }),
  } as never;
}

async function appGuard() {
  const guard = new ThrottlerGuard(
    { throttlers: [{ ttl: 60_000, limit: 1_000 }, deviceShareThrottler] },
    new ThrottlerStorageService(),
    new Reflector(),
  );
  await guard.onModuleInit();
  return guard;
}

const login = AuthController.prototype.login as unknown as object;
const LOGIN_LIMIT = 20;

async function allowed(guard: ThrottlerGuard, times: number, ip: string, device?: string) {
  for (let n = 0; n < times; n += 1) {
    assert.equal(await guard.canActivate(contextFor(login, AuthController, ip, device)), true);
  }
}

test('one phone behind a shared address has half of the route, the others the rest', async () => {
  const guard = await appGuard();
  await allowed(guard, LOGIN_LIMIT / 2, '100.64.0.1', DEVICE_A);
  await assert.rejects(
    guard.canActivate(contextFor(login, AuthController, '100.64.0.1', DEVICE_A)),
    ThrottlerException,
  );
  // Another phone on the same address still signs in, up to the address's ceiling.
  await allowed(guard, LOGIN_LIMIT / 2 - 1, '100.64.0.1', DEVICE_B);
  await assert.rejects(
    guard.canActivate(contextFor(login, AuthController, '100.64.0.1', DEVICE_B)),
    ThrottlerException,
  );
});

test('rotating the phone id never passes the address ceiling, and no id counts on the address', async () => {
  const guard = await appGuard();
  for (let n = 0; n < LOGIN_LIMIT; n += 1) {
    const device = `rotated-device-${String(n).padStart(4, '0')}-0000`;
    assert.equal(await guard.canActivate(contextFor(login, AuthController, '100.64.0.2', device)), true);
  }
  await assert.rejects(
    guard.canActivate(contextFor(login, AuthController, '100.64.0.2', 'rotated-device-9999-0000')),
    ThrottlerException,
  );
  await allowed(guard, LOGIN_LIMIT, '100.64.0.3');
  await assert.rejects(
    guard.canActivate(contextFor(login, AuthController, '100.64.0.3')),
    ThrottlerException,
  );
});

test('a class-wide limit has the phone share too', async () => {
  const guard = await appGuard();
  const register = PushController.prototype.register as unknown as object;
  for (let n = 0; n < 15; n += 1) {
    assert.equal(await guard.canActivate(contextFor(register, PushController, '100.64.0.4', DEVICE_A)), true);
  }
  await assert.rejects(
    guard.canActivate(contextFor(register, PushController, '100.64.0.4', DEVICE_A)),
    ThrottlerException,
  );
});

test('every per-route limit outside the guest links and /ready gives the phone its share', () => {
  const sourceRoot = join(__dirname, '..', 'src');
  const files: string[] = [];
  const walk = (directory: string) => {
    for (const entry of readdirSync(directory)) {
      const path = join(directory, entry);
      if (statSync(path).isDirectory()) walk(path);
      else if (path.endsWith('.controller.ts')) files.push(path);
    }
  };
  walk(sourceRoot);
  const bare: string[] = [];
  for (const file of files) {
    const source = readFileSync(file, 'utf8');
    for (const match of source.matchAll(/@Throttle\((\{[^)]*\})\)/g)) {
      if (!/READINESS_REQUESTS_PER_MINUTE/.test(match[1])) bare.push(`${file}: ${match[0]}`);
    }
  }
  assert.deepEqual(bare, []);
  assert.equal(
    Reflect.getMetadata(`THROTTLER:LIMIT${DEVICE_SHARE_THROTTLER}`, login),
    LOGIN_LIMIT / 2,
  );
});

test('the app registers the phone share beside the address limit', () => {
  const app = readFileSync(join(__dirname, '..', 'src', 'app.module.ts'), 'utf8');
  const throttlers = /throttlers: \[([\s\S]*?)\n {10}\],/.exec(app)?.[1] ?? '';
  assert.match(throttlers, /\bdeviceShareThrottler,/);
  assert.match(throttlers, /\brsvpAddressThrottler,/);
});

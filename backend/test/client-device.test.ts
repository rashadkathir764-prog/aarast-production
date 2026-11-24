import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { AuthController } from '../src/modules/identity/api/auth.controller';
import { clientDeviceId } from '../src/platform/http/client-device';

// RA-BE-140, RA-BE-144, RA-BE-148: the phone sends a random id of its own
// (`X-Aarast-Device`). It is a key the limits count by, never a proof; one
// that is not a plain id counts as none.
const request = (device?: string | string[]) =>
  ({ ip: '198.51.100.7', headers: device === undefined ? {} : { 'x-aarast-device': device } }) as any;

test('a phone id is read from its header, and anything else counts as none', () => {
  assert.equal(
    clientDeviceId(request('3f2b8c1e-5a7d-4e2f-9b1c-0d6e7f8a9b0c')),
    '3f2b8c1e-5a7d-4e2f-9b1c-0d6e7f8a9b0c',
  );
  for (const unusable of [undefined, '', 'short', 'x'.repeat(65), 'has space in it 12345', ['a', 'b']]) {
    assert.equal(clientDeviceId(request(unusable)), null, String(unusable));
  }
});

test('the code requests hand the phone id to the limits beside the address', async () => {
  const contexts: unknown[] = [];
  const record = async (...args: unknown[]) => {
    contexts.push(args[args.length - 1]);
    return {} as any;
  };
  const controller = new AuthController({
    requestOtp: record,
    startRegistration: record,
    requestPasswordReset: record,
  } as any);
  const asked = request('3f2b8c1e-5a7d-4e2f-9b1c-0d6e7f8a9b0c');

  await controller.requestOtp({} as any, asked);
  await controller.register({} as any, asked);
  await controller.requestPasswordReset({} as any, asked);

  for (const context of contexts) {
    assert.deepEqual(context, {
      ip: '198.51.100.7',
      device: '3f2b8c1e-5a7d-4e2f-9b1c-0d6e7f8a9b0c',
    });
  }
  assert.equal(contexts.length, 3);
});

import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { afterEach, test } from 'node:test';
import { loadOpenWaOtpConfig } from '../src/auth/openwa-otp-config';
import { OpenWaOtpChannel } from '../src/auth/otp-channel';

const roots: string[] = [];

afterEach(() => {
  for (const root of roots.splice(0)) {
    fs.rmSync(root, { recursive: true, force: true });
  }
});

function credentialFile(apiKey: string): string {
  const root = fs.mkdtempSync(path.join(os.tmpdir(), 'aarast-openwa-credential-'));
  roots.push(root);
  const file = path.join(root, 'openwa.env');
  fs.writeFileSync(
    file,
    `OPENWA_SESSION_ID=aarast-otp\nOPENWA_API_KEY_ID=key-1\nOPENWA_API_KEY=${apiKey}\nOPENWA_API_KEY_EXPIRES_AT=2099-01-01T00:00:00.000Z\n`,
    { mode: 0o600 },
  );
  return file;
}

test('OpenWA loads the current credential from the atomic secret file', () => {
  const file = credentialFile('a'.repeat(40));
  const config = loadOpenWaOtpConfig({
    OPENWA_BASE_URL: 'http://aarast-openwa-otp:2785',
    OPENWA_CREDENTIAL_FILE: file,
  });

  assert.equal(config.sessionId, 'aarast-otp');
  assert.equal(config.apiKey, 'a'.repeat(40));
});

test('the runtime OTP channel reads the credential file for every send after an atomic rotation', async () => {
  const file = credentialFile('a'.repeat(40));
  const previous = {
    baseUrl: process.env.OPENWA_BASE_URL,
    credentialFile: process.env.OPENWA_CREDENTIAL_FILE,
    sessionId: process.env.OPENWA_SESSION_ID,
    apiKey: process.env.OPENWA_API_KEY,
  };
  process.env.OPENWA_BASE_URL = 'http://aarast-openwa-otp:2785';
  process.env.OPENWA_CREDENTIAL_FILE = file;
  delete process.env.OPENWA_SESSION_ID;
  delete process.env.OPENWA_API_KEY;
  const usedKeys: string[] = [];
  const fetchImplementation: typeof fetch = async (_url, init) => {
    usedKeys.push((init?.headers as Record<string, string>)['X-API-Key']);
    return new Response(
      JSON.stringify({
        messageId: 'message-id',
        timestamp: 1706868000,
        deliveryStatus: 'DELIVERED',
      }),
      { status: 201, headers: { 'content-type': 'application/json' } },
    );
  };
  const channel = new OpenWaOtpChannel(loadOpenWaOtpConfig, fetchImplementation);

  try {
    await channel.deliver('+967777123456', '123456', 'REGISTER');
    const next = `${file}.next`;
    fs.writeFileSync(
      next,
      `OPENWA_SESSION_ID=aarast-otp\nOPENWA_API_KEY_ID=key-2\nOPENWA_API_KEY=${'b'.repeat(40)}\nOPENWA_API_KEY_EXPIRES_AT=2099-01-01T00:00:00.000Z\n`,
      { mode: 0o600 },
    );
    fs.renameSync(next, file);
    await channel.deliver('+967777123456', '654321', 'LOGIN');
    assert.deepEqual(usedKeys, ['a'.repeat(40), 'b'.repeat(40)]);
  } finally {
    restoreEnvironment('OPENWA_BASE_URL', previous.baseUrl);
    restoreEnvironment('OPENWA_CREDENTIAL_FILE', previous.credentialFile);
    restoreEnvironment('OPENWA_SESSION_ID', previous.sessionId);
    restoreEnvironment('OPENWA_API_KEY', previous.apiKey);
  }
});

function restoreEnvironment(name: string, value: string | undefined): void {
  if (value === undefined) delete process.env[name];
  else process.env[name] = value;
}

test('OpenWA credential file parsing fails closed on malformed or oversized input', () => {
  const file = credentialFile('a'.repeat(40));
  const environment = {
    OPENWA_BASE_URL: 'http://aarast-openwa-otp:2785',
    OPENWA_CREDENTIAL_FILE: file,
  };

  fs.writeFileSync(file, `OPENWA_SESSION_ID=aarast-otp\nOPENWA_SESSION_ID=other\nOPENWA_API_KEY=${'a'.repeat(40)}\n`);
  assert.throws(() => loadOpenWaOtpConfig(environment), /credential file is invalid/);

  fs.writeFileSync(file, 'x'.repeat(20 * 1024));
  assert.throws(() => loadOpenWaOtpConfig(environment), /credential file is invalid/);

  fs.writeFileSync(
    file,
    `OPENWA_SESSION_ID=aarast-otp\nOPENWA_API_KEY=${'a'.repeat(40)}\n`,
  );
  assert.throws(() => loadOpenWaOtpConfig(environment), /credential file is invalid/);

  fs.writeFileSync(
    file,
    `OPENWA_SESSION_ID=aarast-otp\nOPENWA_API_KEY_ID=key-1\nOPENWA_API_KEY=${'a'.repeat(40)}\nOPENWA_API_KEY_EXPIRES_AT=2099-01-01T00:00:00.000Z\nUNKNOWN_FIELD=value\n`,
  );
  assert.throws(() => loadOpenWaOtpConfig(environment), /credential file is invalid/);
});

test(
  'OpenWA credential files reject broad permissions and symbolic links',
  { skip: process.platform === 'win32' },
  () => {
    const file = credentialFile('a'.repeat(40));
    const environment = {
      OPENWA_BASE_URL: 'http://aarast-openwa-otp:2785',
      OPENWA_CREDENTIAL_FILE: file,
    };

    fs.chmodSync(file, 0o640);
    assert.throws(() => loadOpenWaOtpConfig(environment), /credential file is invalid/);
    fs.chmodSync(file, 0o600);

    const link = `${file}.link`;
    fs.symlinkSync(file, link);
    assert.throws(
      () => loadOpenWaOtpConfig({ ...environment, OPENWA_CREDENTIAL_FILE: link }),
      /credential file is invalid/,
    );
  },
);

test('OpenWA rejects split credential sources and an expired file credential', () => {
  const file = credentialFile('a'.repeat(40));
  const base = {
    OPENWA_BASE_URL: 'http://aarast-openwa-otp:2785',
    OPENWA_CREDENTIAL_FILE: file,
  };

  assert.throws(
    () =>
      loadOpenWaOtpConfig({
        ...base,
        OPENWA_SESSION_ID: 'stale-session',
        OPENWA_API_KEY: 's'.repeat(40),
      }),
    /credential file is invalid/,
  );

  fs.writeFileSync(
    file,
    `OPENWA_SESSION_ID=aarast-otp\nOPENWA_API_KEY_ID=key-1\nOPENWA_API_KEY=${'a'.repeat(40)}\nOPENWA_API_KEY_EXPIRES_AT=2020-01-01T00:00:00.000Z\n`,
  );
  assert.throws(() => loadOpenWaOtpConfig(base), /credential file is invalid/);
});

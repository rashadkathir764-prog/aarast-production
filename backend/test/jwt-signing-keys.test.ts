import 'reflect-metadata';

import assert from 'node:assert/strict';
import { createHmac, hkdfSync } from 'node:crypto';
import { test } from 'node:test';
import { JwtService } from '@nestjs/jwt';
import {
  identityJwtModuleOptions,
  jwtSigningKey,
  jwtVerificationKey,
} from '../src/modules/identity/internal/auth/jwt-keys';
import { JwtStrategy } from '../src/modules/identity/internal/auth/jwt.strategy';
import {
  isPhoneProofFor,
  signPhoneProof,
} from '../src/modules/identity/internal/auth/phone-proof';

// RA-BE-149: the server's tokens are signed with a key derived from
// JWT_SECRET for their purpose (HKDF-SHA-256), not with the secret itself.
// A token signed before the deploy with the secret itself is still taken
// until it expires, and only if it was issued before this process started:
// nothing signs with the secret any more, so after one access-token
// lifetime (15 minutes) no such token is left to take.

const SECRET = 'k3Jq9vX2mP7rT4wZ8nB5cL1dF6hG0sYaQe';
const environment = { JWT_SECRET: SECRET, NODE_ENV: 'test' } as NodeJS.ProcessEnv;
// An hour ago: a token issued before it and given 15 minutes has expired.
const STARTED_AT_MS = Date.now() - 60 * 60_000;
const nowSeconds = () => Math.floor(Date.now() / 1000);

function service(startedAtMs = STARTED_AT_MS) {
  return new JwtService(identityJwtModuleOptions(environment, startedAtMs));
}

const legacy = new JwtService({ secret: SECRET });
const access = { sub: 'user-1', phone: '+967777123456', scope: 'application', sid: 'session-1' };

test('each purpose has its own key, derived from the secret with HKDF and never the secret', () => {
  const expected = (purpose: string) =>
    Buffer.from(hkdfSync('sha256', SECRET, '', `aarast-jwt-${purpose}-v1`, 32));
  assert.deepEqual(jwtSigningKey('access', environment), expected('access'));
  assert.deepEqual(jwtSigningKey('phone-proof', environment), expected('phone-proof'));
  assert.notDeepEqual(jwtSigningKey('access', environment), jwtSigningKey('phone-proof', environment));
  assert.notDeepEqual(jwtSigningKey('access', environment), Buffer.from(SECRET));
});

test('an access token is signed with the access key, and the secret alone does not verify it', () => {
  const token = service().sign(access);
  const [header, payload, signature] = token.split('.');
  const withAccessKey = createHmac('sha256', jwtSigningKey('access', environment))
    .update(`${header}.${payload}`)
    .digest('base64url');
  assert.equal(signature, withAccessKey);
  assert.throws(() => legacy.verify(token));
  assert.equal(service().verify(token).sub, 'user-1');
});

test('a phone proof and an access token cannot stand in for each other', () => {
  const jwt = service();
  const proof = signPhoneProof(jwt, '+967777123456');
  assert.equal(isPhoneProofFor(jwt, proof, '+967777123456'), true);
  // Signed with the phone-proof key: as an access token it fails its signature.
  assert.throws(() => jwt.verify(proof), /invalid signature/);
  assert.equal(isPhoneProofFor(jwt, jwt.sign(access), '+967777123456'), false);
});

test('a token the secret itself signed before this process started is taken until it expires', () => {
  const before = Math.floor(STARTED_AT_MS / 1000) - 60;
  const oldToken = legacy.sign({ ...access, iat: before }, { expiresIn: '15m' });
  assert.deepEqual(jwtVerificationKey(oldToken, 'access', environment, STARTED_AT_MS), SECRET);
  // In the past, so its own expiry refuses it now.
  assert.throws(() => service().verify(oldToken), /jwt expired/);

  const liveOld = legacy.sign({ ...access, iat: nowSeconds() - 60 }, { expiresIn: '15m' });
  assert.equal(service(Date.now()).verify(liveOld).sub, 'user-1');
  const oldProof = legacy.sign(
    { typ: 'phone-proof', phone: '+967777123456', iat: nowSeconds() - 60 },
    { audience: 'aarast:phone-proof', expiresIn: 600 },
  );
  assert.equal(isPhoneProofFor(service(Date.now()), oldProof, '+967777123456'), true);
});

test('a token the secret itself signed after this process started is refused', () => {
  const startedAtMs = Date.now() - 120_000;
  const forged = legacy.sign(access, { expiresIn: '15m' });
  assert.deepEqual(
    jwtVerificationKey(forged, 'access', environment, startedAtMs),
    jwtSigningKey('access', environment),
  );
  assert.throws(() => service(startedAtMs).verify(forged), /invalid signature/);
});

test('the HTTP strategy picks its key the same way', async () => {
  const previous = process.env.JWT_SECRET;
  process.env.JWT_SECRET = SECRET;
  try {
    const strategy = new JwtStrategy({} as never) as unknown as {
      _secretOrKeyProvider: (
        request: unknown,
        token: string,
        done: (error: unknown, key?: string | Buffer) => void,
      ) => void;
    };
    const keyFor = (token: string) =>
      new Promise<string | Buffer | undefined>((resolve, reject) =>
        strategy._secretOrKeyProvider({}, token, (error, key) =>
          error ? reject(error) : resolve(key),
        ),
      );
    const fresh = new JwtService(identityJwtModuleOptions(process.env, Date.now())).sign(access);
    assert.deepEqual(await keyFor(fresh), jwtSigningKey('access', process.env));
    const forged = legacy.sign(access);
    assert.deepEqual(await keyFor(forged), jwtSigningKey('access', process.env));
  } finally {
    if (previous === undefined) delete process.env.JWT_SECRET;
    else process.env.JWT_SECRET = previous;
  }
});

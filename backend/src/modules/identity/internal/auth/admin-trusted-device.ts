import { createHmac, timingSafeEqual } from 'node:crypto';
import { getJwtSecret } from './jwt-secret';

// "Remember this device": after a full password + WhatsApp-code sign-in the
// browser keeps a signed, httpOnly token for 30 days, and the same browser
// then signs in with the password alone. The token carries no secret: it
// names the admin, its expiry, and a fingerprint of the current password
// hash, so changing the password (recovery included) voids every remembered
// device at once. A stolen token is useless without the password.

export const ADMIN_TRUSTED_DEVICE_COOKIE = 'aarast_admin_device';
export const ADMIN_TRUSTED_DEVICE_TTL_MS = 30 * 24 * 60 * 60_000;

function key(environment: NodeJS.ProcessEnv): Buffer {
  return createHmac('sha256', getJwtSecret(environment))
    .update('aarast-admin-trusted-device-v1', 'utf8')
    .digest();
}

function passwordFingerprint(signingKey: Buffer, passwordHash: string): string {
  return createHmac('sha256', signingKey)
    .update(`password:${passwordHash}`, 'utf8')
    .digest('base64url')
    .slice(0, 32);
}

function sign(signingKey: Buffer, payload: string): string {
  return createHmac('sha256', signingKey).update(payload, 'utf8').digest('base64url');
}

export function issueAdminTrustedDevice(
  admin: { id: string; passwordHash: string | null },
  now: Date,
  environment: NodeJS.ProcessEnv = process.env,
): { token: string; expiresAt: Date } {
  // Only issued after a password + code sign-in, so the hash exists.
  if (admin.passwordHash === null) {
    throw new Error('A trusted device needs the administrator password hash');
  }
  const signingKey = key(environment);
  const expiresAt = new Date(now.getTime() + ADMIN_TRUSTED_DEVICE_TTL_MS);
  const payload = [
    admin.id,
    expiresAt.getTime(),
    passwordFingerprint(signingKey, admin.passwordHash),
  ].join('.');
  const token = `${Buffer.from(payload, 'utf8').toString('base64url')}.${sign(signingKey, payload)}`;
  return { token, expiresAt };
}

/** Whether the token was issued to this admin, is unexpired and predates no password change. */
export function isAdminTrustedDevice(
  token: string | null | undefined,
  admin: { id: string; passwordHash: string | null },
  now: Date,
  environment: NodeJS.ProcessEnv = process.env,
): boolean {
  if (!token || token.length > 512 || admin.passwordHash === null) return false;
  const [encoded, signature, extra] = token.split('.');
  if (!encoded || !signature || extra !== undefined) return false;
  const signingKey = key(environment);
  const payload = Buffer.from(encoded, 'base64url').toString('utf8');
  const expected = Buffer.from(sign(signingKey, payload));
  const given = Buffer.from(signature);
  if (expected.length !== given.length || !timingSafeEqual(expected, given)) {
    return false;
  }
  const [userId, expiresAtMs, fingerprint] = payload.split('.');
  return (
    userId === admin.id &&
    Number(expiresAtMs) > now.getTime() &&
    fingerprint === passwordFingerprint(signingKey, admin.passwordHash)
  );
}

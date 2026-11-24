import { createHmac } from 'node:crypto';
import { getJwtSecret } from './jwt-secret';
import { createOpaqueTokenValue, hashRefreshToken } from './refresh-token-policy';

// "Remember this device": after a full password + WhatsApp-code sign-in the
// browser keeps a random, httpOnly token for 30 days, and the same browser
// then signs in with the password alone. RA-AD-26: the device is a row the
// server keeps (`AdminTrustedDevice`), holding the token's digest, the
// admin, the expiry and a fingerprint of the password hash it was issued
// under. So a device can be revoked (the account disabled or provisioned
// again), changing the password (recovery included) voids every remembered
// device at once, and a token the server does not hold trusts nothing. A
// stolen token is useless without the password.

export const ADMIN_TRUSTED_DEVICE_COOKIE = 'aarast_admin_device';
export const ADMIN_TRUSTED_DEVICE_TTL_MS = 30 * 24 * 60 * 60_000;

export interface AdminTrustedDeviceRecord {
  userId: string;
  tokenHash: string;
  passwordFingerprint: string;
  expiresAt: Date;
  revokedAt: Date | null;
}

function key(environment: NodeJS.ProcessEnv): Buffer {
  return createHmac('sha256', getJwtSecret(environment))
    .update('aarast-admin-trusted-device-v1', 'utf8')
    .digest();
}

function passwordFingerprint(
  passwordHash: string,
  environment: NodeJS.ProcessEnv,
): string {
  return createHmac('sha256', key(environment))
    .update(`password:${passwordHash}`, 'utf8')
    .digest('base64url')
    .slice(0, 32);
}

/** A new device token and the row that remembers it. */
export function issueAdminTrustedDevice(
  admin: { id: string; passwordHash: string | null },
  now: Date,
  environment: NodeJS.ProcessEnv = process.env,
): {
  token: string;
  expiresAt: Date;
  record: Omit<AdminTrustedDeviceRecord, 'revokedAt'>;
} {
  // Only issued after a password + code sign-in, so the hash exists.
  if (admin.passwordHash === null) {
    throw new Error('A trusted device needs the administrator password hash');
  }
  const token = createOpaqueTokenValue();
  const expiresAt = new Date(now.getTime() + ADMIN_TRUSTED_DEVICE_TTL_MS);
  return {
    token,
    expiresAt,
    record: {
      userId: admin.id,
      tokenHash: hashRefreshToken(token),
      passwordFingerprint: passwordFingerprint(admin.passwordHash, environment),
      expiresAt,
    },
  };
}

/** The digest a device cookie is looked up by, or null when it is not one. */
export function adminTrustedDeviceTokenHash(
  token: string | null | undefined,
): string | null {
  return token && /^[a-f0-9]{64}$/.test(token) ? hashRefreshToken(token) : null;
}

/** Whether the stored device belongs to this admin, is live and predates no password change. */
export function isAdminTrustedDeviceRecord(
  record: AdminTrustedDeviceRecord | null,
  admin: { id: string; passwordHash: string | null },
  now: Date,
  environment: NodeJS.ProcessEnv = process.env,
): boolean {
  return (
    record !== null &&
    admin.passwordHash !== null &&
    record.userId === admin.id &&
    record.revokedAt === null &&
    record.expiresAt.getTime() > now.getTime() &&
    record.passwordFingerprint === passwordFingerprint(admin.passwordHash, environment)
  );
}

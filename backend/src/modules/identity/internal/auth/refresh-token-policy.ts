import { createHash, randomBytes } from 'node:crypto';

const refreshTokenLifetimeMs = 30 * 24 * 60 * 60 * 1000;
const refreshTokenPrefixes = {
  application: 'aarast_app_',
  admin: 'aarast_admin_',
} as const;

export type RefreshTokenScope = keyof typeof refreshTokenPrefixes;

export function createOpaqueTokenValue(): string {
  return randomBytes(32).toString('hex');
}

export function createRefreshTokenValue(
  scope: RefreshTokenScope = 'application',
): string {
  return `${refreshTokenPrefixes[scope]}${createOpaqueTokenValue()}`;
}

export function isRefreshTokenForScope(
  token: string,
  scope: RefreshTokenScope,
): boolean {
  const prefix = refreshTokenPrefixes[scope];
  return new RegExp(`^${prefix}[a-f0-9]{64}$`).test(token);
}

export function hashRefreshToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

export function refreshTokenExpiry(now = new Date()): Date {
  return new Date(now.getTime() + refreshTokenLifetimeMs);
}

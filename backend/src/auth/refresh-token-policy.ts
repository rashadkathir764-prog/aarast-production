import { createHash, randomBytes } from 'node:crypto';

const refreshTokenLifetimeMs = 30 * 24 * 60 * 60 * 1000;

export function createRefreshTokenValue(): string {
  return randomBytes(32).toString('hex');
}

export function hashRefreshToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

export function refreshTokenExpiry(now = new Date()): Date {
  return new Date(now.getTime() + refreshTokenLifetimeMs);
}

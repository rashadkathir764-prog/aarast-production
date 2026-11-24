import { createHash, timingSafeEqual } from 'node:crypto';

/**
 * The operator's token (METRICS_TOKEN): what reads /metrics and the whole
 * /ready (RA-BE-149). False while none is configured, so nothing internal
 * is open by default.
 */
export function operatorTokenMatches(authorization: string | undefined): boolean {
  const token = process.env.METRICS_TOKEN?.trim();
  if (!token || authorization === undefined) return false;
  const digest = (value: string) => createHash('sha256').update(value, 'utf8').digest();
  return timingSafeEqual(digest(authorization), digest(`Bearer ${token}`));
}

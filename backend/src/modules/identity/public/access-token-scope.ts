import type { JwtPayload } from './jwt-payload.interface';
import type { JwtSessionScope } from './identity-session.types';

/**
 * The realm of an access JWT, or null when the token is not an access token.
 * A purpose token signed with the same secret (a phone proof carries `typ`)
 * is never a session, whatever else it claims.
 */
export function resolveJwtSessionScope(
  payload: JwtPayload,
): JwtSessionScope | null {
  if ((payload as { typ?: unknown }).typ !== undefined) return null;
  if (
    payload.scope === 'application' &&
    payload.amr === undefined &&
    typeof payload.sid === 'string' &&
    payload.sid.length > 0
  ) {
    return 'application';
  }
  if (
    payload.scope === 'admin' &&
    payload.amr === 'admin_mfa' &&
    typeof payload.sid === 'string' &&
    payload.sid.length > 0
  ) {
    return 'admin';
  }
  return null;
}

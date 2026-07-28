import type {
  JwtPayload,
  JwtSessionScope,
} from './jwt-payload.interface';

export function resolveJwtSessionScope(
  payload: JwtPayload,
): JwtSessionScope | null {
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

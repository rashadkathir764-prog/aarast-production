import type { AuthenticatedUser } from '../public/identity-session.types';
import { toSafeUser as mapSafeUser } from '../public/safe-user';
import { permissionsForAdminRole } from '../../backoffice/public/admin-permission.port';

export function toSafeUser(user: AuthenticatedUser, includeAdminMetadata = user.adminMfa === true) {
  return mapSafeUser(user, permissionsForAdminRole, includeAdminMetadata);
}

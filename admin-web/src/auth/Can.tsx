import { ReactNode } from 'react';
import { useAuth } from './AuthProvider';
import { AdminPermission, hasAdminPermission } from './adminPermissions';

export function Can({
  permission,
  children,
}: {
  permission: AdminPermission;
  children: ReactNode;
}) {
  const { user } = useAuth();
  return hasAdminPermission(user, permission) ? <>{children}</> : null;
}

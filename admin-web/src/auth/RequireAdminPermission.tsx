import { ReactNode } from 'react';
import { Navigate } from 'react-router-dom';
import { useAuth } from './AuthProvider';
import { AdminPermission, hasAdminPermission } from './adminPermissions';

export function RequireAdminPermission({
  permission,
  children,
}: {
  permission: AdminPermission;
  children: ReactNode;
}) {
  const { user } = useAuth();
  if (!hasAdminPermission(user, permission)) {
    return <Navigate to="/" replace />;
  }
  return <>{children}</>;
}

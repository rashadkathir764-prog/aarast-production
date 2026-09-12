import { SetMetadata } from '@nestjs/common';
import { AdminPermission } from '../domain/admin-permissions';

export const ADMIN_PERMISSIONS_KEY = 'admin_permissions';

export const RequireAdminPermission = (...permissions: AdminPermission[]) =>
  SetMetadata(ADMIN_PERMISSIONS_KEY, permissions);

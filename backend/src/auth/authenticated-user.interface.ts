import { UserRole, UserStatus } from '@prisma/client';

export interface AuthenticatedUser {
  id: string;
  name: string;
  phone: string | null;
  email: string | null;
  role: UserRole;
  status: UserStatus;
  createdAt: Date;
  updatedAt: Date;
}

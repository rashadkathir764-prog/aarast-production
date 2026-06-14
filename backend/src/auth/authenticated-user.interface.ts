import { UserRole, UserStatus } from '@prisma/client';

export interface AuthenticatedUser {
  id: string;
  name: string;
  phone: string | null;
  email: string | null;
  role: UserRole;
  status: UserStatus;
  phoneVerifiedAt: Date | null;
  lastLoginAt: Date | null;
  avatarUrl: string | null;
  locale: string;
  createdAt: Date;
  updatedAt: Date;
}

import { User } from '@prisma/client';

export interface SafeUser {
  id: string;
  name: string;
  phone: string | null;
  email: string | null;
  role: string;
  status: string;
  createdAt: Date;
  updatedAt: Date;
}

export function toSafeUser(user: User): SafeUser {
  return {
    id: user.id,
    name: user.name,
    phone: user.phone,
    email: user.email,
    role: user.role,
    status: user.status,
    createdAt: user.createdAt,
    updatedAt: user.updatedAt,
  };
}

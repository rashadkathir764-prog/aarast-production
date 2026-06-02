import { AuthenticatedUser } from './authenticated-user.interface';

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

export function toSafeUser(user: AuthenticatedUser): SafeUser {
  return toAuthenticatedUser(user);
}

export function toAuthenticatedUser(user: AuthenticatedUser): AuthenticatedUser {
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

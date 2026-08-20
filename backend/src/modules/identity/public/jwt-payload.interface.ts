import type { JwtSessionScope } from './identity-session.types';

export interface JwtPayload {
  sub: string;
  phone: string | null;
  scope: JwtSessionScope;
  amr?: 'admin_mfa';
  sid?: string;
}

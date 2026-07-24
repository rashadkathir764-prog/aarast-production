export type JwtSessionScope = 'application' | 'admin';

export interface JwtPayload {
  sub: string;
  phone: string | null;
  scope: JwtSessionScope;
  amr?: 'admin_mfa';
  sid?: string;
}

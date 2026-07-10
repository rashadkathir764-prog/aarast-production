export interface JwtPayload {
  sub: string;
  phone: string | null;
  amr?: 'admin_mfa';
  sid?: string;
}

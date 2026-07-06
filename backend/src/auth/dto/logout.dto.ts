import { IsOptional, IsString, MaxLength } from 'class-validator';

/**
 * Body for POST /auth/logout.
 *
 * `refreshToken` is optional. When present, only that specific device's
 * session is revoked. When absent (e.g. the client lost the token but still
 * has a valid access JWT), the caller's userId is derived from the JWT and
 * ALL of that user's refresh tokens are revoked (logout everywhere).
 */
export class LogoutDto {
  @IsOptional()
  @IsString()
  @MaxLength(256)
  refreshToken?: string;
}
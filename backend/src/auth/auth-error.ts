import { HttpException, HttpStatus } from '@nestjs/common';

export const AuthErrorCode = {
  INVALID_CREDENTIALS: 'INVALID_CREDENTIALS',
  PHONE_VERIFICATION_REQUIRED: 'PHONE_VERIFICATION_REQUIRED',
  ACCOUNT_ALREADY_EXISTS: 'ACCOUNT_ALREADY_EXISTS',
  ADMIN_APP_PASSWORD_ALREADY_SET: 'ADMIN_APP_PASSWORD_ALREADY_SET',
  OTP_INVALID_OR_EXPIRED: 'OTP_INVALID_OR_EXPIRED',
  ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF: 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF',
  ACCOUNT_DISABLED_AFTER_PHONE_PROOF: 'ACCOUNT_DISABLED_AFTER_PHONE_PROOF',
  INVITE_NOT_FOUND_FOR_PHONE: 'INVITE_NOT_FOUND_FOR_PHONE',
  ADMIN_RESET_INVALID_OR_EXPIRED: 'ADMIN_RESET_INVALID_OR_EXPIRED',
} as const;

export type AuthErrorCode =
  (typeof AuthErrorCode)[keyof typeof AuthErrorCode];

export function authError(
  statusCode: HttpStatus,
  code: AuthErrorCode,
  message: string,
): HttpException {
  return new HttpException({ statusCode, code, message }, statusCode);
}

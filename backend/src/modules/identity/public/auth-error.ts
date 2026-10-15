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
  INVITE_ACCOUNT_SETUP_REQUIRED: 'INVITE_ACCOUNT_SETUP_REQUIRED',
  ADMIN_RESET_INVALID_OR_EXPIRED: 'ADMIN_RESET_INVALID_OR_EXPIRED',
  OTP_DELIVERY_UNAVAILABLE: 'OTP_DELIVERY_UNAVAILABLE',
} as const;

export type AuthErrorCode = (typeof AuthErrorCode)[keyof typeof AuthErrorCode];

export function authError(
  statusCode: HttpStatus,
  code: AuthErrorCode,
  message: string,
): HttpException {
  return new HttpException({ statusCode, code, message }, statusCode);
}

// The WhatsApp channel cannot tell a number without WhatsApp from a channel
// outage, so the message names both causes the user can act on.
export const OTP_DELIVERY_UNAVAILABLE_MESSAGE =
  'تعذر إرسال رمز التحقق عبر واتساب. تأكد أن الرقم صحيح وعليه واتساب، ثم حاول مرة أخرى.';

export function otpDeliveryUnavailableError(): HttpException {
  return authError(
    HttpStatus.SERVICE_UNAVAILABLE,
    AuthErrorCode.OTP_DELIVERY_UNAVAILABLE,
    OTP_DELIVERY_UNAVAILABLE_MESSAGE,
  );
}

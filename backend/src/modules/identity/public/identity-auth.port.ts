import type { OtpPurpose } from '@prisma/client';

export const IDENTITY_AUTH_PORT = Symbol('IDENTITY_AUTH_PORT');
export const IDENTITY_ACCESS_TOKEN_VERIFIER = Symbol(
  'IDENTITY_ACCESS_TOKEN_VERIFIER',
);

export interface OtpDispatchContext {
  ip?: string | null;
}

export interface InviteOtpRequestResponse {
  phone: string;
  purpose: OtpPurpose;
  expiresAt: Date;
  delivery: 'LOCAL_DEV' | 'WHATSAPP';
  deliveryStatus: 'LOCAL_DEV' | 'DELIVERED' | 'PENDING' | 'UNCERTAIN';
  code?: string;
  message?: string;
}

export interface InviteOtpVerifyInput {
  token: string;
  phone: string;
  code: string;
  name?: string;
  password?: string;
}

export interface InviteOtpVerifyResponse {
  verified: true;
  phone: string;
  purpose: OtpPurpose;
  user?: unknown;
  accessToken?: string;
  refreshToken?: string;
  refreshTokenExpiresAt?: Date;
}

export interface IdentityAuthPort {
  requestInviteOtp(
    phoneInput: string,
    planInviteIdInput: string,
    expectedTokenHashInput: string,
    context?: OtpDispatchContext,
    allowAcceptedCredentialRecovery?: boolean,
  ): Promise<InviteOtpRequestResponse>;
  verifyInviteOtp(
    input: InviteOtpVerifyInput,
  ): Promise<InviteOtpVerifyResponse>;
}

export interface IdentityAccessTokenVerifier {
  verifyAsync<T extends object>(token: string): Promise<T>;
}

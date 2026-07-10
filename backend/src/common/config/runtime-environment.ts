import { loadWhatsAppOtpConfig } from '../../auth/whatsapp-otp-config';

export function isProductionEnvironment(
  environment: NodeJS.ProcessEnv = process.env,
): boolean {
  return environment.NODE_ENV === 'production';
}

export function validateRuntimeEnvironment(
  environment: NodeJS.ProcessEnv = process.env,
): void {
  const missing = ['DATABASE_URL', 'JWT_SECRET'].filter(
    (name) => !environment[name]?.trim(),
  );
  if (missing.length > 0) {
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }

  const otpMode = environment.AUTH_OTP_MODE?.trim().toLowerCase();
  if (otpMode && !['dev', 'whatsapp', 'disabled'].includes(otpMode)) {
    throw new Error(
      `AUTH_OTP_MODE must be one of dev|whatsapp|disabled, got "${otpMode}"`,
    );
  }

  if (environment.NODE_ENV === 'production' && !otpMode) {
    throw new Error('AUTH_OTP_MODE is required in production');
  }

  if (environment.NODE_ENV === 'production' && otpMode === 'dev') {
    throw new Error('AUTH_OTP_MODE=dev is forbidden in production');
  }

  if (otpMode === 'whatsapp') {
    loadWhatsAppOtpConfig(environment);
  }
}

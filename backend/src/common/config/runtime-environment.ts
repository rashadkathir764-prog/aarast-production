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

  if (
    environment.NODE_ENV === 'production' &&
    !environment.AUTH_LOGIN_THROTTLE_PEPPER?.trim()
  ) {
    throw new Error('AUTH_LOGIN_THROTTLE_PEPPER is required in production');
  }

  validateProductionMediaEndpoints(environment);

  if (otpMode === 'whatsapp') {
    loadWhatsAppOtpConfig(environment);
  }
}

function validateProductionMediaEndpoints(
  environment: NodeJS.ProcessEnv,
): void {
  if (environment.NODE_ENV !== 'production') return;
  const requiredByReadiness =
    environment.READINESS_REQUIRE_MEDIA?.trim().toLowerCase() === 'true';
  const mediaConfigured = [
    environment.AARAST_MEDIA_ENDPOINT,
    environment.AARAST_MEDIA_SIGNED_ENDPOINT,
    environment.AARAST_MEDIA_BUCKET,
    environment.AARAST_MEDIA_PUBLIC_BASE_URL,
  ].some((value) => Boolean(value?.trim()));
  if (!requiredByReadiness && !mediaConfigured) return;

  const missing = [
    'AARAST_MEDIA_ENDPOINT',
    'AARAST_MEDIA_BUCKET',
    'AARAST_MEDIA_PUBLIC_BASE_URL',
  ].filter((name) => !environment[name]?.trim());
  if (missing.length > 0) {
    throw new Error(
      `Missing required media environment variables: ${missing.join(', ')}`,
    );
  }

  const signedEndpoint =
    environment.AARAST_MEDIA_SIGNED_ENDPOINT?.trim() ||
    environment.AARAST_MEDIA_ENDPOINT!.trim();
  for (const [name, rawValue] of [
    ['AARAST_MEDIA_SIGNED_ENDPOINT', signedEndpoint],
    [
      'AARAST_MEDIA_PUBLIC_BASE_URL',
      environment.AARAST_MEDIA_PUBLIC_BASE_URL!.trim(),
    ],
  ] as const) {
    let url: URL;
    try {
      url = new URL(rawValue);
    } catch {
      throw new Error(`${name} must be a valid absolute URL`);
    }
    if (url.protocol !== 'https:') {
      throw new Error(`${name} must use HTTPS in production`);
    }
  }
}

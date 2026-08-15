import { loadWhatsAppOtpConfig } from "../otp-transport/whatsapp-otp-config";
import { loadOpenWaOtpConfig } from "../otp-transport/openwa-otp-config";

export type IdentitySecretValidator = (
  environment: NodeJS.ProcessEnv,
) => void;

export function isProductionEnvironment(
  environment: NodeJS.ProcessEnv = process.env,
): boolean {
  return environment.NODE_ENV === "production";
}

export function validateRuntimeEnvironment(
  environment: NodeJS.ProcessEnv,
  validateIdentitySecret: IdentitySecretValidator,
): void {
  const missing = ["DATABASE_URL", "JWT_SECRET"].filter(
    (name) => !environment[name]?.trim(),
  );
  if (missing.length > 0) {
    throw new Error(
      `Missing required environment variables: ${missing.join(", ")}`,
    );
  }
  validateIdentitySecret(environment);

  const otpMode = environment.AUTH_OTP_MODE?.trim().toLowerCase();
  if (otpMode && !["dev", "whatsapp", "openwa", "disabled"].includes(otpMode)) {
    throw new Error(
      `AUTH_OTP_MODE must be one of dev|whatsapp|openwa|disabled, got "${otpMode}"`,
    );
  }

  if (environment.NODE_ENV === "production" && !otpMode) {
    throw new Error("AUTH_OTP_MODE is required in production");
  }

  if (environment.NODE_ENV === "production" && otpMode === "dev") {
    throw new Error("AUTH_OTP_MODE=dev is forbidden in production");
  }

  if (
    environment.NODE_ENV === "production" &&
    !environment.AUTH_LOGIN_THROTTLE_PEPPER?.trim()
  ) {
    throw new Error("AUTH_LOGIN_THROTTLE_PEPPER is required in production");
  }

  const globalOtpLimit = Number(environment.OTP_GLOBAL_DAILY_LIMIT ?? 150);
  if (
    !Number.isInteger(globalOtpLimit) ||
    globalOtpLimit < 1 ||
    globalOtpLimit > 10_000
  ) {
    throw new Error(
      "OTP_GLOBAL_DAILY_LIMIT must be an integer from 1 to 10000",
    );
  }

  const pushNotificationsEnabled =
    environment.PUSH_NOTIFICATIONS_ENABLED?.trim().toLowerCase();
  if (
    pushNotificationsEnabled &&
    !["true", "false"].includes(pushNotificationsEnabled)
  ) {
    throw new Error("PUSH_NOTIFICATIONS_ENABLED must be true or false");
  }
  if (
    pushNotificationsEnabled === "true" &&
    !environment.FIREBASE_PROJECT_ID?.trim()
  ) {
    throw new Error(
      "FIREBASE_PROJECT_ID is required when push notifications are enabled",
    );
  }

  validateProductionMediaEndpoints(environment);

  if (otpMode === "whatsapp") {
    loadWhatsAppOtpConfig(environment);
  }
  if (otpMode === "openwa") {
    loadOpenWaOtpConfig(environment);
  }
}

function validateProductionMediaEndpoints(
  environment: NodeJS.ProcessEnv,
): void {
  if (environment.NODE_ENV !== "production") return;
  const requiredByReadiness =
    environment.READINESS_REQUIRE_MEDIA?.trim().toLowerCase() === "true";
  const mediaConfigured = [
    environment.AARAST_MEDIA_ENDPOINT,
    environment.AARAST_MEDIA_SIGNED_ENDPOINT,
    environment.AARAST_MEDIA_BUCKET,
    environment.AARAST_MEDIA_PUBLIC_BASE_URL,
  ].some((value) => Boolean(value?.trim()));
  if (!requiredByReadiness && !mediaConfigured) return;

  const missing = [
    "AARAST_MEDIA_ENDPOINT",
    "AARAST_MEDIA_SIGNED_ENDPOINT",
    "AARAST_MEDIA_BUCKET",
    "AARAST_MEDIA_PUBLIC_BASE_URL",
  ].filter((name) => !environment[name]?.trim());
  if (missing.length > 0) {
    throw new Error(
      `Missing required media environment variables: ${missing.join(", ")}`,
    );
  }

  const signedEndpoint = environment.AARAST_MEDIA_SIGNED_ENDPOINT!.trim();
  for (const [name, rawValue] of [
    ["AARAST_MEDIA_SIGNED_ENDPOINT", signedEndpoint],
    [
      "AARAST_MEDIA_PUBLIC_BASE_URL",
      environment.AARAST_MEDIA_PUBLIC_BASE_URL!.trim(),
    ],
  ] as const) {
    let url: URL;
    try {
      url = new URL(rawValue);
    } catch {
      throw new Error(`${name} must be a valid absolute URL`);
    }
    if (url.protocol !== "https:") {
      throw new Error(`${name} must use HTTPS in production`);
    }
  }
}

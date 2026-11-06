import { loadWhatsAppOtpConfig } from "../otp-transport/whatsapp-otp-config";
import { loadOpenWaOtpConfig } from "../otp-transport/openwa-otp-config";
import { minClientContract } from "../http/client-contract";

export type IdentitySecretValidator = (
  environment: NodeJS.ProcessEnv,
) => void;

export function isProductionEnvironment(
  environment: NodeJS.ProcessEnv = process.env,
): boolean {
  return environment.NODE_ENV === "production";
}

/**
 * How many WhatsApp codes the whole app may send in a rolling day (J1-19).
 * One reading for the start-up check, the quota and the readiness signal
 * (RA-BE-02); the quota used to read the variable again on its own.
 */
export function otpGlobalDailyLimit(
  environment: NodeJS.ProcessEnv = process.env,
): number {
  const limit = Number(environment.OTP_GLOBAL_DAILY_LIMIT ?? 150);
  if (!Number.isInteger(limit) || limit < 1 || limit > 10_000) {
    throw new Error("OTP_GLOBAL_DAILY_LIMIT must be an integer from 1 to 10000");
  }
  return limit;
}

/** The share of the daily limit at which the readiness check warns. */
export const OTP_CAPACITY_WARNING_SHARE = 0.8;

export function validateRuntimeEnvironment(
  environment: NodeJS.ProcessEnv,
  validateIdentitySecret: IdentitySecretValidator,
): void {
  // RA-BE-01: a broken minimum app contract stops the boot.
  minClientContract(environment);
  const missing = ["DATABASE_URL", "JWT_SECRET"].filter(
    (name) => !environment[name]?.trim(),
  );
  if (missing.length > 0) {
    throw new Error(
      `Missing required environment variables: ${missing.join(", ")}`,
    );
  }
  validateIdentitySecret(environment);

  const deploymentTier = environment.AARAST_DEPLOYMENT_TIER?.trim().toLowerCase();
  if (deploymentTier && deploymentTier !== "staging") {
    throw new Error("AARAST_DEPLOYMENT_TIER must be staging when set");
  }
  if (deploymentTier === "staging") {
    const routeProfile = environment.AARAST_STAGING_ROUTE_PROFILE?.trim() || "isolated";
    const expectedDatabaseHost = routeProfile === "aarast-controlled-cutover"
      ? "aarast-staging-postgres" : "postgres";
    let databaseUrl: URL;
    try {
      databaseUrl = new URL(environment.DATABASE_URL!);
    } catch {
      throw new Error("Staging deployment identity requires an isolated database");
    }
    if (
      environment.NODE_ENV !== "production" ||
      environment.POSTGRES_DB !== "aarast_staging" ||
      environment.AARAST_DB_EXPECTED_ROLE !== "aarast_stage_runtime" ||
      !["isolated", "aarast-controlled-cutover"].includes(routeProfile) ||
      databaseUrl.hostname !== expectedDatabaseHost ||
      databaseUrl.pathname !== "/aarast_staging"
    ) {
      throw new Error("Staging deployment identity requires the staging database and runtime role");
    }
  }

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

  otpGlobalDailyLimit(environment);

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

  if (deploymentTier === "staging") {
    if (pushNotificationsEnabled === "true") {
      if (
        environment.FIREBASE_PROJECT_ID !== "aarast-staging-qa" ||
        environment.GOOGLE_APPLICATION_CREDENTIALS !==
          "/run/aarast-firebase/service-account.json"
      ) {
        throw new Error("Staging Firebase must use its dedicated project and credential path");
      }
    } else if (
      pushNotificationsEnabled !== "false" ||
      environment.FIREBASE_PROJECT_ID?.trim() ||
      environment.GOOGLE_APPLICATION_CREDENTIALS?.trim()
    ) {
      throw new Error("Staging Firebase must be explicitly disabled without credentials");
    }
    if (otpMode === "openwa") {
      let endpoint: URL;
      try {
        endpoint = new URL(environment.OPENWA_BASE_URL ?? "");
      } catch {
        throw new Error("Staging OpenWA requires an isolated endpoint");
      }
      if (
        !/(?:staging|test)/i.test(endpoint.hostname) ||
        /^(?:aarast-openwa-otp|otp-lab-api\.shadowgardn\.com)$/i.test(
          endpoint.hostname,
        ) ||
        environment.OPENWA_CREDENTIAL_FILE !==
          "/run/aarast-openwa-staging/openwa.env" ||
        environment.OPENWA_SESSION_ID?.trim() ||
        environment.OPENWA_API_KEY?.trim()
      ) {
        throw new Error("Staging OpenWA must use its dedicated endpoint and credential file");
      }
    } else if (
      otpMode !== "disabled" ||
      Object.keys(environment).some((key) => key.startsWith("OPENWA_") &&
        Boolean(environment[key]?.trim()))
    ) {
      throw new Error("Staging OpenWA must be isolated or explicitly disabled");
    }
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

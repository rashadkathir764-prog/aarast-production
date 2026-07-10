export interface WhatsAppOtpConfig {
  apiVersion: string;
  phoneNumberId: string;
  accessToken: string;
  templateName: string;
  templateLanguage: string;
  timeoutMs: number;
}

const requiredEnvironmentVariables = [
  'WHATSAPP_GRAPH_API_VERSION',
  'WHATSAPP_PHONE_NUMBER_ID',
  'WHATSAPP_ACCESS_TOKEN',
  'WHATSAPP_OTP_TEMPLATE_NAME',
  'WHATSAPP_OTP_TEMPLATE_LANGUAGE',
] as const;

export function loadWhatsAppOtpConfig(
  environment: NodeJS.ProcessEnv = process.env,
): WhatsAppOtpConfig {
  const missing = requiredEnvironmentVariables.filter(
    (name) => !environment[name]?.trim(),
  );
  if (missing.length > 0) {
    throw new Error(
      `WhatsApp OTP is missing required environment variables: ${missing.join(', ')}`,
    );
  }

  const apiVersion = environment.WHATSAPP_GRAPH_API_VERSION!.trim();
  const phoneNumberId = environment.WHATSAPP_PHONE_NUMBER_ID!.trim();
  const accessToken = environment.WHATSAPP_ACCESS_TOKEN!.trim();
  const templateName = environment.WHATSAPP_OTP_TEMPLATE_NAME!.trim();
  const templateLanguage = environment.WHATSAPP_OTP_TEMPLATE_LANGUAGE!.trim();

  if (!/^v\d+\.\d+$/.test(apiVersion)) {
    throw new Error('WHATSAPP_GRAPH_API_VERSION must look like v23.0');
  }
  if (!/^\d+$/.test(phoneNumberId)) {
    throw new Error('WHATSAPP_PHONE_NUMBER_ID must contain digits only');
  }
  if (accessToken.length < 20) {
    throw new Error('WHATSAPP_ACCESS_TOKEN is not configured');
  }
  if (!/^[a-z0-9_]+$/.test(templateName)) {
    throw new Error(
      'WHATSAPP_OTP_TEMPLATE_NAME must use lowercase letters, digits, and underscores',
    );
  }
  if (!/^[A-Za-z]{2,3}(?:_[A-Za-z]{2})?$/.test(templateLanguage)) {
    throw new Error('WHATSAPP_OTP_TEMPLATE_LANGUAGE is invalid');
  }

  const configuredTimeout = Number(environment.WHATSAPP_OTP_TIMEOUT_MS ?? 10_000);
  const timeoutMs =
    Number.isFinite(configuredTimeout) && configuredTimeout >= 1_000
      ? Math.min(Math.floor(configuredTimeout), 30_000)
      : 10_000;

  return {
    apiVersion,
    phoneNumberId,
    accessToken,
    templateName,
    templateLanguage,
    timeoutMs,
  };
}

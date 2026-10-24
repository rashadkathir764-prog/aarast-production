/// Where people reach the Aarast team (g10). Set at build time with
/// `--dart-define=AARAST_SUPPORT_WHATSAPP=+967...`; without it the WhatsApp
/// card is left out rather than showing a number nobody answers.
class SupportConfig {
  const SupportConfig._();

  static const whatsApp = String.fromEnvironment('AARAST_SUPPORT_WHATSAPP');
}

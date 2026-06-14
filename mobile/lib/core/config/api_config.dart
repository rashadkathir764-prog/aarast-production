class ApiConfig {
  const ApiConfig._();

  static final baseUrl = _normalizeBaseUrl(_rawBaseUrl);

  static const _rawBaseUrl = String.fromEnvironment(
    'AARAST_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3115',
  );

  static String _normalizeBaseUrl(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}

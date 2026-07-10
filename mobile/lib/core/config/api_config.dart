class ApiConfig {
  const ApiConfig._();

  static final baseUrl = _normalizeBaseUrl(_rawBaseUrl);

  static const _isProductBuild = bool.fromEnvironment('dart.vm.product');
  static const _hasExplicitBaseUrl = bool.hasEnvironment('AARAST_API_BASE_URL');
  static const _devBypassLoginGates = bool.fromEnvironment(
    'AARAST_DEV_BYPASS_LOGIN_GATES',
    defaultValue: false,
  );

  static const _rawBaseUrl = String.fromEnvironment(
    'AARAST_API_BASE_URL',
    defaultValue: 'http://127.0.0.1:3115',
  );

  /// Fails closed before storage, providers, or network clients are created.
  /// Local debug/profile development keeps the localhost default, while a
  /// product build must receive an explicit, public HTTPS API origin.
  static void validateForStartup() {
    validateReleaseConfiguration(
      isProductBuild: _isProductBuild,
      hasExplicitBaseUrl: _hasExplicitBaseUrl,
      baseUrl: baseUrl,
      devBypassLoginGates: _devBypassLoginGates,
    );
  }

  static void validateReleaseConfiguration({
    required bool isProductBuild,
    required bool hasExplicitBaseUrl,
    required String baseUrl,
    required bool devBypassLoginGates,
  }) {
    if (!isProductBuild) return;

    if (!hasExplicitBaseUrl) {
      throw StateError(
        'Release builds require --dart-define='
        'AARAST_API_BASE_URL=https://your-production-api.',
      );
    }
    if (devBypassLoginGates) {
      throw StateError(
        'AARAST_DEV_BYPASS_LOGIN_GATES must stay disabled in release builds.',
      );
    }

    final uri = Uri.tryParse(baseUrl.trim());
    if (uri == null ||
        uri.scheme.toLowerCase() != 'https' ||
        !uri.hasAuthority ||
        uri.host.trim().isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        _isLocalOrPrivateHost(uri.host)) {
      throw StateError(
        'AARAST_API_BASE_URL must be a public HTTPS origin without '
        'credentials, query parameters, or fragments.',
      );
    }
  }

  static String _normalizeBaseUrl(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  static bool _isLocalOrPrivateHost(String value) {
    final host = value.trim().toLowerCase();
    if (host == 'localhost' ||
        host.endsWith('.localhost') ||
        host == '::1' ||
        host.contains(':') ||
        host == '0.0.0.0') {
      return true;
    }

    final octets = host.split('.').map(int.tryParse).toList(growable: false);
    final looksNumeric = RegExp(r'^[0-9.]+$').hasMatch(host);
    if (octets.length != 4 || octets.any((octet) => octet == null)) {
      return looksNumeric;
    }
    if (octets.any((octet) => octet! < 0 || octet > 255)) {
      return true;
    }
    if (!looksNumeric) {
      return false;
    }
    final first = octets[0]!;
    final second = octets[1]!;
    return first == 10 ||
        first == 127 ||
        (first == 169 && second == 254) ||
        (first == 172 && second >= 16 && second <= 31) ||
        (first == 192 && second == 168);
  }
}

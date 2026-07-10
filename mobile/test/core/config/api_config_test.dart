import 'package:aarast_mobile/core/config/api_config.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('release API configuration', () {
    test('debug builds may use the local development default', () {
      expect(
        () => ApiConfig.validateReleaseConfiguration(
          isProductBuild: false,
          hasExplicitBaseUrl: false,
          baseUrl: 'http://127.0.0.1:3115',
          devBypassLoginGates: true,
        ),
        returnsNormally,
      );
    });

    test('release requires an explicit API URL', () {
      expect(
        () => ApiConfig.validateReleaseConfiguration(
          isProductBuild: true,
          hasExplicitBaseUrl: false,
          baseUrl: 'http://127.0.0.1:3115',
          devBypassLoginGates: false,
        ),
        throwsStateError,
      );
    });

    test('release rejects HTTP, local networks, and URL credentials', () {
      for (final value in [
        'http://api.example.com',
        'https://127.0.0.1:3115',
        'https://10.0.0.8',
        'https://172.16.2.5',
        'https://192.168.1.10',
        'https://[::1]',
        'https://[fc00::1]',
        'https://999.1.1.1',
        'https://127.0.0',
        'https://user:password@api.example.com',
        'https://api.example.com?token=value',
        'https://api.example.com/#fragment',
      ]) {
        expect(
          () => ApiConfig.validateReleaseConfiguration(
            isProductBuild: true,
            hasExplicitBaseUrl: true,
            baseUrl: value,
            devBypassLoginGates: false,
          ),
          throwsStateError,
          reason: value,
        );
      }
    });

    test('release rejects the development auth bypass', () {
      expect(
        () => ApiConfig.validateReleaseConfiguration(
          isProductBuild: true,
          hasExplicitBaseUrl: true,
          baseUrl: 'https://aarast-api.shadowgardn.com',
          devBypassLoginGates: true,
        ),
        throwsStateError,
      );
    });

    test('release accepts a public HTTPS API origin', () {
      expect(
        () => ApiConfig.validateReleaseConfiguration(
          isProductBuild: true,
          hasExplicitBaseUrl: true,
          baseUrl: 'https://aarast-api.shadowgardn.com',
          devBypassLoginGates: false,
        ),
        returnsNormally,
      );
    });
  });
}

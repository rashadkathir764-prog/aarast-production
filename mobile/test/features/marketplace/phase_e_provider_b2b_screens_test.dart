import 'dart:io';

import 'package:aarast_mobile/core/utils/currency_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase E provider B2B screens contract', () {
    final screenPaths = <String>[
      'lib/features/marketplace/screens/provider_apply_screen.dart',
      'lib/features/marketplace/screens/edit_provider_profile_screen.dart',
      'lib/features/marketplace/screens/add_provider_service_screen.dart',
      'lib/features/marketplace/screens/add_provider_package_screen.dart',
    ];

    test('provider B2B screens use Lucide and avoid stale UI leaks', () {
      for (final path in screenPaths) {
        final source = File(path).readAsStringSync();
        expect(source, contains('LucideIcons.'), reason: path);
        expect(
          source,
          isNot(matches(RegExp(r'(?<!Lucide)Icons\.'))),
          reason: path,
        );
        expect(source, isNot(contains('AarastComingSoonScreen')), reason: path);
        expect(source, isNot(contains('PLANNING')), reason: path);
        expect(source, isNot(contains('placeholder')), reason: path);
        expect(source, isNot(contains('Mock progress')), reason: path);
      }
    });

    test('provider service and package forms keep Arabic currency UI', () {
      for (final path in [
        'lib/features/marketplace/screens/add_provider_service_screen.dart',
        'lib/features/marketplace/screens/add_provider_package_screen.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, contains('currencyLabelAr(defaultCurrencyCode)'));
        expect(source, contains('currency: defaultCurrencyCode'));
        expect(source, isNot(contains("currency: 'YER'")));
      }

      expect(currencyLabelAr(defaultCurrencyCode), 'ر.ي');
    });

    test('provider portal formats visible prices through Arabic labels', () {
      final source = File(
        'lib/features/marketplace/screens/provider_portal_tabs.dart',
      ).readAsStringSync();

      expect(source, contains('currencyLabelAr(service.currency)'));
      expect(source, contains('currencyLabelAr(item.currency)'));
      expect(source, isNot(contains('250000 YER')));
    });
  });
}

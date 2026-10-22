import 'dart:io';

import 'package:aarast_mobile/core/utils/currency_label.dart';
import 'package:aarast_mobile/features/provider_portal/screens/provider_apply_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase E provider B2B screens contract', () {
    final screenPaths = <String>[
      'lib/features/provider_portal/screens/provider_apply_screen.dart',
      'lib/features/provider_portal/screens/edit_provider_profile_screen.dart',
      'lib/features/provider_portal/screens/add_provider_service_screen.dart',
      'lib/features/provider_portal/screens/add_provider_package_screen.dart',
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
        'lib/features/provider_portal/screens/add_provider_service_screen.dart',
        'lib/features/provider_portal/screens/add_provider_package_screen.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, contains('currencyLabelAr(defaultCurrencyCode)'));
        expect(source, contains('currency: defaultCurrencyCode'));
        expect(source, isNot(contains("currency: 'YER'")));
      }

      expect(currencyLabelAr(defaultCurrencyCode), 'ر.ي');
    });

    testWidgets(
      'submitted provider application offers home return without customer browsing',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: ProviderApplyStatusScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('العودة للرئيسية'), findsOneWidget);
        expect(find.text('فتح المزودين'), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
      },
    );

    test('provider portal is split into bounded real tab libraries', () {
      final barrel = File(
        'lib/features/provider_portal/screens/provider_portal_tabs.dart',
      ).readAsStringSync();
      const tabFiles = [
        'provider_home_tab.dart',
        'provider_requests_tab.dart',
        'provider_services_tab.dart',
        'provider_profile_tab.dart',
      ];
      final sources = <String>[];
      for (final name in tabFiles) {
        final file = File('lib/features/provider_portal/screens/$name');
        expect(file.existsSync(), isTrue, reason: name);
        final source = file.readAsStringSync();
        expect(source.split('\n').length, lessThanOrEqualTo(500), reason: name);
        expect(source, isNot(contains('part of ')), reason: name);
        expect(barrel, contains("export '$name';"), reason: name);
        sources.add(source);
      }

      final executableBarrelLines = barrel
          .split('\n')
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty && !line.startsWith('//'));
      expect(
        executableBarrelLines.every((line) => line.startsWith('export ')),
        isTrue,
      );

      final source = sources.join('\n');

      expect(source, contains('currencyLabelAr(service.currency)'));
      expect(source, contains('currencyLabelAr(item.currency)'));
      expect(source, contains('class ProviderHomeTab'));
      expect(source, contains('class ProviderRequestsTab'));
      expect(source, contains('class ProviderServicesTab'));
      expect(source, contains('class ProviderProfileTab'));
      expect(source, isNot(contains('250000 YER')));
    });
  });
}

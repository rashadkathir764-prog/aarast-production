import 'dart:io';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/utils/currency_label.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/create_wedding_plan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  group('Phase D account and settings screens contract', () {
    final screenPaths = <String>[
      'lib/features/more/screens/more_screen.dart',
      'lib/features/wedding_plans/screens/create_wedding_plan_screen.dart',
      'lib/features/auth/screens/register_screen.dart',
      'lib/features/settings/screens/settings_screen.dart',
      'lib/features/support/screens/support_screen.dart',
      'lib/features/auth/screens/splash_screen.dart',
    ];

    test('phase D screens avoid stale Material icons and placeholders', () {
      for (final path in screenPaths) {
        final source = File(path).readAsStringSync();
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

    test('interactive account screens use Lucide where icons are visible', () {
      for (final path in screenPaths.where(
        (path) => !path.endsWith('splash_screen.dart'),
      )) {
        final source = File(path).readAsStringSync();
        expect(source, contains('LucideIcons.'), reason: path);
      }
    });

    test(
      'create wedding plan displays Arabic currency but preserves API code',
      () {
        final source = File(
          'lib/features/wedding_plans/screens/create_wedding_plan_screen.dart',
        ).readAsStringSync();
        final sharedForm = File(
          'lib/features/wedding_plans/widgets/wedding_plan_creation_form.dart',
        ).readAsStringSync();

        expect(source, isNot(contains("TextEditingController(text: 'YER')")));
        expect(source, isNot(contains("? 'YER'")));
        expect(source, contains('WeddingPlanCreationFields('));
        expect(source, contains('currency: _currency'));
        expect(sharedForm, contains("value: 'YER', child: Text('ر.ي')"));
        expect(sharedForm, contains("value: 'SAR', child: Text('ر.س')"));
        expect(currencyLabelAr(defaultCurrencyCode), 'ر.ي');
        expect(currencyCodeFromDisplayInput('ر.ي'), defaultCurrencyCode);
        expect(currencyCodeFromDisplayInput('ر.س'), 'SAR');
      },
    );
  });

  group('Phase D create wedding plan rendering', () {
    testWidgets('create plan shows Arabic currency instead of raw code', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(360, 780));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final apiClient = ApiClient(tokenProvider: () async => null);
      final provider = WeddingPlansProvider(WeddingPlansApi(apiClient));

      await tester.pumpWidget(
        ChangeNotifierProvider<WeddingPlansProvider>.value(
          value: provider,
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const CreateWeddingPlanScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('إنشاء خطة زفاف'), findsOneWidget);
      expect(find.text('ميزانية أولية'), findsOneWidget);
      await tester.ensureVisible(find.text('ميزانية أولية'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ميزانية أولية'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ر.ي'), findsWidgets);
      expect(find.textContaining('YER'), findsNothing);
      expect(find.text('تفاصيل عنوان إضافية'), findsOneWidget);
      expect(find.text('المنطقة أو العزلة'), findsOneWidget);
      expect(find.text('الحي'), findsOneWidget);
      expect(find.text('الشارع أو أقرب معلم'), findsNothing);

      await tester.tap(find.text('تفاصيل عنوان إضافية'));
      await tester.pumpAndSettle();

      expect(find.text('الشارع أو أقرب معلم'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}

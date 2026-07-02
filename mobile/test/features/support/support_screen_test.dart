import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/support/screens/support_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  testWidgets(
    'support screen is actionable and not a coming soon placeholder',
    (tester) async {
      final router = GoRouter(
        initialLocation: AppRouter.support,
        routes: [
          GoRoute(
            path: AppRouter.support,
            builder: (context, state) => const SupportScreen(),
          ),
          GoRoute(
            path: AppRouter.settings,
            builder: (context, state) =>
                const Scaffold(body: Text('settings-opened')),
          ),
          GoRoute(
            path: AppRouter.notifications,
            builder: (context, state) =>
                const Scaffold(body: Text('notifications-opened')),
          ),
          GoRoute(
            path: AppRouter.sharedWeddingPlans,
            builder: (context, state) =>
                const Scaffold(body: Text('shared-plans-opened')),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();

      expect(find.text('الدعم والمساعدة'), findsOneWidget);
      expect(find.text('إرشادات آمنة وحلول سريعة داخل أعرست'), findsOneWidget);
      expect(find.textContaining('قناة الدعم ستظهر هنا'), findsNothing);
      expect(find.textContaining('تجهيز هادئ قبل الإطلاق'), findsNothing);
      expect(find.text('فتح الإعدادات'), findsOneWidget);
      expect(find.text('فتح التنبيهات'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('الخطط المشتركة'),
        280,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('الخطط المشتركة'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('حدود الدعم في هذه النسخة'),
        280,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('حدود الدعم في هذه النسخة'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('فتح الإعدادات'),
        -280,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('فتح الإعدادات'));
      await tester.pumpAndSettle();

      expect(router.state.uri.path, AppRouter.settings);
      expect(find.text('settings-opened'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

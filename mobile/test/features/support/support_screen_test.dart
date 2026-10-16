import 'package:aarast_mobile/core/diagnostics/diagnostic_report_sender.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/support/screens/support_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('support screen is actionable and not a coming soon placeholder', (
    tester,
  ) async {
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
    // V1 checklist 6.3: the published policy and terms are one tap away.
    expect(find.byKey(const Key('support-privacy-link')), findsOneWidget);
    expect(find.byKey(const Key('support-terms-link')), findsOneWidget);
    expect(find.text('حلول سريعة'), findsOneWidget);
    expect(find.text('لماذا لا تصلني التنبيهات؟'), findsOneWidget);
    await tester.tap(find.text('لماذا لا تصلني التنبيهات؟'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('إشعارات الجهاز تحتاج نسخة Android مهيأة'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'إشعارات الجهاز والرسائل النصية وواتساب والبريد الإلكتروني فليست متاحة',
      ),
      findsNothing,
    );
    expect(find.text('كيف أحمي بياناتي المالية؟'), findsOneWidget);
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('فتح الإعدادات'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, AppRouter.settings);
    expect(find.text('settings-opened'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('support describes configured Android push truthfully', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const SupportScreen(devicePushAvailableOverride: true),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('لماذا لا تصلني التنبيهات؟'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('نسخة Android هذه مهيأة لإشعارات الجهاز'),
      findsOneWidget,
    );
  });

  testWidgets('diagnostic report requires fresh explicit consent per send', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _FakeDiagnosticReportService();

    await tester.pumpWidget(
      Provider<DiagnosticReportService>.value(
        value: service,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SupportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('diagnostic-report-send')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('diagnostic-report-send')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('diagnostic-report-consent-dialog')),
      findsOneWidget,
    );
    expect(service.sendCalls, 0);

    await tester.tap(find.byKey(const Key('diagnostic-report-cancel')));
    await tester.pumpAndSettle();
    expect(service.sendCalls, 0);

    await tester.tap(find.byKey(const Key('diagnostic-report-send')));
    await tester.pumpAndSettle();
    expect(service.sendCalls, 0);

    await tester.tap(find.byKey(const Key('diagnostic-report-confirm')));
    await tester.pumpAndSettle();

    expect(service.sendCalls, 1);
    expect(find.text('تم إرسال التقرير التشخيصي بأمان.'), findsOneWidget);
  });
}

final class _FakeDiagnosticReportService implements DiagnosticReportService {
  int sendCalls = 0;

  @override
  bool get isAvailable => true;

  @override
  Future<DiagnosticReportSendResult> send() async {
    sendCalls += 1;
    return DiagnosticReportSendResult.sent;
  }
}

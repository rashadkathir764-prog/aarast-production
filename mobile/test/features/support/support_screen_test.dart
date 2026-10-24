import 'package:aarast_mobile/core/diagnostics/diagnostic_report_sender.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/support/screens/support_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  // g10 (D26): WhatsApp, the five questions, privacy and terms.
  testWidgets('g10 answers the common questions in place', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const SupportScreen(whatsAppOverride: '+967777000111'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('المساعدة'), findsOneWidget);
    expect(find.text('كلّمنا على واتساب'), findsOneWidget);
    expect(find.textContaining('777 000 111'), findsOneWidget);
    expect(find.text('أسئلة كثير يسألونها'), findsOneWidget);
    // V1 checklist 6.3: the published policy and terms are one tap away.
    expect(find.byKey(const Key('support-privacy-link')), findsOneWidget);
    expect(find.byKey(const Key('support-terms-link')), findsOneWidget);
    expect(find.textContaining('قناة الدعم ستظهر هنا'), findsNothing);

    expect(find.textContaining('يسجّل اللي دفعته'), findsNothing);
    await tester.tap(find.text('هل اعّرست يحوّل فلوس؟'));
    await tester.pumpAndSettle();
    expect(find.textContaining('يسجّل اللي دفعته'), findsOneWidget);
    expect(find.textContaining('أقساط'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('g10 leaves WhatsApp out when no number is set', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const SupportScreen(whatsAppOverride: ''),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('support-whatsapp')), findsNothing);
    expect(find.text('أسئلة كثير يسألونها'), findsOneWidget);
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
    expect(find.text('وصل التقرير، شكرًا لك.'), findsOneWidget);
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

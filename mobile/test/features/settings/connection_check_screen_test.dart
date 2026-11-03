import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/network/server_reachability.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/settings/screens/connection_check_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// D84 «فحص الاتصال»: the measured truth about reaching the server, and a
// report to copy.

class _Api extends ApiClient {
  _Api(this.failure) : super(tokenProvider: () async => null);

  final ReachabilityFailure? failure;
  int probes = 0;

  @override
  Future<ReachabilityFailure?> probeLive() async {
    probes++;
    return failure;
  }
}

Future<void> _pump(
  WidgetTester tester,
  _Api api,
  ServerReachability reachability,
) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 1200);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: api),
        ChangeNotifierProvider<ServerReachability>.value(value: reachability),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) =>
            Directionality(textDirection: TextDirection.rtl, child: child!),
        home: const ConnectionCheckScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the build, the server and the last measured failure', (
    tester,
  ) async {
    final reachability = ServerReachability(
      clock: () => DateTime(2026, 11, 3, 23, 29),
    );
    reachability.noteFailure(
      ReachabilityFailure(
        cause: ReachabilityCause.timeout,
        at: DateTime(2026, 11, 3, 23, 29),
        path: '/api/v1/wedding-plans/x/money-summary',
      ),
    );
    await _pump(tester, _Api(null), reachability);

    expect(find.text('فحص الاتصال'), findsOneWidget);
    expect(find.textContaining('نسخة تطوير'), findsOneWidget);
    expect(find.textContaining('الخادم: 127.0.0.1'), findsOneWidget);
    expect(find.textContaining('الخادم تأخر في الرد'), findsOneWidget);
    expect(find.text('افحص الحين'), findsOneWidget);
  });

  testWidgets('a probe that reaches the server says so', (tester) async {
    final api = _Api(null);
    await _pump(tester, api, ServerReachability());

    await tester.tap(find.byKey(const ValueKey('connection-probe')));
    await tester.pumpAndSettle();

    expect(api.probes, 1);
    expect(find.textContaining('الخادم رد الحين'), findsOneWidget);
  });

  testWidgets('a probe that fails names the measured cause', (tester) async {
    final api = _Api(
      ReachabilityFailure(
        cause: ReachabilityCause.noNetwork,
        at: DateTime(2026, 11, 3),
      ),
    );
    await _pump(tester, api, ServerReachability());

    await tester.tap(find.byKey(const ValueKey('connection-probe')));
    await tester.pumpAndSettle();

    expect(find.textContaining('ما فيه نت في الجوال الحين'), findsOneWidget);
    expect(find.textContaining('شغّل النت'), findsOneWidget);
  });

  testWidgets('the report is copied as text with the cause code', (
    tester,
  ) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    final reachability = ServerReachability();
    reachability.noteFailure(
      ReachabilityFailure(
        cause: ReachabilityCause.refused,
        at: DateTime(2026, 11, 3, 23, 29),
        path: '/api/v1/live',
        detail: 'Connection refused',
      ),
    );
    await _pump(tester, _Api(null), reachability);

    await tester.tap(find.byKey(const ValueKey('connection-copy')));
    await tester.pumpAndSettle();

    expect(copied, isNotNull);
    expect(copied, contains('نسخة تطوير'));
    expect(copied, contains('(refused)'));
    expect(copied, contains('/api/v1/live'));
  });
}

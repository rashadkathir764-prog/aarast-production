import 'dart:async';

import 'package:aarast_mobile/core/experience_v3/aarast_journey.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/provider_portal/widgets/provider_account_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('provider account actions are RTL safe at 320px', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 760);
    addTearDown(tester.view.reset);

    var settingsCalls = 0;
    await tester.pumpWidget(
      _TestApp(
        child: ProviderAccountActions(
          onOpenSettings: () => settingsCalls += 1,
          onSync: () async {},
          onExitWorkspace: () async {},
          onLogout: () async {},
          onDeleteAccount: () async => null,
        ),
      ),
    );

    expect(find.text('الحساب والتطبيق'), findsOneWidget);
    expect(find.text('الإعدادات'), findsOneWidget);
    expect(find.text('مزامنة الآن'), findsOneWidget);
    expect(find.text('تسجيل الخروج'), findsOneWidget);

    await tester.tap(find.byKey(const Key('provider-settings-action')));
    await tester.pump();

    expect(settingsCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sync runs once and reports success', (tester) async {
    final syncCompleter = Completer<void>();
    var syncCalls = 0;
    await tester.pumpWidget(
      _TestApp(
        child: ProviderAccountActions(
          onOpenSettings: () {},
          onSync: () {
            syncCalls += 1;
            return syncCompleter.future;
          },
          onExitWorkspace: () async {},
          onLogout: () async {},
          onDeleteAccount: () async => null,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('provider-sync-action')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('provider-sync-action')));
    await tester.pump();

    expect(syncCalls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    syncCompleter.complete();
    await tester.pumpAndSettle();

    expect(find.text('تم تحديث بيانات لوحة المزوّد.'), findsOneWidget);
  });

  testWidgets('sync failure stays on screen with a clear message', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestApp(
        child: ProviderAccountActions(
          onOpenSettings: () {},
          onSync: () async => throw StateError('offline'),
          onExitWorkspace: () async {},
          onLogout: () async {},
          onDeleteAccount: () async => null,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('provider-sync-action')));
    await tester.pumpAndSettle();

    expect(
      find.text('تعذّر تحديث بيانات المزوّد. تحقق من الاتصال وحاول مجدداً.'),
      findsOneWidget,
    );
  });

  testWidgets('workspace exit keeps logout as a separate confirmed action', (
    tester,
  ) async {
    var exitCalls = 0;
    var logoutCalls = 0;
    await tester.pumpWidget(
      _TestApp(
        child: ProviderAccountActions(
          onOpenSettings: () {},
          onSync: () async {},
          onExitWorkspace: () async => exitCalls += 1,
          onLogout: () async => logoutCalls += 1,
          onDeleteAccount: () async => null,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('provider-exit-workspace-action')));
    await tester.pumpAndSettle();
    expect(find.text('الخروج من مساحة المزوّد؟'), findsOneWidget);
    expect(
      find.text(
        'ستعود إلى شاشة اختيار المسار، وسيبقى حسابك مسجلًا على هذا الجهاز.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('provider-exit-workspace-confirm')));
    await tester.pumpAndSettle();

    expect(exitCalls, 1);
    expect(logoutCalls, 0);
  });

  testWidgets('logout requires explicit confirmation', (tester) async {
    var logoutCalls = 0;
    await tester.pumpWidget(
      _TestApp(
        child: ProviderAccountActions(
          onOpenSettings: () {},
          onSync: () async {},
          onExitWorkspace: () async {},
          onLogout: () async => logoutCalls += 1,
          onDeleteAccount: () async => null,
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('provider-logout-action')));
    await tester.pumpAndSettle();
    expect(find.text('الخروج من حساب المزوّد؟'), findsOneWidget);

    await tester.tap(find.byKey(const Key('provider-logout-cancel')));
    await tester.pumpAndSettle();
    expect(logoutCalls, 0);

    await tester.tap(find.byKey(const Key('provider-logout-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('provider-logout-confirm')));
    await tester.pumpAndSettle();

    expect(logoutCalls, 1);
  });

  testWidgets('account deletion requires typing the explicit confirmation', (
    tester,
  ) async {
    var deleteCalls = 0;
    await tester.pumpWidget(
      _TestApp(
        child: ProviderAccountActions(
          onOpenSettings: () {},
          onSync: () async {},
          onExitWorkspace: () async {},
          onLogout: () async {},
          onDeleteAccount: () async {
            deleteCalls += 1;
            return null;
          },
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('provider-delete-account-action')));
    await tester.pumpAndSettle();

    expect(find.text('حذف حسابك نهائيًا؟'), findsOneWidget);
    final confirm = find.byKey(const Key('provider-delete-account-confirm'));
    expect(tester.widget<JourneyButton>(confirm).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('provider-delete-account-input')),
      'حذف',
    );
    await tester.pump();
    expect(tester.widget<JourneyButton>(confirm).onPressed, isNotNull);

    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(deleteCalls, 1);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    );
  }
}

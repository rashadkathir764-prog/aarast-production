import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/auth/screens/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/preview_fonts.dart';

void main() {
  // Measured with the app's own fonts: the test font draws every Arabic
  // letter as a full square and wraps labels a phone never wraps.
  setUpAll(loadPreviewAppFonts);

  // D7: the journey field holds its label inside the box (60 to 76 px);
  // actions stay one comfortable touch target (48 to 56 px). D75: the
  // number and a WhatsApp code come first; a password is the second way.
  testWidgets('the sign-in screen keeps its fields and actions to size', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await _pumpLogin(tester);

    expect(find.text('بنفس رقم جوالك، ونرسل رمز على واتساب.'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.byKey(const ValueKey('login-password')), findsNothing);
    expect(
      find.byKey(const ValueKey('login-forgot-password-action')),
      findsNothing,
    );
    _expectFieldsToSize(tester);

    final codeActions = {
      'send the code': find.byKey(const ValueKey('login-submit')),
      'no account': find.byKey(const ValueKey('login-register-action')),
    };
    for (final MapEntry(key: label, value: action) in codeActions.entries) {
      expect(action, findsOneWidget);
      expect(
        tester.getSize(action).height,
        inInclusiveRange(48, 56),
        reason: '$label should stay one touch target',
      );
    }
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('login-submit')),
        matching: find.text('أرسل الرمز'),
      ),
      findsOneWidget,
    );
    expect(find.text('ما عندك حساب؟ ابدأ من هنا'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('login-mode')));
    await tester.pumpAndSettle();

    expect(find.text('برقم جوالك وكلمة المرور.'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    _expectFieldsToSize(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('login-submit')),
        matching: find.text('تسجيل الدخول'),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('login-submit'))).height,
      inInclusiveRange(48, 56),
    );
    expect(
      find.byKey(const ValueKey('login-forgot-password-action')),
      findsOneWidget,
    );
    expect(find.text('الدخول برمز واتساب'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final textScale in [1.3, 2.0]) {
    testWidgets('the sign-in screen stays RTL-safe at 320px and ${textScale}x '
        'text', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 760);
      addTearDown(tester.view.reset);

      await _pumpLogin(tester, textScale: textScale);

      // The same screen greets a provider, who has no wedding plan.
      expect(find.text('تسجيل الدخول'), findsOneWidget);
      expect(find.textContaining('خطتك'), findsNothing);
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);

      for (final key in [
        'login-submit',
        'login-register-action',
        'login-mode',
      ]) {
        final action = find.byKey(ValueKey(key));
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        expect(action, findsOneWidget);
        expect(tester.takeException(), isNull);
      }

      await tester.tap(find.byKey(const ValueKey('login-mode')));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsNWidgets(2));
      final forgot = find.byKey(const ValueKey('login-forgot-password-action'));
      await tester.ensureVisible(forgot);
      await tester.pumpAndSettle();
      expect(forgot, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  // x18 (C58): after an expired session, the same account signs in again
  // and is told its offline changes are kept.
  testWidgets('x18 says sign in again with the kept changes at 320px', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 760);
    addTearDown(tester.view.reset);

    await _pumpLogin(
      tester,
      textScale: 2,
      sessionExpired: true,
      pendingChanges: 3,
    );

    expect(find.text('ادخل مرة ثانية'), findsOneWidget);
    expect(find.textContaining('3 أشياء سجّلتها بدون نت'), findsOneWidget);
    expect(find.text('أهلًا من جديد'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

void _expectFieldsToSize(WidgetTester tester) {
  for (final key in ['login-phone', 'login-password']) {
    final field = find.byKey(ValueKey(key));
    if (field.evaluate().isEmpty) continue;
    final box = find.descendant(of: field, matching: find.byType(TextField));
    expect(box, findsOneWidget);
    expect(
      tester.getSize(field).height,
      inInclusiveRange(60, 76),
      reason: '$key holds its label inside the box',
    );
  }
}

Future<void> _pumpLogin(
  WidgetTester tester, {
  double textScale = 1,
  bool sessionExpired = false,
  int pendingChanges = 0,
}) async {
  SharedPreferences.setMockInitialValues({});
  final storage = AuthStorage(await SharedPreferences.getInstance());
  final auth = AuthController(
    AuthRepository(ApiClient(tokenProvider: storage.readAccessToken), storage),
  );
  addTearDown(auth.dispose);
  final offline = _PendingChanges(pendingChanges);
  addTearDown(offline.dispose);

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider<OfflineSyncService>.value(value: offline),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('ar'),
        builder: (context, child) => Directionality(
          textDirection: TextDirection.rtl,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
        home: LoginScreen(
          initialPhone: '777123456',
          sessionExpired: sessionExpired,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Only the count of changes kept on the phone, as x18 reads it.
class _PendingChanges extends ChangeNotifier implements OfflineSyncService {
  _PendingChanges(this.pendingCount);

  @override
  final int pendingCount;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

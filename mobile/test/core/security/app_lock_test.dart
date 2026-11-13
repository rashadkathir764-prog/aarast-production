import 'package:aarast_mobile/core/security/app_lock_controller.dart';
import 'package:aarast_mobile/core/security/app_lock_gate.dart';
import 'package:aarast_mobile/core/storage/sensitive_value_vault.dart';
import 'package:aarast_mobile/features/settings/screens/lock_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// V1 checklist 4.15: an optional 4-digit app lock per account.

class _MemoryVault implements SensitiveValueVault {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemoryVault vault;
  late DateTime now;

  AppLockController controller({String? userId = 'user-1'}) =>
      AppLockController(vault: vault, userId: userId, clock: () => now);

  setUp(() {
    vault = _MemoryVault();
    now = DateTime(2026, 10, 15, 12);
  });

  test('a guest never has a lock, and no code is set by default', () async {
    final guest = controller(userId: null);
    await guest.load();
    expect(guest.isPending, isFalse);
    expect(guest.isLocked, isFalse);

    final account = controller();
    expect(account.isPending, isTrue);
    await account.load();
    expect(account.isEnabled, isFalse);
    expect(account.isLocked, isFalse);
  });

  test('a set code locks the next start, and only a hash is stored', () async {
    final first = controller();
    await first.load();
    await first.setCode('2580');
    expect(vault.values.values, isNot(contains('2580')));

    final next = controller();
    await next.load();
    expect(next.isLocked, isTrue);
    expect(await next.unlock('1111'), isFalse);
    expect(await next.unlock('2580'), isTrue);
    expect(next.isLocked, isFalse);
  });

  test('the code belongs to one account', () async {
    final owner = controller();
    await owner.load();
    await owner.setCode('2580');

    final other = controller(userId: 'user-2');
    await other.load();
    expect(other.isLocked, isFalse);
  });

  test('five wrong codes make the next try wait, and the wait grows', () async {
    final lock = controller();
    await lock.load();
    await lock.setCode('2580');
    final reopened = controller();
    await reopened.load();

    for (var attempt = 0; attempt < 5; attempt += 1) {
      expect(await reopened.unlock('0000'), isFalse);
    }
    expect(reopened.waitRemaining, const Duration(seconds: 30));
    // While waiting, even the right code is not checked.
    expect(await reopened.unlock('2580'), isFalse);

    now = now.add(const Duration(seconds: 31));
    expect(await reopened.unlock('0000'), isFalse);
    expect(reopened.waitRemaining, const Duration(seconds: 60));

    now = now.add(const Duration(seconds: 61));
    expect(await reopened.unlock('2580'), isTrue);
    expect(reopened.failedAttempts, 0);
  });

  test(
    'returning after a minute away locks again; a short switch does not',
    () async {
      final lock = controller();
      await lock.load();
      await lock.setCode('2580');

      lock.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(seconds: 20));
      lock.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(lock.isLocked, isFalse);

      lock.didChangeAppLifecycleState(AppLifecycleState.paused);
      now = now.add(const Duration(minutes: 2));
      lock.didChangeAppLifecycleState(AppLifecycleState.resumed);
      expect(lock.isLocked, isTrue);
    },
  );

  test('a forgotten code is cleared for the sign-out', () async {
    final lock = controller();
    await lock.load();
    await lock.setCode('2580');
    await lock.forgetForSignOut();
    expect(vault.values, isEmpty);
    expect(lock.isEnabled, isFalse);
    expect(() => lock.setCode('12'), throwsArgumentError);
  });

  testWidgets('the lock screen covers the app until the right code', (
    tester,
  ) async {
    final setup = controller();
    await setup.load();
    await setup.setCode('2580');
    final lock = controller();
    await lock.load();
    var signedOut = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: lock,
          child: AppLockGate(
            onForgotCode: () async => signedOut = true,
            child: const Scaffold(body: Text('خطتي')),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('app-lock-screen')), findsOneWidget);
    for (final digit in ['1', '1', '1', '1']) {
      await tester.tap(find.byKey(Key('app-lock-key-$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    // w08: a wrong code turns the title into «الرمز غلط».
    expect(find.text('الرمز غلط'), findsOneWidget);

    for (final digit in ['2', '5', '8', '0']) {
      await tester.tap(find.byKey(Key('app-lock-key-$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('app-lock-screen')), findsNothing);
    expect(find.text('خطتي'), findsOneWidget);
    expect(signedOut, isFalse);
  });

  testWidgets('forgetting the code clears it and signs out', (tester) async {
    final setup = controller();
    await setup.load();
    await setup.setCode('2580');
    final lock = controller();
    await lock.load();
    var signedOut = false;

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: lock,
          child: AppLockGate(
            onForgotCode: () async => signedOut = true,
            child: const Scaffold(body: Text('خطتي')),
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const Key('app-lock-forgot')));
    await tester.tap(find.byKey(const Key('app-lock-forgot')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اطلع وشيل الرمز'));
    await tester.pumpAndSettle();

    expect(signedOut, isTrue);
    expect(vault.values, isEmpty);
  });

  testWidgets('w08: five wrong codes rest the pad and the note opens forgot', (
    tester,
  ) async {
    final setup = controller();
    await setup.load();
    await setup.setCode('2580');
    final lock = controller();
    await lock.load();

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: lock,
          child: AppLockGate(
            onForgotCode: () async {},
            child: const Scaffold(body: Text('خطتي')),
          ),
        ),
      ),
    );
    for (var attempt = 0; attempt < 5; attempt++) {
      for (var press = 0; press < 4; press++) {
        await tester.tap(find.byKey(const Key('app-lock-key-1')));
        await tester.pump();
      }
      await tester.pump();
    }

    expect(find.text('الرمز غلط 5 مرات'), findsOneWidget);
    expect(find.textContaining('جرّب مرة ثانية بعد'), findsOneWidget);
    // The note replaces the separate «نسيت الرمز؟» link while the pad waits.
    expect(find.text('نسيت الرمز؟'), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('app-lock-forgot')));
    await tester.tap(find.byKey(const Key('app-lock-forgot')));
    await tester.pump();
    expect(find.text('اطلع وشيل الرمز'), findsOneWidget);
  });

  testWidgets('g08 chooses a code twice, then can take the lock off', (
    tester,
  ) async {
    final lock = controller();
    await lock.load();

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ChangeNotifierProvider.value(
            value: lock,
            child: const LockSettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('اختر رمز من 4 أرقام'), findsOneWidget);
    for (final digit in ['1', '9', '7', '3']) {
      await tester.tap(find.byKey(Key('app-lock-key-$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('اكتبه مرة ثانية'), findsOneWidget);
    for (final digit in ['1', '9', '7', '3']) {
      await tester.tap(find.byKey(Key('app-lock-key-$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(lock.isEnabled, isTrue);
    expect(find.text('التطبيق مقفول برمزك'), findsOneWidget);

    // RA-MO-156 (2026-11-13): taking the lock off asks the code first; a
    // single tap took it off for whoever held the unlocked phone.
    await tester.tap(find.byKey(const Key('lock-turn-off')));
    await tester.pumpAndSettle();
    expect(find.text('اكتب رمزك الحالي'), findsOneWidget);
    for (final digit in ['0', '0', '0', '0']) {
      await tester.tap(find.byKey(Key('app-lock-key-$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('الرمز غلط.'), findsOneWidget);
    expect(lock.isEnabled, isTrue);

    for (final digit in ['1', '9', '7', '3']) {
      await tester.tap(find.byKey(Key('app-lock-key-$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(lock.isEnabled, isFalse);
  });

  testWidgets('changing the code asks the current one first', (tester) async {
    final lock = controller();
    await lock.load();
    await lock.setCode('2580');

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: lock,
          child: const LockSettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('lock-change-code')));
    await tester.pumpAndSettle();
    expect(find.text('اكتب رمزك الحالي'), findsOneWidget);
    expect(find.text('اختر رمز من 4 أرقام'), findsNothing);

    for (final digit in ['2', '5', '8', '0']) {
      await tester.tap(find.byKey(Key('app-lock-key-$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('اختر رمز من 4 أرقام'), findsOneWidget);
  });

  test('wrong codes asked before a change count and wait too', () async {
    final lock = controller();
    await lock.load();
    await lock.setCode('2580');
    for (var attempt = 0; attempt < 5; attempt += 1) {
      expect(await lock.confirmCode('0000'), isFalse);
    }
    expect(lock.waitRemaining, const Duration(seconds: 30));
    expect(await lock.confirmCode('2580'), isFalse);
    // Confirming never locks or unlocks the app.
    expect(lock.isLocked, isFalse);
  });

  testWidgets('g08 starts over when the second code differs', (tester) async {
    final lock = controller();
    await lock.load();

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider.value(
          value: lock,
          child: const LockSettingsScreen(),
        ),
      ),
    );
    await tester.pump();
    for (final digit in ['1', '2', '3', '4', '4', '3', '2', '1']) {
      await tester.tap(find.byKey(Key('app-lock-key-$digit')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.text('الرمزين مختلفين، ابدأ من جديد'), findsOneWidget);
    expect(lock.isEnabled, isFalse);
  });
}

import 'dart:io';

import 'package:aarast_mobile/core/experience_v3/aarast_journey.dart';
import 'package:aarast_mobile/core/security/app_lock_controller.dart';
import 'package:aarast_mobile/features/shell/widgets/plan_shell_chrome.dart';
import 'package:aarast_mobile/core/security/screen_protection.dart';
import 'package:aarast_mobile/core/storage/sensitive_value_vault.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

// D112 (Q-8), the owner's word: with the app lock on, the money screens
// take no screenshot and leave no picture in the recent-apps list; the
// other screens are untouched. There was no protection at all: a phone that
// asked for its code still showed the money in the recents.

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

  late List<bool> asked;

  setUp(() {
    asked = <bool>[];
    ScreenProtection.instance.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ScreenProtection.channel, (call) async {
          expect(call.method, 'setSecure');
          asked.add(call.arguments as bool);
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ScreenProtection.channel, null);
  });

  Future<AppLockController> lock({required bool on}) async {
    final controller = AppLockController(vault: _MemoryVault(), userId: 'u1');
    await controller.load();
    if (on) await controller.setCode('1234');
    return controller;
  }

  Widget app(AppLockController controller, Widget child) =>
      ChangeNotifierProvider<AppLockController>.value(
        value: controller,
        child: MaterialApp(home: child),
      );

  testWidgets('a money screen is protected while the lock is on, and let go '
      'when it closes', (tester) async {
    final controller = await tester.runAsync(() => lock(on: true));
    await tester.pumpWidget(
      app(controller!, const MoneyScreenShield(child: Text('المال'))),
    );
    await tester.pump();
    expect(asked, [true]);

    await tester.pumpWidget(app(controller, const Text('الرئيسية')));
    await tester.pump();
    expect(asked, [true, false]);
  });

  testWidgets('without the lock nothing is asked of the window', (
    tester,
  ) async {
    final controller = await tester.runAsync(() => lock(on: false));
    await tester.pumpWidget(
      app(controller!, const MoneyScreenShield(child: Text('المال'))),
    );
    await tester.pump();
    expect(asked, isEmpty);

    // Turning the lock on while the money is open protects it at once.
    await tester.runAsync(() => controller.setCode('1234'));
    await tester.pump();
    expect(asked, [true]);
  });

  testWidgets('a tab that is not the money is not protected', (tester) async {
    final controller = await tester.runAsync(() => lock(on: true));
    await tester.pumpWidget(
      app(
        controller!,
        const MoneyScreenShield(active: false, child: Text('المهام')),
      ),
    );
    await tester.pump();
    expect(asked, isEmpty);

    await tester.pumpWidget(
      app(controller, const MoneyScreenShield(child: Text('المال'))),
    );
    await tester.pump();
    expect(asked, [true]);
  });

  testWidgets('two money pages on top of each other ask once, and let go '
      'when both are gone', (tester) async {
    final controller = await tester.runAsync(() => lock(on: true));
    await tester.pumpWidget(
      app(
        controller!,
        const Column(
          children: [
            MoneyScreenShield(child: Text('المال')),
            MoneyScreenShield(child: Text('اتفاق')),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(asked, [true]);

    await tester.pumpWidget(
      app(controller, const MoneyScreenShield(child: Text('المال'))),
    );
    await tester.pump();
    expect(asked, [true]);

    await tester.pumpWidget(app(controller, const Text('الرئيسية')));
    await tester.pump();
    expect(asked, [true, false]);
  });

  // RA-MO-309: the shield asks after the frame. One that asked and was
  // disposed in that same frame held the window secure for good, every
  // screen of the app with it, until the app was restarted.
  testWidgets('a money screen gone in the frame it asked in holds nothing', (
    tester,
  ) async {
    final controller = await tester.runAsync(() => lock(on: false));
    final showMoney = ValueNotifier<bool>(true);
    addTearDown(showMoney.dispose);
    await tester.pumpWidget(
      app(
        controller!,
        ValueListenableBuilder<bool>(
          valueListenable: showMoney,
          builder: (context, show, _) => show
              ? const MoneyScreenShield(child: Text('المال'))
              : const Text('الرئيسية'),
        ),
      ),
    );
    await tester.pump();
    expect(asked, isEmpty);

    // One frame's order, step by step: the lock turns on and the shield
    // rebuilds wanting to hold; the money closes and the shield is
    // disposed; only then do the frame's end callbacks run.
    final owner = tester.binding.buildOwner!;
    final root = tester.binding.rootElement!;
    await tester.runAsync(() => controller.setCode('1234'));
    owner.buildScope(root);
    showMoney.value = false;
    owner.buildScope(root);
    owner.finalizeTree();
    await tester.pump();
    await tester.pump();
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(asked, isEmpty);

    // A later money screen holds and lets go as it should.
    showMoney.value = true;
    await tester.pump();
    await tester.pump();
    expect(asked, [true]);
    showMoney.value = false;
    await tester.pump();
    await tester.pump();
    expect(asked, [true, false]);
  });

  // The two places every money screen passes: the plan's money tab, and
  // the gate of the money routes.
  testWidgets('the plan\'s money tab is protected, its other tabs are not', (
    tester,
  ) async {
    final controller = await tester.runAsync(() => lock(on: true));
    Widget shell(int tab) => app(
      controller!,
      PlanShellChrome(
        activeIndex: tab,
        onTabSelected: (_) {},
        body: const Text('الصفحة'),
      ),
    );

    await tester.pumpWidget(shell(JourneySection.tasks.index));
    await tester.pump();
    expect(asked, isEmpty);

    await tester.pumpWidget(shell(JourneySection.money.index));
    await tester.pump();
    expect(asked, [true]);

    await tester.pumpWidget(shell(JourneySection.guests.index));
    await tester.pump();
    expect(asked, [true, false]);
  });

  test('every money route is protected at its gate', () {
    final gate = File(
      'lib/features/account_contexts/widgets/wedding_plan_context_gate.dart',
    ).readAsStringSync();
    final shield = gate.substring(gate.indexOf('MoneyScreenShield('));
    final rule = shield.substring(0, shield.indexOf('child: child'));
    for (final access in ['viewMoney', 'manageMoney', 'settleMoney']) {
      expect(rule, contains('WeddingPlanRouteAccess.$access'));
    }
    expect(rule, contains('_ => false'));
  });

  testWidgets('a screen with no lock in reach is shown as it is', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: MoneyScreenShield(child: Text('المال'))),
    );
    await tester.pump();
    expect(find.text('المال'), findsOneWidget);
    expect(asked, isEmpty);
    expect(tester.takeException(), isNull);
  });
}

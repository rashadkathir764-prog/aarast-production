import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/storage/sensitive_value_vault.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/account_contexts/widgets/wedding_plan_context_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_context_test_data.dart';

// RA-MO-339: the gate names whose plan a participant was taken off
// («العروسة شالتك من خطتها»). The controller kept that in memory only, so an
// app closed between the server's answer and the gate forgot it, and the
// gate said only «ما عادت ضمن خططك». It is kept on the phone, for the
// signed-in user only, until the gate has said it, or the account is gone.

const _removedText = 'العروسة شالتك من خطتها. ارجع للرئيسية واختر خطة ثانية.';
const _genericText = 'ما عادت ضمن خططك. ارجع للرئيسية واختر خطة ثانية.';

SafeUser _user(String id) =>
    SafeUser.fromJson({'id': id, 'name': 'علي', 'phone': '+967700000000'});

final _own = accountContext(role: AccountContextRole.owner);
final _helping = accountContext(
  role: AccountContextRole.contributor,
  planId: 'plan-2',
  persona: AccountContextPersona.bride,
);

class _Gateway implements AccountContextsGateway {
  _Gateway(this.contexts);
  List<AccountContext> contexts;

  @override
  Future<List<AccountContext>> listContexts() async => contexts;

  @override
  Future<AccountContext> validateContext(String contextKey) async =>
      contexts.firstWhere((context) => context.contextKey == contextKey);
}

/// One run of the app on the same phone: a fresh storage and controller
/// over what the phone kept.
Future<AccountContextController> _launch(
  SharedPreferences preferences,
  _Gateway gateway, {
  SensitiveValueVault? vault,
}) async {
  final storage = AuthStorage(preferences, sensitiveValueVault: vault);
  await storage.initialize();
  return AccountContextController(
    contextsApi: gateway,
    authStorage: storage,
    setActiveWeddingPlan: (_) async {},
  );
}

/// The first run: the participant is on the bride's plan, and the server
/// answers that he no longer is.
Future<AccountContextController> _takenOff(
  SharedPreferences preferences,
  _Gateway gateway, {
  SensitiveValueVault? vault,
  String userId = 'user-1',
}) async {
  final storage = AuthStorage(preferences, sensitiveValueVault: vault);
  await storage.initialize();
  await storage.saveUser(_user(userId));
  final controller = AccountContextController(
    contextsApi: gateway,
    authStorage: storage,
    setActiveWeddingPlan: (_) async {},
  );
  gateway.contexts = [_own, _helping];
  await controller.refresh();
  await controller.select(_helping.contextKey);
  gateway.contexts = [_own];
  await controller.refresh();
  expect(controller.removedPlanPath('plan-2')?.persona,
      AccountContextPersona.bride);
  return controller;
}

Widget _gate(AccountContextController controller) =>
    ChangeNotifierProvider<AccountContextController>.value(
      value: controller,
      child: const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: WeddingPlanContextGate(
            weddingPlanId: 'plan-2',
            child: Text('private-plan-2'),
          ),
        ),
      ),
    );

class _Vault implements SensitiveValueVault {
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

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the owner is named after the app is closed and opened again, '
      'once', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    final gateway = _Gateway([]);
    await _takenOff(preferences, gateway);

    // Opened again: the server still says he is off the plan.
    final second = await _launch(preferences, gateway);
    await second.refresh();
    await tester.pumpWidget(_gate(second));
    await tester.pumpAndSettle();
    expect(find.text(_removedText), findsOneWidget);
    expect(find.text('private-plan-2'), findsNothing);

    // Within the run it keeps saying it.
    await second.refresh();
    await tester.pumpAndSettle();
    expect(find.text(_removedText), findsOneWidget);

    // Said once: the next run does not keep it.
    await tester.pumpWidget(const SizedBox());
    final third = await _launch(preferences, gateway);
    await third.refresh();
    expect(third.removedPlanPath('plan-2'), isNull);
    await tester.pumpWidget(_gate(third));
    await tester.pumpAndSettle();
    expect(find.text(_removedText), findsNothing);
    expect(find.text(_genericText), findsOneWidget);
  });

  testWidgets('asked into the plan again, it is forgotten on the phone too', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final gateway = _Gateway([]);
    final first = await _takenOff(preferences, gateway);
    gateway.contexts = [_own, _helping];
    await first.refresh();
    expect(first.removedPlanPath('plan-2'), isNull);

    gateway.contexts = [_own];
    final second = await _launch(preferences, gateway);
    expect(second.removedPlanPath('plan-2'), isNull);
  });

  testWidgets('signing out forgets it', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    final gateway = _Gateway([]);
    final first = await _takenOff(preferences, gateway);
    await first.clearForLogout();
    expect(first.removedPlanPath('plan-2'), isNull);

    final second = await _launch(preferences, gateway);
    expect(second.removedPlanPath('plan-2'), isNull);
    expect(
      preferences.getKeys().where((key) => key.contains('removed')),
      isEmpty,
    );
  });

  testWidgets('another account on the same phone is not told', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final gateway = _Gateway([]);
    await _takenOff(preferences, gateway);

    final storage = AuthStorage(preferences);
    await storage.saveUser(_user('user-2'));
    final other = AccountContextController(
      contextsApi: gateway,
      authStorage: storage,
      setActiveWeddingPlan: (_) async {},
    );
    expect(other.removedPlanPath('plan-2'), isNull);
  });

  testWidgets('kept in the secure vault, not in the plain preferences', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final vault = _Vault();
    final gateway = _Gateway([]);
    await _takenOff(preferences, gateway, vault: vault);

    expect(
      preferences.getKeys().where((key) => key.contains('removed')),
      isEmpty,
    );
    expect(vault.values.keys.where((key) => key.contains('removed')),
        isNotEmpty);
    final second = await _launch(preferences, gateway, vault: vault);
    expect(second.removedPlanPath('plan-2')?.persona,
        AccountContextPersona.bride);
  });
}

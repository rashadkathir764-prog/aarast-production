import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/account_contexts/screens/account_context_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'account_context_test_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'shows a full path-selection screen and activates provider safely at 320px',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      final owner = accountContext(
        role: AccountContextRole.owner,
        displayName: 'خطة زفاف طويلة جدًا لاختبار العرض الآمن على الهاتف',
      );
      final provider = accountContext(
        role: AccountContextRole.provider,
        displayName: 'مزود خدمات احتفالات صنعاء والحديدة باسم طويل جدًا',
      );
      final controller = await _controller([owner, provider]);

      await tester.pumpWidget(
        ChangeNotifierProvider<AccountContextController>.value(
          value: controller,
          child: const MaterialApp(
            home: Directionality(
              textDirection: TextDirection.rtl,
              child: AccountContextSelectionScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('account-context-selection-screen')),
        findsOneWidget,
      );
      expect(find.text('اختر المسار'), findsOneWidget);
      expect(find.textContaining('عريس'), findsOneWidget);
      expect(find.textContaining('خطة زفاف طويلة'), findsOneWidget);
      expect(find.text('مزود'), findsOneWidget);
      expect(find.textContaining('مزود خدمات احتفالات'), findsOneWidget);
      expect(tester.takeException(), isNull);

      expect(
        find.byKey(const ValueKey('account-path-option-provider:provider-1')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('account-path-option-provider:provider-1')),
      );
      await tester.pumpAndSettle();

      expect(controller.selectedContext, provider);
      expect(tester.takeException(), isNull);
    },
  );
}

Future<AccountContextController> _controller(
  List<AccountContext> contexts,
) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final controller = AccountContextController(
    contextsApi: _StaticGateway(contexts),
    authStorage: AuthStorage(preferences),
    setActiveWeddingPlan: (_) async {},
  );
  await controller.refresh();
  expect(controller.selectedContext, isNull);
  return controller;
}

class _StaticGateway implements AccountContextsGateway {
  const _StaticGateway(this.contexts);

  final List<AccountContext> contexts;

  @override
  Future<List<AccountContext>> listContexts() async => contexts;

  @override
  Future<AccountContext> validateContext(String contextKey) async {
    return contexts.firstWhere((context) => context.contextKey == contextKey);
  }
}

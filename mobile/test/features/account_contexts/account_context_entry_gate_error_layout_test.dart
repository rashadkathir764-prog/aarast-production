@Tags(['golden'])
library;

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/widgets/aarast_ui.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart';
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/account_contexts/widgets/account_context_entry_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/preview_fonts.dart';

void main() {
  setUpAll(loadPreviewAppFonts);

  testWidgets('context load error is a compact card at the top', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = AccountContextController(
      contextsApi: const _FailingGateway(),
      authStorage: AuthStorage(preferences),
      setActiveWeddingPlan: (_) async {},
    );
    addTearDown(controller.dispose);
    await controller.refresh();

    await tester.pumpWidget(
      ChangeNotifierProvider<AccountContextController>.value(
        value: controller,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AccountContextEntryGate(),
        ),
      ),
    );
    await tester.pump();

    final card = find.byType(AarastErrorState);
    expect(card, findsOneWidget);
    final rect = tester.getRect(card);
    expect(rect.top, lessThan(80));
    expect(rect.height, lessThan(150));
    expect(find.text('ما قدرنا نفتح حسابك'), findsOneWidget);
    expect(find.text('جرّب مرة ثانية'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('goldens/account_context_error.png'),
    );
  });
}

class _FailingGateway implements AccountContextsGateway {
  const _FailingGateway();

  @override
  Future<List<AccountContext>> listContexts() {
    throw const ApiException('network unavailable', isNetworkFailure: true);
  }

  @override
  Future<AccountContext> validateContext(String contextKey) {
    throw const ApiException('network unavailable', isNetworkFailure: true);
  }
}

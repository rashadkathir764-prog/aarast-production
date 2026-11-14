import 'dart:async';

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

// Right after a sign-in the account's paths are read once; a single failed
// read put a full-screen error in front of a person who had just signed in.
// A failed read is now tried again by itself, a little later each time,
// before the error shows; its retry button stays.

void main() {
  Future<AccountContextController> failedOnce(
    WidgetTester tester,
    _CountingGateway gateway,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final controller = AccountContextController(
      contextsApi: gateway,
      authStorage: AuthStorage(preferences),
      setActiveWeddingPlan: (_) async {},
    );
    addTearDown(controller.dispose);
    await controller.refresh();
    expect(controller.errorMessage, isNotNull);
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
    return controller;
  }

  testWidgets('a failed read is tried again before any error shows', (
    tester,
  ) async {
    // The third read is still on its way when the test ends.
    final gateway = _CountingGateway(failures: 2, holdAfterFailures: true);
    final controller = await failedOnce(tester, gateway);

    expect(find.byType(AarastErrorState), findsNothing);
    expect(find.byType(AarastScreenLoading), findsOneWidget);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(gateway.calls, 2);
    expect(find.byType(AarastErrorState), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(gateway.calls, 3);
    expect(controller.isRefreshing, isTrue);
    expect(find.byType(AarastErrorState), findsNothing);
    expect(find.byType(AarastScreenLoading), findsOneWidget);
  });

  // From the review of the field-notes branch: the wait was armed while the
  // page was drawn and never taken back. A read asked for meanwhile (the
  // app back in front, the person's own press) was asked for a second time
  // when the wait ran out.
  testWidgets('a read asked for meanwhile is not asked for again by the wait', (
    tester,
  ) async {
    final gateway = _CountingGateway(failures: 1, holdAfterFailures: true);
    final controller = await failedOnce(tester, gateway);
    expect(find.text('نحاول مرة ثانية'), findsOneWidget);

    unawaited(controller.refresh());
    await tester.pump();
    expect(gateway.calls, 2);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(gateway.calls, 2, reason: 'the read on its way is the try');
    expect(find.byType(AarastErrorState), findsNothing);
  });

  testWidgets('drawing the page again while it waits arms nothing more', (
    tester,
  ) async {
    final gateway = _CountingGateway(failures: 100);
    await failedOnce(tester, gateway);

    for (var i = 0; i < 5; i++) {
      tester.view.physicalSize = Size(800 + i * 10, 600);
      addTearDown(tester.view.reset);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(gateway.calls, 1);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(gateway.calls, 2);
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(gateway.calls, 3);
    expect(find.byType(AarastErrorState), findsOneWidget);
  });

  testWidgets('after the tries by itself the error shows, with its retry', (
    tester,
  ) async {
    final gateway = _CountingGateway(failures: 100);
    await failedOnce(tester, gateway);

    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(gateway.calls, 3);
    expect(find.byType(AarastErrorState), findsOneWidget);
    expect(find.text('جرّب مرة ثانية'), findsOneWidget);

    // Nothing more is tried by itself; the button still tries.
    await tester.pump(const Duration(seconds: 10));
    expect(gateway.calls, 3);
    await tester.tap(find.text('جرّب مرة ثانية'));
    await tester.pump();
    await tester.pump();
    expect(gateway.calls, 4);
    expect(find.byType(AarastErrorState), findsOneWidget);
  });
}

class _CountingGateway implements AccountContextsGateway {
  _CountingGateway({required this.failures, this.holdAfterFailures = false});

  final int failures;
  final bool holdAfterFailures;
  final _held = Completer<List<AccountContext>>();
  int calls = 0;

  @override
  Future<List<AccountContext>> listContexts() async {
    calls += 1;
    if (calls <= failures) {
      throw const ApiException('network unavailable', isNetworkFailure: true);
    }
    if (holdAfterFailures) return _held.future;
    return const [];
  }

  @override
  Future<AccountContext> validateContext(String contextKey) {
    throw const ApiException('network unavailable', isNetworkFailure: true);
  }
}

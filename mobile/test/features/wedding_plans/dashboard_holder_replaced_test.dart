import 'dart:async';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/home_fixtures.dart';

// The real app, 2026-11-28 (the offline_resume walk): a groom with a plan
// opened the app and the home said «ما عندك خطة بعد · أنشئ خطتك».
//
// The plan's holders are made again when the account's context is settled
// (main.dart `_forPlanScope`, a session restored at the app's start). The
// home had asked the first holder; its answer was dropped with it, and the
// new holder was empty with nothing loading and no error, which is how the
// home reads «no plan».

class _Plans extends WeddingPlansApi {
  _Plans({this.hold}) : super(ApiClient(tokenProvider: () async => null));

  /// The server has not answered yet.
  final Completer<void>? hold;
  int asked = 0;

  @override
  Future<DashboardSummary?> cachedDashboardSummary(String planId) async => null;

  @override
  Future<DashboardSummary> getDashboardSummary(String planId) async {
    asked++;
    await hold?.future;
    return homeSummary(date: homeWedding, today: DateTime(2026, 11, 28));
  }
}

void main() {
  testWidgets('the home reads the plan again from a holder made after it '
      'asked', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(preferences);
    final guestStorage = GuestOnboardingStorage(preferences);
    final auth = AuthController(
      AuthRepository(
        ApiClient(tokenProvider: () async => null),
        authStorage,
      ),
      guestOnboardingStorage: guestStorage,
    );
    addTearDown(auth.dispose);

    final slow = _Plans(hold: Completer<void>());
    final first = DashboardSummaryProvider(weddingPlansApi: slow);
    final plans = _Plans();
    final second = DashboardSummaryProvider(weddingPlansApi: plans);
    addTearDown(first.dispose);
    addTearDown(second.dispose);

    Widget app(DashboardSummaryProvider holder) => MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        Provider<GuestOnboardingStorage>.value(value: guestStorage),
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider<DashboardSummaryProvider>.value(value: holder),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: WeddingPlanDashboardScreen(weddingPlanId: homePlanId),
          ),
        ),
      ),
    );

    // The home asks the first holder; the server has not answered.
    await tester.pumpWidget(app(first));
    await tester.pump();
    expect(slow.asked, 1);
    expect(find.byKey(const ValueKey('aarast-home-skeleton')), findsOneWidget);

    // The account's context settles: the plan's holder is made again.
    await tester.pumpWidget(app(second));
    await tester.pump();
    // The first answer comes late, to the holder nobody reads any more.
    slow.hold!.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(plans.asked, 1, reason: 'the new holder was asked for the plan');
    expect(second.summary?.planId, homePlanId);
    expect(find.byKey(const ValueKey('aarast-home-empty')), findsNothing);
    expect(find.text('ما عندك خطة بعد'), findsNothing);
    expect(find.text('أنشئ خطتك'), findsNothing);
  });
}

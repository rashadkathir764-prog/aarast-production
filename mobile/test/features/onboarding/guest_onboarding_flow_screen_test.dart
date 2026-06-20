import 'package:aarast_mobile/features/onboarding/screens/guest_onboarding_flow_screen.dart';
import 'package:aarast_mobile/features/onboarding/screens/generated_dashboard_preview_screen.dart';
import 'package:aarast_mobile/features/onboarding/screens/provider_path_pending_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('GuestOnboardingFlowScreen', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('provider path stays inside a safe pending screen', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: GuestOnboardingFlowScreen()),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('guest-onboarding-primary-action')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('guest-path-provider')));
      await tester.pumpAndSettle();

      expect(find.byType(ProviderPathPendingScreen), findsOneWidget);
      expect(find.byKey(const Key('provider-dashboard-screen')), findsNothing);
    });

    testWidgets('wedding user path reaches generated preview internally', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: GuestOnboardingFlowScreen()),
      );
      await tester.pumpAndSettle();

      for (var step = 0; step < 8; step += 1) {
        final action = find.byKey(const Key('guest-onboarding-primary-action'));
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        await tester.tap(action);
        await tester.pumpAndSettle();
      }

      expect(find.byType(GeneratedDashboardPreviewScreen), findsOneWidget);
    });
  });
}

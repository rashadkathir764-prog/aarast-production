import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/home/data/dashboard_summary_sources.dart';
import 'package:aarast_mobile/features/home/screens/local_guest_dashboard_screen.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('local dashboard source derives honest guest summary', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = GuestOnboardingStorage(preferences);
    await storage.saveDraft(_guestPlan());

    final summary = await LocalGuestDashboardSummarySource(
      storage,
    ).loadSummary();

    expect(summary, isNotNull);
    expect(summary!.plan.guestPlanId, 'guest-plan-test');
    expect(summary.taskCount, 0);
    expect(summary.guestCount, 0);
    expect(summary.providerCount, 0);
    expect(summary.progressPercent, 0);
    expect(summary.seed.selectedCategories, ['hall', 'photo']);

    final royalSummary = summary.toDashboardSummary();
    expect(royalSummary.title, 'خطة زفاف صنعاء');
    expect(royalSummary.city, 'صنعاء، السبعين، حدة');
    expect(royalSummary.budgetTotal, '1000000');
    expect(royalSummary.remainingBudget, '1000000');
    expect(royalSummary.totalTasks, 0);
    expect(royalSummary.guestCount, 0);
    expect(royalSummary.providerCount, 0);
    expect(royalSummary.currentUserRole, 'GUEST');
    expect(royalSummary.permissions.role, 'GUEST_LOCAL');
  });

  testWidgets(
    'dashboard opens local guest plan in Royal Home and gates sync on tap',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final authStorage = AuthStorage(preferences);
      final summary = LocalGuestDashboardSummary.fromPlan(_guestPlan());

      await tester.pumpWidget(
        Provider<AuthStorage>.value(
          value: authStorage,
          child: MaterialApp(home: LocalGuestDashboardScreen(summary: summary)),
        ),
      );

      expect(find.text('خطة زفاف صنعاء'), findsOneWidget);
      expect(find.text('الأهم اليوم'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('الخطوة التالية المقترحة'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('الخطوة التالية المقترحة'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('المال').first,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('المال'), findsWidgets);
      expect(find.text('إجراء جديد'), findsOneWidget);
      expect(
        find.text('خطة محفوظة على جهازك — سجّل الدخول للمزامنة والمشاركة'),
        findsNothing,
      );

      final syncAction = find.byKey(const Key('royal-local-sync-action'));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
      // Bounded pumps — the dashboard uses repeating animations (live dot,
      // breath CTA) which would otherwise hang pumpAndSettle forever.
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 80));
      }
      expect(syncAction, findsOneWidget);
      await tester.tap(syncAction);
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 80));
      }

      expect(find.text('هذه الخطوة تحتاج حساباً'), findsOneWidget);
      expect(find.text('تسجيل الدخول'), findsOneWidget);
      expect(find.text('إنشاء حساب'), findsOneWidget);
    },
  );
}

GuestOnboardingDraft _guestPlan() {
  return GuestOnboardingDraft(
    guestPlanId: 'guest-plan-test',
    createdAt: DateTime.utc(2026, 6, 19),
    isGuestPlan: true,
    needsSync: true,
    selectedPath: GuestOnboardingPath.weddingUser,
    persona: GuestPersona.groom,
    governorate: 'صنعاء',
    city: 'صنعاء',
    district: 'السبعين',
    neighborhood: 'حدة',
    street: null,
    addressNote: null,
    weddingDate: DateTime.now().add(const Duration(days: 90)),
    weddingDateUnknown: false,
    priorities: const ['budget', 'tasks'],
    currency: 'YER',
    estimatedBudget: '1000000',
    selectedCategoryKeys: const ['hall', 'photo'],
  );
}

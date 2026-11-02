import 'package:aarast_mobile/features/finance/models/money_starter_catalog.dart';
import 'package:aarast_mobile/features/home/data/dashboard_summary_sources.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/tasks/models/task_starter_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Field test Q01, seen again in the running app on 2026-10-23: a groom's plan
// kept on the phone was offered «حجز قاعة النساء», because the starters read
// the persona from a provider the app never creates. The plan's summary is
// the one place a phone plan's persona lives now.
void main() {
  Future<String?> personaOf(GuestPersona persona) async {
    SharedPreferences.setMockInitialValues({});
    final storage = GuestOnboardingStorage(
      await SharedPreferences.getInstance(),
    );
    await storage.saveDraft(
      const GuestOnboardingDraft.empty().copyWith(
        guestPlanId: 'guest-plan-persona',
        planName: 'عرس محمد',
        createdAt: DateTime(2026, 10, 23),
        isGuestPlan: true,
        needsSync: true,
        budgetSkipped: true,
        selectedPath: GuestOnboardingPath.weddingUser,
        persona: persona,
        city: 'صنعاء',
        weddingDate: DateTime(2027, 1, 21),
        currency: 'YER',
      ),
    );
    final local = await LocalGuestDashboardSummarySource(storage).loadSummary();
    return local!.toDashboardSummary().persona;
  }

  test('a phone plan carries whose plan it is in its summary', () async {
    expect(await personaOf(GuestPersona.groom), 'GROOM');
    expect(await personaOf(GuestPersona.bride), 'BRIDE');
    expect(await personaOf(GuestPersona.helper), isNull);
  });

  test(
    'a groom phone plan is never offered the bride tasks or items',
    () async {
      final persona = await personaOf(GuestPersona.groom);

      final taskPersona = taskStarterPersonaFor('guest-plan-persona', [
        (planId: 'guest-plan-persona', persona: persona),
      ]);
      expect(taskPersona, TaskStarterPersona.groom);
      final groups = taskStarterGroupsFor(null, taskPersona);
      expect(groups.map((group) => group.key), isNot(contains('bride-tasks')));
      expect(
        groups.expand((group) => group.templates).map((task) => task.title),
        isNot(contains('حجز قاعة النساء')),
      );

      expect(moneyStarterPersonaFromCode(persona), MoneyStarterPersona.groom);
    },
  );
}

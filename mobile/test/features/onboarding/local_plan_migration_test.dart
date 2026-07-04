import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/data/local_plan_migration.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const guestPlanId = 'local-guest-1234';

  GuestOnboardingDraft buildDraft() {
    return GuestOnboardingDraft(
      guestPlanId: guestPlanId,
      planName: 'عرسنا',
      createdAt: DateTime(2026, 1, 1),
      isGuestPlan: true,
      needsSync: true,
      selectedPath: GuestOnboardingPath.weddingUser,
      persona: GuestPersona.bride,
      governorate: 'صنعاء',
      city: 'صنعاء',
      district: null,
      neighborhood: null,
      street: null,
      addressNote: null,
      weddingDate: DateTime(2026, 10, 20),
      weddingDateUnknown: false,
      priorities: const ['القاعة'],
      currency: 'YER',
      estimatedBudget: '1,500,000',
      selectedCategoryKeys: const ['القاعة'],
    );
  }

  Future<LocalPlanMigrationService> buildService() async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(preferences);
    await database.initialize();
    final guestStorage = GuestOnboardingStorage(preferences);
    await guestStorage.saveDraft(buildDraft());

    await database.saveCachedItem(
      table: OfflineTables.cachedBudgetCategories,
      json: {
        'id': 'local-budget-category-9',
        'weddingPlanId': guestPlanId,
        'name': 'التصوير',
      },
      dirty: true,
    );
    await database.saveCachedItem(
      table: OfflineTables.cachedBudgetItems,
      json: {
        'id': 'local-expense-1',
        'weddingPlanId': guestPlanId,
        'title': 'عربون المصور',
        'amount': '50000',
        'budgetCategoryId': 'local-budget-category-9',
        'status': 'PAID',
      },
      dirty: true,
    );
    await database.saveCachedItem(
      table: OfflineTables.cachedTasks,
      json: {
        'id': 'local-task-1',
        'weddingPlanId': guestPlanId,
        'title': 'حجز القاعة',
        'status': 'WEIRD_STATUS',
        'priority': 'HIGH',
      },
      dirty: true,
    );
    await database.saveCachedItem(
      table: OfflineTables.cachedGuests,
      json: {
        'id': 'local-guest-row-1',
        'weddingPlanId': guestPlanId,
        'name': 'أحمد صالح',
        'phone': '+967700000001',
        'side': 'GROOM',
        'status': 'INVITED',
      },
      dirty: true,
    );

    final apiClient = ApiClient(tokenProvider: () async => null);
    return LocalPlanMigrationService(
      guestStorage: guestStorage,
      weddingPlansApi: WeddingPlansApi(apiClient),
      database: database,
    );
  }

  test('snapshot collects local rows scoped to the guest plan', () async {
    final service = await buildService();

    final snapshot = await service.loadSnapshot();

    expect(snapshot, isNotNull);
    expect(snapshot!.expenses, hasLength(1));
    expect(snapshot.tasks, hasLength(1));
    expect(snapshot.guests, hasLength(1));
    expect(snapshot.categoryNameById['local-budget-category-9'], 'التصوير');
  });

  test('import payload maps local data to the server contract', () async {
    final service = await buildService();
    final snapshot = await service.loadSnapshot();

    final payload = service.buildImportPayload(snapshot!);

    // Idempotency: the stable local plan id is the migration key.
    expect(payload['clientMigrationId'], guestPlanId);
    expect(payload['persona'], 'BRIDE');
    expect(payload['title'], 'عرسنا');
    expect(payload['estimatedBudget'], '1500000');
    expect(payload['currency'], 'YER');

    final expenses = payload['expenses'] as List;
    final expense = expenses.single as Map<String, dynamic>;
    // Local category ids are meaningless server-side: mapped to NAME.
    expect(expense['categoryName'], 'التصوير');
    expect(expense.containsKey('budgetCategoryId'), isFalse);
    expect(expense['amount'], '50000');

    final tasks = payload['tasks'] as List;
    final task = tasks.single as Map<String, dynamic>;
    // Off-enum values are dropped so one bad row can't fail the migration.
    expect(task.containsKey('status'), isFalse);
    expect(task['priority'], 'HIGH');

    final guests = payload['guests'] as List;
    final guest = guests.single as Map<String, dynamic>;
    expect(guest['name'], 'أحمد صالح');
    expect(guest['side'], 'GROOM');
  });

  test('no pending plan yields null snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final guestStorage = GuestOnboardingStorage(preferences);
    final apiClient = ApiClient(tokenProvider: () async => null);
    final service = LocalPlanMigrationService(
      guestStorage: guestStorage,
      weddingPlansApi: WeddingPlansApi(apiClient),
    );

    expect(await service.loadSnapshot(), isNull);
  });
}

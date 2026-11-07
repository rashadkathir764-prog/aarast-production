import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart'
    show planGuestsMax;
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
      table: OfflineTables.cachedCosts,
      json: {
        'id': 'local-cost-1',
        'weddingPlanId': guestPlanId,
        'title': 'تكلفة المصور',
        'totalAmount': '100000',
        'paidAmount': '40000',
        'budgetCategoryId': 'local-budget-category-9',
        'partyName': 'استديو النور',
        'status': 'PARTIALLY_PAID',
      },
      dirty: true,
    );
    await database.saveCachedItem(
      table: OfflineTables.cachedCosts,
      json: {
        'id': 'local-cost-cancelled',
        'weddingPlanId': guestPlanId,
        'title': 'تكلفة ملغية',
        'totalAmount': '50000',
        'paidAmount': '0',
        'budgetCategoryId': 'local-budget-category-9',
        'status': 'CANCELLED',
      },
      dirty: true,
    );
    for (final payment in [
      {
        'id': 'payment-active',
        'weddingPlanId': guestPlanId,
        'costId': 'local-cost-1',
        'amount': '30000',
        'entryType': 'PAYMENT',
        'paidAt': '2026-01-10T10:00:00.000Z',
      },
      {
        'id': 'payment-from-schedule',
        'weddingPlanId': guestPlanId,
        'costId': 'local-cost-1',
        'amount': '10000',
        'entryType': 'PAYMENT',
        'paymentScheduleId': 'schedule-paid',
        'paidAt': '2026-01-11T10:00:00.000Z',
      },
      {
        'id': 'payment-reversed',
        'weddingPlanId': guestPlanId,
        'costId': 'local-cost-1',
        'amount': '20000',
        'entryType': 'PAYMENT',
        'paidAt': '2026-01-12T10:00:00.000Z',
      },
      {
        'id': 'reversal-1',
        'weddingPlanId': guestPlanId,
        'costId': 'local-cost-1',
        'amount': '20000',
        'entryType': 'REVERSAL',
        'reversalOfId': 'payment-reversed',
        'paidAt': '2026-01-13T10:00:00.000Z',
      },
    ]) {
      await database.saveCachedItem(
        table: OfflineTables.cachedCostPayments,
        json: payment,
        dirty: true,
      );
    }
    for (final schedule in [
      {
        'id': 'schedule-pending',
        'weddingPlanId': guestPlanId,
        'costId': 'local-cost-1',
        'amount': '40000',
        'dueDate': '2026-09-01',
        'status': 'PENDING',
      },
      {
        'id': 'schedule-paid',
        'weddingPlanId': guestPlanId,
        'costId': 'local-cost-1',
        'amount': '10000',
        'dueDate': '2026-08-01',
        'status': 'PAID',
        'paidAt': '2026-01-11T10:00:00.000Z',
      },
      {
        'id': 'schedule-cancelled',
        'weddingPlanId': guestPlanId,
        'costId': 'local-cost-1',
        'amount': '10000',
        'dueDate': '2026-07-01',
        'status': 'CANCELLED',
      },
    ]) {
      await database.saveCachedItem(
        table: OfflineTables.cachedPaymentSchedules,
        json: schedule,
        dirty: true,
      );
    }
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
      financeApi: FinanceApi(apiClient),
      database: database,
    );
  }

  test('snapshot collects local rows scoped to the guest plan', () async {
    final service = await buildService();

    final snapshot = await service.loadSnapshot();

    expect(snapshot, isNotNull);
    expect(snapshot!.costs, hasLength(2));
    expect(snapshot.costPayments, hasLength(4));
    expect(snapshot.paymentSchedules, hasLength(3));
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
    // The items as they are in the plan's money now, not the list the plan
    // started with (the draft had «القاعة»; money now holds «التصوير»).
    expect(payload['selectedCategories'], ['التصوير']);

    expect(payload.containsKey('expenses'), isFalse);
    final costs = payload['costs'] as List;
    final cost = costs.single as Map<String, dynamic>;
    // Cancelled costs are not resurrected in the new account.
    expect(cost['title'], 'تكلفة المصور');
    // Local category ids are meaningless server-side: mapped to NAME.
    expect(cost['categoryName'], 'التصوير');
    expect(cost.containsKey('budgetCategoryId'), isFalse);
    expect(cost['totalAmount'], '100000');

    final payments = cost['payments'] as List;
    expect(payments, hasLength(2));
    expect(
      payments.map((item) => (item as Map)['amount']),
      unorderedEquals(['30000', '10000']),
    );
    expect(
      payments.any((item) => (item as Map)['amount'] == '20000'),
      isFalse,
      reason: 'the original and its reversal net to zero',
    );

    final schedules = cost['paymentSchedules'] as List;
    expect(schedules, hasLength(1));
    expect((schedules.single as Map)['amount'], '40000');
    expect((schedules.single as Map)['dueDate'], '2026-09-01');

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

  // J1-13: the server takes at most so many starting items; a phone plan
  // with more is never refused for it. Items that carry an agreement go
  // with the agreement (the server keeps each agreement's item), so they
  // are the ones left out of the list when it is full.
  test('the import never sends more items than the server takes', () async {
    final service = await buildService();
    final names = [for (var i = 0; i < 70; i++) 'بند $i'];
    final snapshot = LocalPlanSnapshot(
      draft: buildDraft(),
      costs: [
        for (var i = 0; i < 15; i++)
          {
            'id': 'cost-$i',
            'title': 'اتفاق $i',
            'totalAmount': '1000',
            'budgetCategoryId': 'c$i',
          },
      ],
      costPayments: const [],
      paymentSchedules: const [],
      tasks: const [],
      guests: const [],
      categoryNameById: {for (var i = 0; i < 70; i++) 'c$i': names[i]},
    );

    final payload = service.buildImportPayload(snapshot);

    final sent = payload['selectedCategories'] as List;
    expect(LocalPlanMigrationService.maxStartingItems, 60);
    expect(sent, hasLength(LocalPlanMigrationService.maxStartingItems));
    // Every item still reaches the account: in the list or with its cost.
    final withCosts = [
      for (final cost in payload['costs'] as List)
        (cost as Map)['categoryName'],
    ];
    expect({...sent, ...withCosts}, names.toSet());
    // The list keeps the plan's own order.
    expect(sent, [
      for (final name in names)
        if (sent.contains(name)) name,
    ]);
  });

  test('a plan within the cap sends every item as it is', () async {
    final service = await buildService();
    final snapshot = await service.loadSnapshot();
    final payload = service.buildImportPayload(snapshot!);
    expect(payload['selectedCategories'], ['التصوير']);
  });

  test('no pending plan yields null snapshot', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final guestStorage = GuestOnboardingStorage(preferences);
    final apiClient = ApiClient(tokenProvider: () async => null);
    final service = LocalPlanMigrationService(
      guestStorage: guestStorage,
      weddingPlansApi: WeddingPlansApi(apiClient),
      financeApi: FinanceApi(apiClient),
    );

    expect(await service.loadSnapshot(), isNull);
  });

  test(
    'RA-BE-65: a second save of the plan keeps its own id on every retry',
    () async {
      final service = await buildService();
      final storage = service.guestStorage;

      final first = await service.loadSnapshot();
      expect(first!.migrationId, guestPlanId);
      expect(
        service.buildImportPayload(first)['clientMigrationId'],
        guestPlanId,
      );

      await storage.startNewImport(guestPlanId);
      final second = await service.loadSnapshot();
      expect(second!.migrationId, '$guestPlanId~2');
      expect(
        service.buildImportPayload(second)['clientMigrationId'],
        '$guestPlanId~2',
      );
      // Read again (a retry of the same save): the same id.
      expect((await service.loadSnapshot())!.migrationId, '$guestPlanId~2');

      await storage.startNewImport(guestPlanId);
      expect((await service.loadSnapshot())!.migrationId, '$guestPlanId~3');

      // The plan leaves the phone: the next plan starts from its own id.
      await storage.clearDraft();
      expect(await storage.importMigrationId(guestPlanId), guestPlanId);
    },
  );

  test(
    'RA-BE-64: a plan past what one save takes is said before it is sent',
    () {
      Map<String, dynamic> plan({
        int guests = 0,
        int tasks = 0,
        int costs = 0,
      }) => {
        'guests': [
          for (var i = 0; i < guests; i++) {'name': 'ضيف $i'},
        ],
        'tasks': [
          for (var i = 0; i < tasks; i++) {'title': 'مهمة $i'},
        ],
        'costs': [
          for (var i = 0; i < costs; i++) {'title': 'اتفاق $i'},
        ],
      };

      // One save takes as many guests as a plan holds (D99).
      expect(LocalPlanMigrationService.maxImportGuests, planGuestsMax);
      expect(
        LocalPlanMigrationService.tooLargeReason(plan(guests: 5000)),
        isNull,
      );
      expect(
        LocalPlanMigrationService.tooLargeReason(plan(guests: 5001)),
        contains('5000 ضيف'),
      );
      expect(
        LocalPlanMigrationService.tooLargeReason(plan(tasks: 2000)),
        isNull,
      );
      expect(
        LocalPlanMigrationService.tooLargeReason(plan(tasks: 2001)),
        contains('2000 مهمة'),
      );
      expect(
        LocalPlanMigrationService.tooLargeReason(plan(costs: 1000)),
        isNull,
      );
      expect(
        LocalPlanMigrationService.tooLargeReason(plan(costs: 1001)),
        contains('1000 اتفاق'),
      );
      expect(
        LocalPlanMigrationService.tooLargeReason({
          'guests': [
            {
              'name': 'ضيف',
              'notes':
                  'ن' * (LocalPlanMigrationService.maxImportBytes ~/ 2 + 1),
            },
          ],
        }),
        contains('خفّف الملاحظات'),
      );
    },
  );

  // A guest marked «أكد» on the phone reaches the account as a reply, the
  // column the guest list and the home read, not only as the old `status`.
  test('the import carries each guest\'s reply and invitation', () async {
    final service = await buildService();
    final snapshot = (await service.loadSnapshot())!;
    final withReplies = LocalPlanSnapshot(
      draft: snapshot.draft,
      costs: const [],
      costPayments: const [],
      paymentSchedules: const [],
      tasks: const [],
      guests: const [
        {
          'id': 'g1',
          'name': 'أبو محمد',
          'status': 'CONFIRMED',
          'attendanceStatus': 'CONFIRMED',
          'invitationStatus': 'SENT',
        },
        {'id': 'g2', 'name': 'خالد', 'attendanceStatus': 'MAYBE'},
      ],
      categoryNameById: const {},
    );

    final guests = service.buildImportPayload(withReplies)['guests'] as List;
    expect(guests[0]['attendanceStatus'], 'CONFIRMED');
    expect(guests[0]['invitationStatus'], 'SENT');
    // A value the server does not take is left out, not sent to be refused.
    expect((guests[1] as Map).containsKey('attendanceStatus'), isFalse);
  });
}

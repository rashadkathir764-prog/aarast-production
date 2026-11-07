import 'dart:convert';

import '../../../core/offline/local_database.dart';
import '../../../core/offline/offline_tables.dart';
import '../../../core/utils/plan_day.dart';
import '../../finance/finance_api.dart' show FinanceApi;
import '../../wedding_plans/wedding_plans_api.dart'
    show OnboardingCompleteResponse, WeddingPlansApi;
import '../models/guest_onboarding_draft.dart';
import 'guest_onboarding_storage.dart';

/// Snapshot of everything a guest planned locally, ready to be shown in the
/// migration prompt and uploaded to the account.
class LocalPlanSnapshot {
  const LocalPlanSnapshot({
    required this.draft,
    required this.costs,
    required this.costPayments,
    required this.paymentSchedules,
    required this.tasks,
    required this.guests,
    required this.categoryNameById,
    this.migrationId,
  });

  final GuestOnboardingDraft draft;

  /// RA-BE-65: the id the account knows this save by; the plan's phone id
  /// unless the person chose to keep it as a second plan.
  final String? migrationId;
  final List<Map<String, dynamic>> costs;
  final List<Map<String, dynamic>> costPayments;
  final List<Map<String, dynamic>> paymentSchedules;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> guests;
  final Map<String, String> categoryNameById;

  bool get hasAnyRecords =>
      costs.isNotEmpty || tasks.isNotEmpty || guests.isNotEmpty;

  /// The plan's money items as they are now (added, renamed or removed in
  /// its money), or the items it started with when it has none yet.
  List<String> get itemNames {
    final names = categoryNameById.values.toSet().toList();
    return names.isNotEmpty ? names : draft.selectedCategoryKeys;
  }
}

/// RA-BE-64: the plan is past what one save takes; said before sending.
class LocalPlanTooLarge implements Exception {
  const LocalPlanTooLarge(this.message);

  final String message;

  @override
  String toString() => message;
}

/// What the account's own open plan holds, for w09's «في حسابك» card.
class AccountPlanCounts {
  const AccountPlanCounts({
    required this.items,
    required this.tasks,
    this.title = '',
  });

  final int items;
  final int tasks;

  /// The account plan by name and city («عرس أحمد · تعز»), so the choice
  /// is between two plans the person recognises.
  final String title;
}

/// Migrates a guest-mode local plan into the authenticated account.
///
/// Hard rule: local data is NEVER deleted here. The caller clears it only
/// after the server confirms the import — a guest's weeks of planning must
/// never be lost to a network failure.
class LocalPlanMigrationService {
  const LocalPlanMigrationService({
    required this.guestStorage,
    required this.weddingPlansApi,
    required this.financeApi,
    this.database,
  });

  final GuestOnboardingStorage guestStorage;
  final WeddingPlansApi weddingPlansApi;
  final FinanceApi financeApi;
  final LocalDatabase? database;

  /// J1-13: the most starting items the server takes in one plan:
  /// `PLAN_STARTER_ITEMS_MAX`, the `@ArrayMaxSize` of
  /// `CompleteOnboardingDto.selectedCategories` (backend
  /// `src/onboarding/dto/complete-onboarding.dto.ts`), which
  /// `ImportLocalPlanDto` inherits. Keep the two equal.
  static const maxStartingItems = 60;

  static const _taskStatuses = {'TODO', 'IN_PROGRESS', 'DONE', 'CANCELLED'};
  static const _taskPriorities = {'LOW', 'MEDIUM', 'HIGH', 'URGENT'};
  static const _guestSides = {'GROOM', 'BRIDE', 'FAMILY', 'FRIEND', 'OTHER'};
  static const _guestStatuses = {'INVITED', 'CONFIRMED', 'DECLINED', 'PENDING'};

  /// The complete guest plan waiting to be migrated, if any.
  Future<GuestOnboardingDraft?> pendingGuestPlan() {
    return guestStorage.loadGuestPlan();
  }

  Future<LocalPlanSnapshot?> loadSnapshot() async {
    final draft = await pendingGuestPlan();
    if (draft == null) return null;

    final planId = draft.guestPlanId;
    final categories = await _rows(
      OfflineTables.cachedBudgetCategories,
      planId,
    );

    return LocalPlanSnapshot(
      draft: draft,
      migrationId: planId == null
          ? null
          : await guestStorage.importMigrationId(planId),
      costs: await _rows(OfflineTables.cachedCosts, planId),
      costPayments: await _rows(OfflineTables.cachedCostPayments, planId),
      paymentSchedules: await _rows(
        OfflineTables.cachedPaymentSchedules,
        planId,
      ),
      tasks: await _rows(OfflineTables.cachedTasks, planId),
      guests: await _rows(OfflineTables.cachedGuests, planId),
      categoryNameById: {
        for (final row in categories)
          if (_text(row['id']) != null && _text(row['name']) != null)
            _text(row['id'])!: _text(row['name'])!,
      },
    );
  }

  /// The account's own open plan (w09): the one open now when the account
  /// owns it, otherwise the one changed last. Null when the account owns no
  /// open plan, so the plan kept on this phone is saved without asking.
  Future<AccountPlanCounts?> accountPlanCounts() async {
    final plans = (await weddingPlansApi.getMyWeddingPlans())
        .where((plan) => plan.status != 'ARCHIVED')
        .toList();
    if (plans.isEmpty) return null;
    final active = await weddingPlansApi.getActiveWeddingPlan();
    plans.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final plan = plans.firstWhere(
      (plan) => plan.id == active?.id,
      orElse: () => plans.first,
    );
    final items = await financeApi.getBudgetCategories(plan.id);
    final summary = await weddingPlansApi.getDashboardSummary(plan.id);
    return AccountPlanCounts(
      items: items.length,
      tasks: summary.totalTasks,
      title: [
        plan.title.trim(),
        plan.city?.trim() ?? '',
      ].where((part) => part.isNotEmpty).join(' · '),
    );
  }

  /// RA-BE-64: the most one save takes, the server's own bounds
  /// (`backend/src/onboarding/dto/import-local-plan.dto.ts`: guests stop
  /// where a plan stops, D99, the guests' own `planGuestsMax`; tasks,
  /// agreements and the body are bounds no real wedding reaches). Keep them
  /// equal; a test holds the guests' one to `planGuestsMax`.
  static const maxImportGuests = 5000;
  static const maxImportTasks = 2000;
  static const maxImportCosts = 1000;
  static const maxImportBytes = 8 * 1024 * 1024;

  /// Why this plan cannot go in one save, in words for the person; null
  /// when it fits.
  static String? tooLargeReason(Map<String, dynamic> payload) {
    int count(String key) => (payload[key] as List?)?.length ?? 0;
    if (count('guests') > maxImportGuests) {
      return 'خطتك فيها أكثر من $maxImportGuests ضيف، والحساب يشيل $maxImportGuests بالكثير.';
    }
    if (count('tasks') > maxImportTasks) {
      return 'خطتك فيها أكثر من $maxImportTasks مهمة، والحساب ياخذ $maxImportTasks بالكثير مرة وحدة.';
    }
    if (count('costs') > maxImportCosts) {
      return 'خطتك فيها أكثر من $maxImportCosts اتفاق، والحساب ياخذ $maxImportCosts بالكثير مرة وحدة.';
    }
    if (utf8.encode(jsonEncode(payload)).length > maxImportBytes) {
      return 'خطتك أكبر من اللي ينحفظ مرة وحدة. خفّف الملاحظات الطويلة وجرّب.';
    }
    return null;
  }

  /// Uploads the snapshot into the authenticated account in one idempotent
  /// call. The save's id ([LocalPlanSnapshot.migrationId]) is the
  /// idempotency key: a retry of the same plan after a timeout returns the
  /// plan already saved instead of duplicating it, and a retry after the
  /// plan changed on the phone is refused (LOCAL_PLAN_SAVED_BEFORE) instead
  /// of answering with the old one.
  Future<OnboardingCompleteResponse> migrate(LocalPlanSnapshot snapshot) {
    final payload = buildImportPayload(snapshot);
    final reason = tooLargeReason(payload);
    if (reason != null) throw LocalPlanTooLarge(reason);
    return weddingPlansApi.importLocalPlan(payload);
  }

  /// Pure payload mapping — kept separate so the contract is testable
  /// without network plumbing.
  Map<String, dynamic> buildImportPayload(LocalPlanSnapshot snapshot) {
    final draft = snapshot.draft;
    final location = draft.weddingLocation;
    final city = _text(location.cityOrDistrict);

    final reversedPaymentIds = _reversedPaymentIds(snapshot.costPayments);
    final costs = [
      for (final row in snapshot.costs)
        ?_costPayload(row, snapshot, reversedPaymentIds),
    ];
    final payload = <String, dynamic>{
      'clientMigrationId': snapshot.migrationId ?? draft.guestPlanId,
      'path': 'USER',
      'persona': switch (draft.persona) {
        GuestPersona.bride => 'BRIDE',
        GuestPersona.helper => 'HELPER',
        _ => 'GROOM',
      },
      'title': ?_text(draft.planName),
      'city': ?city,
      if (location.hasAnyLocation) 'location': location.toJson(),
      if (draft.weddingDate != null)
        'weddingDate': planDayToJson(draft.weddingDate!),
      if (draft.priorities.isNotEmpty) 'priorities': draft.priorities,
      if (_budget(draft) != null) 'estimatedBudget': _budget(draft),
      'currency': draft.currency ?? 'YER',
      // The items as they are in the plan's money now (added, renamed or
      // removed there), not the list the plan started with.
      if (_itemNames(snapshot, costs).isNotEmpty)
        'selectedCategories': _itemNames(snapshot, costs),
      // a06: the server records the mahr with the plan (C1).
      if (draft.mahr case final mahr?) 'mahr': mahr.toRequestJson(),
      if (costs.isNotEmpty) 'costs': costs,
      if (snapshot.tasks.isNotEmpty)
        'tasks': [for (final row in snapshot.tasks) _taskPayload(row)],
      if (snapshot.guests.isNotEmpty)
        'guests': [for (final row in snapshot.guests) _guestPayload(row)],
    };

    return payload;
  }

  /// The plan's items, never more than [maxStartingItems] (J1-13). When the
  /// plan holds more, the items that carry an agreement are left out of the
  /// list first: each still reaches the account with its agreement's
  /// `categoryName`, so nothing is lost while there is room for the rest.
  static List<String> _itemNames(
    LocalPlanSnapshot snapshot,
    List<Map<String, dynamic>> costs,
  ) {
    final names = snapshot.itemNames;
    if (names.length <= maxStartingItems) return names;
    final withCosts = {for (final cost in costs) cost['categoryName']};
    final kept = {
      ...names.where((name) => !withCosts.contains(name)),
      ...names.where(withCosts.contains),
    }.take(maxStartingItems).toSet();
    return [
      for (final name in names)
        if (kept.contains(name)) name,
    ];
  }

  Map<String, dynamic>? _costPayload(
    Map<String, dynamic> row,
    LocalPlanSnapshot snapshot,
    Set<String> reversedPaymentIds,
  ) {
    if (_text(row['status'])?.toUpperCase() == 'CANCELLED') return null;
    final totalAmount = _positiveMoney(row['totalAmount']);
    if (totalAmount == null) return null;
    final costId = _text(row['id']);
    if (costId == null) return null;
    final categoryName =
        snapshot.categoryNameById[_text(row['budgetCategoryId'])] ??
        _text(row['categoryName']) ??
        'أخرى';
    final activePayments = snapshot.costPayments
        .where((payment) {
          if (_text(payment['costId']) != costId) return false;
          if (_text(payment['entryType'])?.toUpperCase() == 'REVERSAL') {
            return false;
          }
          final id = _text(payment['id']);
          return id != null &&
              !reversedPaymentIds.contains(id) &&
              _positiveMoney(payment['amount']) != null;
        })
        .toList(growable: false);
    final paidScheduleIds = {
      for (final payment in activePayments)
        ?_text(payment['paymentScheduleId']),
    };
    final pendingSchedules = snapshot.paymentSchedules
        .where((schedule) {
          if (_text(schedule['costId']) != costId) return false;
          final id = _text(schedule['id']);
          return _text(schedule['status'])?.toUpperCase() == 'PENDING' &&
              _text(schedule['paidAt']) == null &&
              (id == null || !paidScheduleIds.contains(id)) &&
              _positiveMoney(schedule['amount']) != null &&
              _text(schedule['dueDate']) != null;
        })
        .toList(growable: false);
    return {
      'title': _text(row['title']) ?? 'تكلفة',
      'totalAmount': totalAmount,
      'categoryName': categoryName,
      'partyName': ?(_text(row['partyName']) ?? _text(row['providerName'])),
      'partyPhone': ?_text(row['partyPhone']),
      'agreementDate': ?_text(row['agreementDate']),
      'dueDate': ?_text(row['dueDate']),
      'note': ?_text(row['note']),
      if (activePayments.isNotEmpty)
        'payments': [
          for (final payment in activePayments)
            {
              'amount': _positiveMoney(payment['amount']),
              'paidAt': ?_text(payment['paidAt']),
              'method': ?_text(payment['method']),
              'note': ?_text(payment['note']),
            },
        ],
      if (pendingSchedules.isNotEmpty)
        'paymentSchedules': [
          for (final schedule in pendingSchedules)
            {
              'amount': _positiveMoney(schedule['amount']),
              'dueDate': _text(schedule['dueDate']),
              'note': ?_text(schedule['note']),
            },
        ],
    };
  }

  static Set<String> _reversedPaymentIds(List<Map<String, dynamic>> payments) {
    return {
      for (final payment in payments)
        if (_text(payment['entryType'])?.toUpperCase() == 'REVERSAL')
          ?_text(payment['reversalOfId']),
      for (final payment in payments)
        if (_text(payment['reversedById']) != null) ?_text(payment['id']),
    };
  }

  Map<String, dynamic> _taskPayload(Map<String, dynamic> row) {
    final status = _enumOrNull(row['status'], _taskStatuses);
    final priority = _enumOrNull(row['priority'], _taskPriorities);
    return {
      'title': _text(row['title']) ?? 'مهمة',
      'description': ?_text(row['description']),
      'dueDate': ?_text(row['dueDate']),
      'taskCategory': ?_text(row['taskCategory']),
      'reminderAt': ?_text(row['reminderAt']),
      'status': ?status,
      'priority': ?priority,
    };
  }

  Map<String, dynamic> _guestPayload(Map<String, dynamic> row) {
    final side = _enumOrNull(row['side'], _guestSides);
    final status = _enumOrNull(row['status'], _guestStatuses);
    return {
      'name': _text(row['name']) ?? 'ضيف',
      'phone': ?_text(row['phone']),
      'side': ?side,
      'status': ?status,
      'notes': ?_text(row['notes']),
    };
  }

  Future<List<Map<String, dynamic>>> _rows(String table, String? planId) async {
    final db = database;
    if (db == null || planId == null || planId.isEmpty) return const [];
    return db.readCachedList(
      table: table,
      parentColumn: 'planId',
      parentId: planId,
    );
  }

  static String? _budget(GuestOnboardingDraft draft) {
    final raw = draft.estimatedBudget?.replaceAll(',', '').trim();
    return raw == null || raw.isEmpty ? null : raw;
  }

  static String? _positiveMoney(Object? value) {
    final text = _text(value)?.replaceAll(',', '');
    final parsed = num.tryParse(text ?? '');
    return parsed != null && parsed > 0 ? text : null;
  }

  static String? _enumOrNull(Object? value, Set<String> allowed) {
    final text = _text(value)?.toUpperCase();
    return text != null && allowed.contains(text) ? text : null;
  }

  static String? _text(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty || text == 'null' ? null : text;
  }
}

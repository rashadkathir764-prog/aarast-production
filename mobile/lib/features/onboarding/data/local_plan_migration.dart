import '../../../core/offline/local_database.dart';
import '../../../core/offline/offline_tables.dart';
import '../../wedding_plans/data/wedding_plans_api.dart';
import '../../wedding_plans/models/onboarding_complete.dart';
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
  });

  final GuestOnboardingDraft draft;
  final List<Map<String, dynamic>> costs;
  final List<Map<String, dynamic>> costPayments;
  final List<Map<String, dynamic>> paymentSchedules;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> guests;
  final Map<String, String> categoryNameById;

  bool get hasAnyRecords =>
      costs.isNotEmpty || tasks.isNotEmpty || guests.isNotEmpty;
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
    this.database,
  });

  final GuestOnboardingStorage guestStorage;
  final WeddingPlansApi weddingPlansApi;
  final LocalDatabase? database;

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

  /// Uploads the snapshot into the authenticated account in one idempotent
  /// call. The stable local plan id doubles as the idempotency key, so a
  /// retry after a timeout returns the already-imported plan instead of
  /// duplicating it.
  Future<OnboardingCompleteResponse> migrate(LocalPlanSnapshot snapshot) {
    return weddingPlansApi.importLocalPlan(buildImportPayload(snapshot));
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
      'clientMigrationId': draft.guestPlanId,
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
        'weddingDate': draft.weddingDate!.toIso8601String(),
      if (draft.priorities.isNotEmpty) 'priorities': draft.priorities,
      if (_budget(draft) != null) 'estimatedBudget': _budget(draft),
      'currency': draft.currency ?? 'YER',
      if (draft.selectedCategoryKeys.isNotEmpty)
        'selectedCategories': draft.selectedCategoryKeys,
      if (costs.isNotEmpty) 'costs': costs,
      if (snapshot.tasks.isNotEmpty)
        'tasks': [for (final row in snapshot.tasks) _taskPayload(row)],
      if (snapshot.guests.isNotEmpty)
        'guests': [for (final row in snapshot.guests) _guestPayload(row)],
    };

    return payload;
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

import 'dart:convert';

import 'offline_tables.dart';

class LocalCacheRow {
  const LocalCacheRow({required this.table, required this.columns});

  final String table;
  final Map<String, Object?> columns;
}

LocalCacheRow buildCacheRow({
  required String table,
  required Map<String, dynamic> json,
  DateTime? now,
  bool dirty = false,
  bool deletedLocally = false,
}) {
  final timestamp = now ?? DateTime.now();
  final updatedAt = _stringOrNow(json['updatedAt'], timestamp);
  final rawJson = jsonEncode(json);
  final base = <String, Object?>{
    'id': _idFor(table, json),
    'rawJson': rawJson,
    'dirty': dirty ? 1 : 0,
    'deletedLocally': deletedLocally ? 1 : 0,
    'updatedAt': updatedAt,
    'syncedAt': dirty ? null : timestamp.toIso8601String(),
  };

  switch (table) {
    case OfflineTables.currentUserProfile:
      base.addAll({
        'name': _string(json['name']),
        'phone': _string(json['phone']),
        'role': _string(json['role']),
      });
    case OfflineTables.cachedWeddingPlans:
      base.addAll({
        'title': _string(json['title']),
        'ownerId': _string(json['ownerUserId']),
        'status': _string(json['status']) ?? 'PLANNING',
      });
    case OfflineTables.cachedPlanMembers:
      base.addAll({
        'planId': _string(json['weddingPlanId']),
        'userId': _string(json['userId']),
        'phone': _memberPhone(json),
        'role': _string(json['role']),
        'permissionsJson': jsonEncode({
          'canViewBudget': json['canViewBudget'] == true,
          'canViewExpenses': json['canViewExpenses'] == true,
          'canViewDebts': json['canViewDebts'] == true,
          'canManageTasks': json['canManageTasks'] == true,
          'canManageFinancialRecords':
              json['canManageFinancialRecords'] == true,
        }),
      });
    case OfflineTables.cachedGuests:
      base.addAll({
        'planId': _string(json['weddingPlanId']),
        'name': _string(json['name']),
        'phone': _string(json['phone']),
        'side': _string(json['side']) ?? 'OTHER',
        'status': _string(json['status']) ?? 'INVITED',
      });
    case OfflineTables.cachedTasks:
      base.addAll({
        'planId': _string(json['weddingPlanId']),
        'title': _string(json['title']),
        'dueDate': _string(json['dueDate']),
        'status': _string(json['status']) ?? 'TODO',
        'priority': _string(json['priority']) ?? 'MEDIUM',
      });
    case OfflineTables.cachedBudgetCategories:
      base.addAll({
        'planId': _string(json['weddingPlanId']),
        'name': _string(json['name']),
        'targetAmount': _string(json['targetAmount']),
      });
    case OfflineTables.cachedBudgetItems:
      base.addAll({
        'planId': _string(json['weddingPlanId']),
        'category': _string(json['category']) ?? _string(json['title']),
        'amount': _string(json['amount']),
        'paidAmount': json['status'] == 'PAID' ? _string(json['amount']) : null,
        'status': _string(json['status']) ?? 'PAID',
      });
    case OfflineTables.cachedDebts:
      base.addAll({
        'planId': _string(json['weddingPlanId']),
        'title': _string(json['title']),
        'creditorName': _string(json['creditorName']),
        'amount': _string(json['totalAmount']),
        'paidAmount': _string(json['paidAmount']),
        'status': _string(json['status']) ?? 'OPEN',
      });
    case OfflineTables.cachedInstallments:
      base.addAll({
        'debtId': _string(json['debtId']),
        'amount': _string(json['amount']),
        'dueDate': _string(json['dueDate']),
        'status': _string(json['status']) ?? 'PENDING',
      });
    case OfflineTables.cachedFinancialCommitments:
      base.addAll({
        'planId': _string(json['weddingPlanId']),
        'categoryId': _string(json['budgetCategoryId']),
        'providerId': _string(json['providerId']),
        'title': _string(json['title']),
        'totalAmount': _string(json['totalAmount']),
        'paidAmount': _string(json['paidAmount']),
        'status': _string(json['status']) ?? 'OPEN',
      });
    case OfflineTables.cachedFinancialPaymentRecords:
      base.addAll({
        'planId': _string(json['weddingPlanId']),
        'commitmentId': _string(json['financialCommitmentId']),
        'categoryId': _string(json['budgetCategoryId']),
        'amount': _string(json['amount']),
        'paidAt': _string(json['paidAt']),
      });
    case OfflineTables.cachedFinancialInstallments:
      base.addAll({
        'planId': _string(json['weddingPlanId']),
        'commitmentId': _string(json['financialCommitmentId']),
        'categoryId': _string(json['budgetCategoryId']),
        'amount': _string(json['amount']),
        'dueDate': _string(json['dueDate']),
        'status': _string(json['status']) ?? 'PENDING',
      });
    case OfflineTables.cachedProviderCategories:
      base.addAll({
        'nameAr': _string(json['nameAr']) ?? _string(json['name']),
        'name': _string(json['nameEn']) ?? _string(json['name']),
      });
    case OfflineTables.cachedCities:
      base.addAll({
        'nameAr': _string(json['nameAr']) ?? _string(json['name']),
        'name': _string(json['nameEn']) ?? _string(json['name']),
      });
    case OfflineTables.cachedProviders:
      base.addAll({
        'name': _string(json['businessName']) ?? _string(json['name']),
        'categoryId': _providerCategoryId(json),
        'cityId': _string(json['cityId']),
        'status': _string(json['status']) ?? 'ACTIVE',
      });
    case OfflineTables.cachedProviderServices:
      base.addAll({
        'providerId': _string(json['providerId']),
        'title': _string(json['title']),
        'categoryId': _string(json['categoryId']),
      });
    case OfflineTables.cachedProviderPackages:
      base.addAll({
        'providerId': _string(json['providerId']),
        'title': _string(json['title']),
        'serviceId': _string(json['serviceId']),
      });
    case OfflineTables.cachedBookings:
      base.addAll({
        'providerId': _string(json['providerId']),
        'planId': _string(json['weddingPlanId']),
        'status': _string(json['status']) ?? 'SENT',
      });
    case OfflineTables.cachedFavoriteProviders:
      base.addAll({
        'providerId': _string(json['providerId']) ?? _string(json['id']),
      });
  }

  return LocalCacheRow(table: table, columns: base);
}

String _idFor(String table, Map<String, dynamic> json) {
  final id = _string(json['id']);
  if (id != null && id.isNotEmpty) return id;
  if (table == OfflineTables.cachedFavoriteProviders) {
    return _string(json['providerId']) ??
        'favorite-${DateTime.now().microsecondsSinceEpoch}';
  }
  return 'local-${DateTime.now().microsecondsSinceEpoch}';
}

String _stringOrNow(Object? value, DateTime now) {
  final text = _string(value);
  return text == null || text.isEmpty ? now.toIso8601String() : text;
}

String? _string(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  return text.isEmpty ? null : text;
}

String? _memberPhone(Map<String, dynamic> json) {
  final direct = _string(json['phone']);
  if (direct != null) return direct;
  final user = json['user'];
  if (user is Map) return _string(user['phone']);
  return null;
}

String? _providerCategoryId(Map<String, dynamic> json) {
  final direct =
      _string(json['primaryCategoryId']) ?? _string(json['categoryId']);
  if (direct != null) return direct;
  final services = json['services'];
  if (services is List && services.isNotEmpty && services.first is Map) {
    return _string((services.first as Map)['categoryId']);
  }
  return null;
}

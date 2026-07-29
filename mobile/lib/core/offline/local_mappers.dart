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
          'canViewMoney': json['canViewMoney'] == true,
          'canManageTasks': json['canManageTasks'] == true,
          'canManageMoney': json['canManageMoney'] == true,
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
        'allocatedAmount': _string(json['allocatedAmount']),
      });
    case OfflineTables.cachedCosts:
      base.addAll({
        'planId': _string(json['weddingPlanId']),
        'categoryId': _string(json['budgetCategoryId']),
        'providerId': _string(json['providerId']),
        'title': _string(json['title']),
        'totalAmount': _string(json['totalAmount']),
        'paidAmount': _string(json['paidAmount']),
        'status': _string(json['status']) ?? 'OPEN',
      });
    case OfflineTables.cachedCostPayments:
      base.addAll({
        'planId': _string(json['weddingPlanId']),
        'costId': _string(json['costId']),
        'amount': _string(json['amount']),
        'paidAt': _string(json['paidAt']),
      });
    case OfflineTables.cachedPaymentSchedules:
      base.addAll({
        'planId': _string(json['weddingPlanId']),
        'costId': _string(json['costId']),
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
    case OfflineTables.cachedGovernorates:
      base.addAll({
        'code': _string(json['code']),
        'nameAr': _string(json['nameAr']),
        'name': _string(json['nameEn']),
      });
    case OfflineTables.cachedDistricts:
      base.addAll({
        'governorateId': _string(json['governorateId']),
        'code': _string(json['code']),
        'nameAr': _string(json['nameAr']),
        'name': _string(json['nameEn']),
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

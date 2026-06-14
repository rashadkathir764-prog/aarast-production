import 'dart:convert';

import 'package:aarast_mobile/core/offline/local_mappers.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('task mapper stores searchable columns and raw JSON', () {
    final now = DateTime.utc(2026, 6, 14, 9);
    final row = buildCacheRow(
      table: OfflineTables.cachedTasks,
      json: {
        'id': 'task-1',
        'weddingPlanId': 'plan-1',
        'title': 'Book hall',
        'status': 'TODO',
        'priority': 'HIGH',
        'updatedAt': '2026-06-14T08:00:00.000Z',
      },
      now: now,
    );

    expect(row.table, OfflineTables.cachedTasks);
    expect(row.columns['id'], 'task-1');
    expect(row.columns['planId'], 'plan-1');
    expect(row.columns['title'], 'Book hall');
    expect(row.columns['status'], 'TODO');
    expect(row.columns['priority'], 'HIGH');
    expect(row.columns['dirty'], 0);
    expect(row.columns['deletedLocally'], 0);
    expect(row.columns['updatedAt'], '2026-06-14T08:00:00.000Z');
    expect(row.columns['syncedAt'], now.toIso8601String());
    expect(jsonDecode(row.columns['rawJson'] as String)['id'], 'task-1');
  });

  test('provider mapper stores category, city, status, and raw JSON', () {
    final now = DateTime.utc(2026, 6, 14, 9);
    final row = buildCacheRow(
      table: OfflineTables.cachedProviders,
      json: {
        'id': 'provider-1',
        'businessName': 'Aden Hall',
        'cityId': 'city-1',
        'primaryCategoryId': 'category-1',
        'status': 'ACTIVE',
      },
      now: now,
    );

    expect(row.columns['id'], 'provider-1');
    expect(row.columns['name'], 'Aden Hall');
    expect(row.columns['cityId'], 'city-1');
    expect(row.columns['categoryId'], 'category-1');
    expect(row.columns['status'], 'ACTIVE');
    expect(row.columns['syncedAt'], now.toIso8601String());
  });
}

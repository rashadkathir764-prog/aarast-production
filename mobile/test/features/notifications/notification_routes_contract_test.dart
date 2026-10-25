import 'dart:io';

import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/features/notifications/models/aarast_notification.dart';
import 'package:aarast_mobile/features/notifications/utils/notification_route_policy.dart';
import 'package:flutter_test/flutter_test.dart';

/// B-19: every notice the server can write opens a screen of this app.
///
/// The server's one route table (`backend/src/shared-kernel/routes/
/// notification-routes.ts`) lists, for every notification type of the
/// schema, the route shapes its notices carry. This test reads both and
/// fails if a type has no entry, or if a shape is not opened as written,
/// not allowed by the safety check, or not a route the router registers.
void main() {
  final repository = Directory.current.parent;
  final enumSource = File(
    '${repository.path}/backend/prisma/schema/notifications.prisma',
  ).readAsStringSync();
  final routeSource = File(
    '${repository.path}/backend/src/shared-kernel/routes/notification-routes.ts',
  ).readAsStringSync();

  List<String> notificationTypes() {
    final body = RegExp(
      r'enum NotificationType \{([^}]*)\}',
    ).firstMatch(enumSource)!.group(1)!;
    return [
      for (final line in body.split('\n'))
        if (RegExp(r'^\s*[A-Z_]+\s*$').hasMatch(line)) line.trim(),
    ];
  }

  Map<String, List<String>> routeTable() {
    final table = <String, List<String>>{};
    for (final match in RegExp(
      r'^\s+([A-Z_]+): \[(.*)\],$',
      multiLine: true,
    ).allMatches(routeSource)) {
      table[match.group(1)!] = [
        for (final shape in RegExp(r"'([^']+)'").allMatches(match.group(2)!))
          shape.group(1)!,
      ];
    }
    return table;
  }

  /// A concrete location of a shape: every `:name` an id.
  String sample(String shape) =>
      shape.replaceAllMapped(RegExp(r':([A-Za-z]+)'), (match) {
        // The portal's tab is a word the portal knows, not an id.
        return match.group(1) == 'tab' ? 'profile' : 'id-${match.group(1)}';
      });

  test('every notification type of the schema has an entry in the server route table', () {
    final types = notificationTypes();
    final table = routeTable();
    expect(types, isNotEmpty);
    expect(table.keys.toSet(), types.toSet());
    // Written by no code (the server test proves it): nothing to open.
    expect(
      [
        for (final entry in table.entries)
          if (entry.value.isEmpty) entry.key,
      ]..sort(),
      ['GENERAL', 'PLAN_UPDATED', 'SHARING_UPDATED', 'SYNC_REQUIRED'],
    );
  });

  test('every route a notice carries opens as written, is allowed and is a registered route', () {
    final router = AppRouter.create();
    addTearDown(router.dispose);
    final table = routeTable();
    var checked = 0;
    for (final entry in table.entries) {
      for (final shape in entry.value) {
        final location = sample(shape);
        final notice = AarastNotification(
          id: 'notice-${entry.key}',
          userId: 'user-1',
          type: entry.key,
          title: 'عنوان',
          body: 'سطر',
          routeTarget: location,
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        expect(
          resolveNotificationRouteTarget(notice),
          location,
          reason: '${entry.key}: the phone opens the route as written',
        );
        expect(
          isSafeNotificationRouteTarget(location),
          isTrue,
          reason: '${entry.key}: $location must be an allowed target',
        );
        final match = router.configuration.findMatch(Uri.parse(location));
        expect(
          match.isError,
          isFalse,
          reason: '${entry.key}: $location must be a registered route',
        );
        expect(match.isNotEmpty, isTrue, reason: '${entry.key}: $location');
        checked += 1;
      }
    }
    expect(checked, greaterThanOrEqualTo(30));
  });

  test('a route outside the app stays closed', () {
    expect(isSafeNotificationRouteTarget('https://example.com/x'), isFalse);
    expect(isSafeNotificationRouteTarget('/admin/users'), isFalse);
    expect(isSafeNotificationRouteTarget('/provider/dashboard?tab=../x'), isFalse);
    expect(isSafeNotificationRouteTarget('/provider/reviews/a.b'), isFalse);
    expect(isSafeNotificationRouteTarget('/provider/reviews/r-1?next=/x'), isFalse);
  });
}

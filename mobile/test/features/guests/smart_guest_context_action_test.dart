import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/guests/models/guest.dart';
import 'package:aarast_mobile/features/guests/widgets/guest_list_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pending guest exposes a real reply action at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    String? selectedStatus;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: GuestListRow(
                guest: _pendingGuest,
                groupLabel: 'العائلة',
                isDuplicate: false,
                isBusy: false,
                onEdit: () {},
                onStatus: (status) => selectedStatus = status,
                onDelete: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('تحديث الرد'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('تحديث الرد'));
    await tester.pumpAndSettle();
    expect(find.text('تحديث رد ليلى سالم'), findsOneWidget);

    await tester.tap(find.text('مؤكد'));
    await tester.pumpAndSettle();
    expect(selectedStatus, 'CONFIRMED');
    expect(tester.takeException(), isNull);
  });

  testWidgets('guest overflow menu keeps every action readable at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: GuestListRow(
                guest: _pendingGuest,
                groupLabel: 'العائلة',
                isDuplicate: false,
                isBusy: false,
                onEdit: () {},
                onStatus: (_) {},
                onDelete: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('إجراءات الضيف'));
    await tester.pumpAndSettle();

    expect(find.text('تعديل'), findsOneWidget);
    expect(find.text('حذف'), findsOneWidget);
    expect(find.byType(PopupMenuItem<String>), findsNWidgets(6));
    expect(tester.takeException(), isNull);
  });
}

final _pendingGuest = Guest(
  id: 'guest-1',
  weddingPlanId: 'plan-1',
  name: 'ليلى سالم',
  phone: '+967777123456',
  side: 'BRIDE',
  status: 'PENDING',
  seatsCount: 1,
  createdAt: DateTime(2026, 8, 1),
  updatedAt: DateTime(2026, 8, 1),
);

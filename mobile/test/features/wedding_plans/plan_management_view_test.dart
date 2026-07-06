import 'dart:io';

import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/plan_management_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('plan management is administrative and RTL safe at 320px', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 760);
    addTearDown(tester.view.reset);

    var editCalls = 0;
    var locationCalls = 0;
    var sharingCalls = 0;
    var archiveCalls = 0;
    await tester.pumpWidget(
      _TestApp(
        child: PlanManagementView(
          plan: _completePlan(),
          ownerName: 'رشاد',
          participantCount: 3,
          pendingInvites: 1,
          canManagePlan: true,
          canManageSharing: true,
          isLocalPlan: false,
          onEditBasics: () => editCalls += 1,
          onEditLocation: () => locationCalls += 1,
          onManageSharing: () => sharingCalls += 1,
          onArchive: () => archiveCalls += 1,
        ),
      ),
    );

    expect(find.text('عرس رشاد'), findsWidgets);
    expect(find.text('صنعاء'), findsWidgets);
    expect(find.text('نشطة'), findsWidgets);

    for (final title in [
      'إدارة الخطة',
      'بيانات الخطة',
      'موقع الزفاف',
      'المشاركون والصلاحيات',
      'تفضيلات الخطة',
      'حالة اكتمال البيانات',
      'أمان وإدارة الخطة',
    ]) {
      await tester.scrollUntilVisible(
        find.text(title),
        240,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(title), findsOneWidget);
      if (title == 'المشاركون والصلاحيات') {
        expect(find.text('رشاد'), findsOneWidget);
        expect(find.text('3'), findsOneWidget);
      }
      if (title == 'حالة اكتمال البيانات') {
        expect(find.text('مكتملة'), findsOneWidget);
        expect(find.text('100%'), findsOneWidget);
      }
    }

    final source = File(
      'lib/features/wedding_plans/widgets/plan_management_view.dart',
    ).readAsStringSync();
    for (final forbidden in [
      'أقسام الخطة',
      'الموردون والعروض',
      'ملخص التقدم',
      'نسخ الخطة',
      'تصدير بيانات الخطة',
      'حذف الخطة',
    ]) {
      expect(source, isNot(contains(forbidden)));
    }
    expect(source, isNot(contains("'باقي")));

    await tester.tap(find.byKey(const Key('plan-archive')));
    for (final key in const [
      Key('plan-manage-sharing'),
      Key('plan-edit-location'),
      Key('plan-edit-basics'),
    ]) {
      await tester.scrollUntilVisible(
        find.byKey(key),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(key));
    }

    expect(editCalls, 1);
    expect(locationCalls, 1);
    expect(sharingCalls, 1);
    expect(archiveCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('incomplete administrative data names the missing fields', (
    tester,
  ) async {
    final plan = WeddingPlan(
      id: 'plan-incomplete',
      ownerUserId: 'user-1',
      title: 'خطة جديدة',
      currency: 'YER',
      status: 'PLANNING',
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 2),
    );

    await tester.pumpWidget(
      _TestApp(
        child: PlanManagementView(
          plan: plan,
          ownerName: 'رشاد',
          participantCount: 1,
          pendingInvites: 0,
          canManagePlan: true,
          canManageSharing: true,
          isLocalPlan: false,
          onEditBasics: () {},
          onEditLocation: () {},
          onManageSharing: () {},
          onArchive: () {},
        ),
      ),
    );

    await tester.scrollUntilVisible(
      find.text('حالة اكتمال البيانات'),
      300,
      scrollable: find.byType(Scrollable).first,
    );

    expect(find.text('بيانات ناقصة'), findsOneWidget);
    expect(find.textContaining('تاريخ الزواج'), findsOneWidget);
    expect(find.textContaining('الموقع'), findsOneWidget);
    expect(find.textContaining('الأولويات'), findsWidgets);
  });
}

WeddingPlan _completePlan() {
  return WeddingPlan(
    id: 'plan-1',
    ownerUserId: 'user-1',
    title: 'عرس رشاد',
    city: 'صنعاء',
    location: const {
      'governorate': 'أمانة العاصمة',
      'cityOrDistrict': 'صنعاء',
      'areaOrNeighborhood': 'حدة',
      'street': 'شارع تعز',
      'detailedAddress': 'بجوار القاعة الكبرى',
    },
    weddingDate: DateTime(2026, 8, 31),
    priorities: const ['budget', 'providers'],
    onboardingPath: 'USER',
    persona: 'GROOM',
    estimatedBudget: '1000000',
    currency: 'YER',
    status: 'PLANNING',
    createdAt: DateTime(2026, 7, 1),
    updatedAt: DateTime(2026, 7, 6, 12, 30),
  );
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: AppTheme.light(),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: child),
      ),
    );
  }
}

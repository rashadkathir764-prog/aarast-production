import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// D72 (replaces b01's fixed steps): no steps hold the home. «خطوتك الجاية»
// names one missing basic at a time (budget, mahr, first item, first task,
// first guest), each only while missing; the venue and the like are
// optional suggestions under it, each answered «ما أحتاجها» or «بعدين».

DashboardSummary _summary({
  String? budget,
  int? items,
  int tasks = 0,
  int guests = 0,
  bool isOwner = true,
  List<Map<String, Object?>> essentials = const [],
}) {
  return DashboardSummary.fromJson({
    'planId': 'plan-1',
    'title': 'عرس محمد',
    'city': 'صنعاء',
    'currency': 'YER',
    'status': 'PLANNING',
    'weddingDate': '2027-01-21',
    'daysRemaining': 96,
    'progressPercentage': 0,
    'totalTasks': tasks,
    'completedTasks': 0,
    'overdueTasks': 0,
    'todayTasks': 0,
    'guestCount': guests,
    'confirmedGuests': 0,
    'providerCount': 0,
    'quoteRequestsCount': 0,
    'unreadNotificationsCount': 0,
    'nextBestActions': const [],
    'venueSecured': false,
    'budgetItemsCount': items,
    'essentials': essentials,
    'moneySummary': {'totalBudget': budget},
    'permissions': {
      'isOwner': isOwner,
      'canViewMoney': true,
      'canManageMoney': isOwner,
      'canManageTasks': true,
      'canManageGuests': true,
      'canManageProviders': true,
      'canManagePlan': isOwner,
    },
  });
}

Map<String, Object?> _essential(
  String key, {
  String status = 'MISSING',
  bool hidden = false,
}) => {
  'key': key,
  'status': status,
  'budgetCategoryId': 'item-$key',
  'hidden': hidden,
};

Future<void> _pump(
  WidgetTester tester,
  DashboardSummary summary, {
  DashboardHomeMahr? mahr,
  VoidCallback? onOpenMahr,
  VoidCallback? onOpenGuests,
  VoidCallback? onImportGuests,
  void Function(DashboardEssential item, String choice)? onAnswer,
  ValueChanged<DashboardEssential>? onOpenSuggestion,
  JourneyProfile profile = JourneyProfile.groom,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 1800);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: const TextScaler.linear(1.3)),
        child: child!,
      ),
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: JourneyProfileScope(
          profile: profile,
          child: Scaffold(
            body: AarastDashboardView(
              summary: summary,
              mahr: mahr,
              onOpenMahr: onOpenMahr,
              userName: 'محمد',
              bottomPadding: 24,
              now: DateTime(2026, 10, 17, 9),
              onNotifications: () {},
              onProfile: () {},
              onOpenPlan: () {},
              onOpenMoney: () {},
              onOpenTasks: () {},
              onOpenProviders: () {},
              onOpenGuests: onOpenGuests ?? () {},
              onImportGuests: onImportGuests,
              onOpenSharing: () {},
              onOpenNextStep: () {},
              onOpenImportantItem: (_) {},
              onAnswerSuggestion: onAnswer ?? (_, _) {},
              onOpenSuggestion: onOpenSuggestion,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a new plan is never held behind fixed steps', (tester) async {
    await _pump(
      tester,
      _summary(essentials: [_essential('VENUE'), _essential('PHOTO')]),
    );

    // The old checklist is gone; the home itself is there from day one.
    expect(find.text('ثلاث خطوات وعرسك منظم'), findsNothing);
    expect(find.text('أربع خطوات وعرسك منظم'), findsNothing);
    expect(
      find.byKey(const ValueKey('aarast-dashboard-suggestions')),
      findsOneWidget,
    );
    // One next step: the first missing basic, the budget.
    expect(find.text('حدّد ميزانية تقريبية'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a set budget is not asked again: the first item is next', (
    tester,
  ) async {
    await _pump(tester, _summary(budget: '5000000', items: 0));

    expect(find.text('حدّد ميزانية تقريبية'), findsNothing);
    expect(find.text('أضف أول بند'), findsOneWidget);
  });

  testWidgets('a groom\'s plan without its mahr asks for it after the budget', (
    tester,
  ) async {
    var opened = 0;
    await _pump(
      tester,
      _summary(budget: '5000000', items: 4),
      mahr: const DashboardHomeMahr.notRecorded(MahrHomeSide.pays),
      onOpenMahr: () => opened += 1,
    );

    expect(find.text('اتفقتوا على المهر؟'), findsOneWidget);
    await _tapVisible(tester, find.text('سجّل المهر'));
    expect(opened, 1);
  });

  testWidgets('with items and tasks, the first guest comes from contacts', (
    tester,
  ) async {
    var imported = 0;
    var listed = 0;
    await _pump(
      tester,
      _summary(budget: '5000000', items: 4, tasks: 3),
      onImportGuests: () => imported += 1,
      onOpenGuests: () => listed += 1,
    );

    expect(find.text('أضف أول ضيف'), findsOneWidget);
    await _tapVisible(tester, find.text('اختر من جهات الاتصال'));
    expect(imported, 1);
    expect(listed, 0);
  });

  testWidgets('a suggestion is answered «ما أحتاجها» or «بعدين»', (
    tester,
  ) async {
    final answers = <String>[];
    DashboardEssential? opened;
    await _pump(
      tester,
      _summary(
        budget: '5000000',
        items: 4,
        tasks: 3,
        guests: 10,
        essentials: [_essential('VENUE'), _essential('PHOTO')],
      ),
      onAnswer: (item, choice) => answers.add('${item.key}:$choice'),
      onOpenSuggestion: (item) => opened = item,
    );

    expect(find.text('اقتراحات لعرسك'), findsOneWidget);
    await _tapVisible(
      tester,
      find.byKey(
        const ValueKey('aarast-dashboard-suggestion-VENUE-not-needed'),
      ),
    );
    await _tapVisible(
      tester,
      find.byKey(const ValueKey('aarast-dashboard-suggestion-PHOTO-later')),
    );
    expect(answers, ['VENUE:NOT_NEEDED', 'PHOTO:LATER']);
    // RA-MO-164: each answer is heard with the item it answers.
    expect(find.bySemanticsLabel('ما أحتاج التصوير'), findsOneWidget);
    expect(find.bySemanticsLabel('التصوير بعدين'), findsOneWidget);

    await _tapVisible(tester, find.text('التصوير'));
    expect(opened?.budgetCategoryId, 'item-PHOTO');
  });

  testWidgets('an answered, settled or itemless essential is not suggested', (
    tester,
  ) async {
    await _pump(
      tester,
      _summary(
        budget: '5000000',
        items: 4,
        tasks: 3,
        guests: 10,
        essentials: [
          _essential('VENUE', hidden: true),
          _essential('PHOTO', status: 'BOOKED'),
          _essential('GOLD', status: 'NONE'),
        ],
      ),
    );

    expect(
      find.byKey(const ValueKey('aarast-dashboard-suggestions')),
      findsNothing,
    );
  });

  testWidgets('a participant is never offered the owner\'s suggestions', (
    tester,
  ) async {
    await _pump(
      tester,
      _summary(
        budget: '5000000',
        items: 4,
        isOwner: false,
        essentials: [_essential('VENUE')],
      ),
    );

    expect(
      find.byKey(const ValueKey('aarast-dashboard-suggestions')),
      findsNothing,
    );
  });

  testWidgets('the bride\'s suggestions in her words and her rose', (
    tester,
  ) async {
    await _pump(
      tester,
      _summary(
        budget: '5000000',
        items: 4,
        tasks: 3,
        guests: 10,
        essentials: [_essential('VENUE'), _essential('DRESS')],
      ),
      profile: JourneyProfile.bride,
    );

    expect(find.text('الصالة'), findsOneWidget);
    expect(find.text('الفستان'), findsOneWidget);
    expect(find.text('القاعة'), findsNothing);
    expect(find.text('ما اتفقتِ مع أحد بعد'), findsWidgets);
    final row = tester.widget<JourneyListRow>(
      find.descendant(
        of: find.byKey(const ValueKey('aarast-dashboard-suggestion-VENUE')),
        matching: find.byType(JourneyListRow),
      ),
    );
    expect(row.color, AarastV3Color.rose);
  });
}

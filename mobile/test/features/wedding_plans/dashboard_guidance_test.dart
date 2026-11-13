import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// D72 (replaces b01's fixed steps): no steps hold the home. «خطوتك الجاية»
// names one missing basic at a time, each only while missing; the venue and
// the like are optional suggestions under it, each answered «ما أحتاجها» or
// «بعدين». D78 (RA-MO-147): the chain is the server's; the phone walks its
// own (budget, first agreement, guests) only for a plan kept on the phone.

DashboardSummary _summary({
  String? budget,
  int? items,
  int tasks = 0,
  int guests = 0,
  bool isOwner = true,
  List<Map<String, Object?>> essentials = const [],

  /// A plan kept on the phone, and what its agreements come to.
  bool onPhone = false,
  String? agreed,
  List<Map<String, Object?>> steps = const [],
}) {
  return DashboardSummary.fromJson({
    if (onPhone) ...{'accountBacked': false, 'dataScope': 'LOCAL'},
    'confirmedCostTotal': ?agreed,
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
    'nextBestActions': steps,
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

/// One of the server's next steps, as the summary sends it (D78).
Map<String, Object?> _step(
  String type,
  String title,
  String action, {
  String? route,
}) => {
  'id': 'step-$type',
  'type': type,
  'title': title,
  'subtitle': 'من الخادم',
  'actionLabel': action,
  'priority': 'NORMAL',
  'routeTarget': ?route,
};

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
  ValueChanged<DashboardImportantItem>? onOpenItem,
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
              onOpenImportantItem: onOpenItem ?? (_) {},
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
      _summary(
        essentials: [_essential('VENUE'), _essential('PHOTO')],
        steps: [_step('SET_BUDGET', 'حدد ميزانية الخطة', 'حدد الميزانية')],
      ),
    );

    // The old checklist is gone; the home itself is there from day one.
    expect(find.text('ثلاث خطوات وعرسك منظم'), findsNothing);
    expect(find.text('أربع خطوات وعرسك منظم'), findsNothing);
    expect(
      find.byKey(const ValueKey('aarast-dashboard-suggestions')),
      findsOneWidget,
    );
    // One next step: the server's first, the budget.
    expect(find.text('حدد ميزانية الخطة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // RA-MO-147: the server had sent nothing, and the phone still asked
  // «أضف أول بند», a step of its own the server never set.
  testWidgets('an account plan is asked no step the server did not send', (
    tester,
  ) async {
    await _pump(tester, _summary(items: 0));

    expect(find.text('حدّد ميزانية تقريبية'), findsNothing);
    expect(find.text('أضف أول بند'), findsNothing);
    expect(find.text('أضف أول مهمة'), findsNothing);
    expect(find.text('ما فيه شي مستعجل'), findsOneWidget);
  });

  testWidgets('a phone plan with its budget asks for the first agreement', (
    tester,
  ) async {
    await _pump(tester, _summary(budget: '5000000', onPhone: true));

    expect(find.text('حدّد ميزانية تقريبية'), findsNothing);
    expect(find.text('سجّل أول اتفاق'), findsOneWidget);
  });

  testWidgets('the server\'s mahr step opens where the server sends it', (
    tester,
  ) async {
    final opened = <String>[];
    await _pump(
      tester,
      _summary(
        budget: '5000000',
        steps: [
          _step(
            'RECORD_MAHR',
            'اتفقتوا على المهر؟',
            'سجّل المهر',
            route: '/wedding-plans/plan-1/money/mahr',
          ),
        ],
      ),
      mahr: const DashboardHomeMahr.notRecorded(MahrHomeSide.pays),
      onOpenItem: (item) => opened.add(item.routeTarget!),
    );

    expect(find.text('اتفقتوا على المهر؟'), findsOneWidget);
    await _tapVisible(tester, find.text('سجّل المهر'));
    expect(opened, ['/wedding-plans/plan-1/money/mahr']);
  });

  testWidgets('a phone plan\'s first guest comes from contacts', (
    tester,
  ) async {
    var imported = 0;
    var listed = 0;
    await _pump(
      tester,
      _summary(budget: '5000000', onPhone: true, agreed: '400000'),
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

// Captures today's real home / notifications / assistant screens for the
// groom before/after review.
//   flutter test test/prototype/now_home/now_home_test.dart --update-goldens
@Tags(['golden'])
library;

import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart'
    show JourneyCelebrationSky, JourneyProfile, JourneyProfileScope;
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_status_widgets.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/sync_status.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/utils/app_clock.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/home/screens/dashboard_entry_screen.dart';
import 'package:aarast_mobile/features/notifications/data/notifications_api.dart';
import 'package:aarast_mobile/features/notifications/models/aarast_notification.dart';
import 'package:aarast_mobile/features/notifications/providers/notifications_provider.dart';
import 'package:aarast_mobile/features/notifications/screens/notifications_screen.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/shell/widgets/plan_shell_chrome.dart';
import 'package:aarast_mobile/features/wedding_day/data/plan_events_api.dart';
import 'package:aarast_mobile/features/wedding_day/models/plan_event.dart';
import 'package:aarast_mobile/features/wedding_day/providers/plan_events_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/data/plan_assistant_api.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/models/plan_assistant.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/plan_assistant_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/wedding_week_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/dashboard/aarast_dashboard_view.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/plan_assistant_entry.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/preview_fonts.dart';
import '../../support/app_text_scale.dart';

const _planId = 'plan-mohammed-salma';
final _wedding = DateTime(2027, 1, 21, 16);

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget home, {
  double h = 844,
  double w = 390,
  double textScale = 1,
  List<SingleChildWidget> providers = const [],
  Future<void> Function()? act,
}) async {
  tester.view.physicalSize = Size(w * 2, h * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  if (textScale != 1) {
    tester.platformDispatcher.textScaleFactorTestValue = appTextScaler(
      textScale,
    ).scale(1);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final app = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light(),
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    // Keep the real view size: a bare MediaQueryData has size zero, which
    // collapses widths that read MediaQuery.sizeOf.
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: true),
      child: child!,
    ),
    home: home,
  );
  await tester.pumpWidget(
    providers.isEmpty ? app : MultiProvider(providers: providers, child: app),
  );
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (act != null) await act();
  await tester.pump(const Duration(seconds: 1));
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('out/$name.png'),
  );
}

Map<String, dynamic> _base({
  required int? days,
  DateTime? date,
  int progress = 0,
  int totalTasks = 20,
  int completed = 0,
  int overdue = 0,
  int today = 0,
  int guests = 0,
  int confirmed = 0,
  int pending = 0,
  int providers = 0,
  int quotes = 0,
  int received = 0,
  String? budget = '8000000',
  String confirmedCost = '0',
  String paid = '0',
  String outstanding = '0',
  List<Map<String, dynamic>> actions = const [],
  Map<String, dynamic>? nextSchedule,
  int unread = 0,
}) {
  return {
    'planId': _planId,
    'title': 'عرس محمد',
    'currency': 'YER',
    'weddingDate': date?.toIso8601String(),
    'city': 'صنعاء',
    'location': {'fullLabel': 'أمانة العاصمة · صنعاء'},
    'status': 'PLANNING',
    'daysRemaining': days,
    'progressPercentage': progress,
    'budgetTotal': budget,
    'confirmedCostTotal': confirmedCost,
    'paidTotal': paid,
    'outstandingTotal': outstanding,
    'moneySummary': {
      'totalBudget': budget,
      'confirmedCost': confirmedCost,
      'paid': paid,
      'outstanding': outstanding,
      'remainingBudget': budget == null
          ? null
          : '${int.parse(budget) - int.parse(confirmedCost)}',
      'overBudget': false,
    },
    'totalTasks': totalTasks,
    'completedTasks': completed,
    'overdueTasks': overdue,
    'todayTasks': today,
    'guestCount': guests,
    'confirmedGuests': confirmed,
    'pendingGuests': pending,
    'providerCount': providers,
    'acceptedProvidersCount': providers,
    'quoteRequestsCount': quotes,
    'receivedQuotes': received,
    'participantCount': 1,
    'unreadNotificationsCount': unread,
    'nextBestActions': actions,
    'planProviders': const [],
    'importantNotifications': const [],
    'nextPaymentScheduleDue': nextSchedule,
    'permissions': {
      'isOwner': true,
      'canViewMoney': true,
      'canManageTasks': true,
      'canManageGuests': true,
      'canManageProviders': true,
      'canManageMembers': true,
      'canManageMoney': true,
      'canManagePlan': true,
    },
  };
}

/// D78 (RA-MO-147): what the server sends a new plan with its budget set, in
/// its order; the home draws these and orders nothing of its own.
const _freshSteps = [
  {
    'id': 'setup:ADD_FIRST_COST',
    'type': 'ADD_FIRST_COST',
    'title': 'سجّل أول اتفاق',
    'subtitle': 'القاعة أو الذهب أو الكسوة: أول رقم يخلي الباقي يبان',
    'icon': 'wallet',
    'tone': 'info',
    'priority': 'NORMAL',
    'actionLabel': 'أضف اتفاق',
    'routeTarget': '/wedding-plans/$_planId/money/costs/create',
  },
  {
    'id': 'setup:ADD_GUESTS',
    'type': 'ADD_GUESTS',
    'title': 'ابدأ قائمة الضيوف',
    'subtitle': 'العدد يحدد حجم القاعة وتكلفة الضيافة',
    'icon': 'people',
    'tone': 'info',
    'priority': 'NORMAL',
    'actionLabel': 'أضف أول ضيف',
    'routeTarget': '/wedding-plans/$_planId/guests/add',
  },
  {
    'id': 'setup:REQUEST_QUOTE',
    'type': 'REQUEST_QUOTE',
    'title': 'اطلب أول عرض سعر',
    'subtitle': 'الليالي تنحجز بدري، والعرض يعطيك سعر حقيقي بدل التخمين',
    'icon': 'provider',
    'tone': 'info',
    'priority': 'NORMAL',
    'actionLabel': 'شوف المزودين',
    'routeTarget': '/wedding-plans/$_planId/providers',
  },
];

final _fresh = DashboardSummary.fromJson(
  _base(days: 93, date: _wedding, progress: 0, actions: _freshSteps),
);

final _active = DashboardSummary.fromJson(
  _base(
    days: 93,
    date: _wedding,
    progress: 40,
    completed: 8,
    overdue: 1,
    guests: 124,
    confirmed: 86,
    pending: 20,
    providers: 3,
    quotes: 4,
    received: 2,
    confirmedCost: '5400000',
    paid: '2400000',
    outstanding: '3000000',
    unread: 3,
    actions: [
      {
        'id': 'a1',
        'type': 'PAYMENT_SCHEDULE_DUE_SOON',
        // The server's title is the cost's; the card adds the amount.
        'title': 'دفعة القاعة',
        'subtitle': 'قاعة سبأ · تستحق بعد 5 أيام',
        'icon': 'wallet',
        'tone': 'warning',
        'priority': 'HIGH',
        'actionLabel': 'سجّل الدفعة',
        'amount': '500000',
        'dueDate': DateTime(2026, 10, 25).toIso8601String(),
      },
    ],
    nextSchedule: {
      'id': 's1',
      'weddingCostId': 'c1',
      'title': 'القاعة',
      'amount': '500000',
      'status': 'PENDING',
      'dueDate': DateTime(2026, 10, 25).toIso8601String(),
    },
  ),
);

/// D114, the owner's own plan (2026-11-14): budget 7 million, mahr 2
/// million with 500 thousand handed over, nothing else agreed; the budget
/// holds the mahr when [inside].
DashboardSummary _ownerPlan({required bool inside}) {
  final json = _base(
    days: 93,
    date: _wedding,
    progress: 10,
    budget: '7000000',
    confirmedCost: '2000000',
    paid: '500000',
    outstanding: '1500000',
  );
  return DashboardSummary.fromJson({
    ...json,
    'budgetIncludesMahr': inside,
    'moneySummary': {
      ...json['moneySummary'] as Map<String, dynamic>,
      'paidByOwner': '500000',
      'paidByOthers': '0',
      'remainingBudget': inside ? '5000000' : '7000000',
    },
  });
}

const _ownerMahr = DashboardHomeMahr(
  side: MahrHomeSide.pays,
  recorded: true,
  total: 2000000,
  settled: 500000,
);

const _ownerFunding = DashboardHomeFunding(
  inHand: 0,
  pledged: 0,
  shortfall: null,
  sourcesCount: 0,
  ownerLeft: 1500000,
);

DashboardSummary _stage(int days, DateTime? date) => DashboardSummary.fromJson(
  _base(
    days: days,
    date: date,
    progress: 85,
    completed: 17,
    guests: 124,
    confirmed: 110,
    pending: 6,
    providers: 5,
    quotes: 6,
    received: 5,
    confirmedCost: '7600000',
    paid: '6200000',
    outstanding: '1400000',
  ),
);

class _FakeAssistantApi extends PlanAssistantApi {
  _FakeAssistantApi({this.status_})
    : super(ApiClient(tokenProvider: () async => null));

  final PlanAssistantStatus? status_;

  @override
  Future<PlanAssistantStatus> status(String weddingPlanId) async =>
      status_ ??
      const PlanAssistantStatus(
        enabled: true,
        allowed: true,
        dailyLimit: 10,
        remainingToday: 10,
      );

  @override
  Future<PlanAssistantAnswer> ask(
    String weddingPlanId, {
    required PlanAssistantKind kind,
    String? question,
  }) async {
    return const PlanAssistantAnswer(
      answerId: 'answer-1',
      answer:
          'من خطتك: ميزانيتك 8,000,000 ر.ي، اتفقت على 5,400,000 ودفعت منها '
          '2,400,000. أكبر بند باقي هو القاعة (دفعتان).\n\n'
          '1. ثبّت عدد الضيوف قبل الدفعة الثانية للقاعة، فالسعر بالرأس.\n'
          '2. التصوير: وصلك عرضين، قارن بينهم قبل ما ينتهوا.\n'
          '3. أجّل الكماليات (الزينة الإضافية) لآخر شهر.',
      declined: false,
      marketDataAvailable: false,
      remainingToday: 9,
    );
  }
}

class _FakeNotificationsApi extends NotificationsApi {
  _FakeNotificationsApi(this._items)
    : super(ApiClient(tokenProvider: () async => null));
  final List<AarastNotification> _items;

  @override
  Future<NotificationsPage> getNotifications({
    String? weddingPlanId,
    int page = 1,
    int limit = 20,
  }) async => NotificationsPage(
    items: _items,
    page: page,
    limit: limit,
    total: _items.length,
    totalPages: _items.isEmpty ? 0 : 1,
    hasMore: false,
  );

  @override
  Future<int> getUnreadCount({String? weddingPlanId}) async =>
      _items.where((item) => item.isUnread).length;
}

AarastNotification _n(
  String id,
  String type,
  String title,
  String body, {
  required int hoursAgo,
  bool unread = false,
  String priority = 'NORMAL',
}) {
  // A fixed past moment: the feed groups and words times against the real
  // clock («اليوم», weekday names), so only an old date keeps the shot the
  // same on every day it runs.
  final at = DateTime(2026, 9, 20, 18).subtract(Duration(hours: hoursAgo));
  return AarastNotification(
    id: id,
    userId: 'user-1',
    weddingPlanId: _planId,
    type: type,
    title: title,
    body: body,
    priority: priority,
    createdAt: at,
    updatedAt: at,
    readAt: unread ? null : at,
  );
}

class _FakeSync extends OfflineSyncService {
  _FakeSync(LocalDatabase db, this._s, this._pending, this._blocked)
    : super(
        database: db,
        apiClient: ApiClient(tokenProvider: () async => null),
      );
  final SyncState _s;
  final int _pending;
  final int _blocked;
  @override
  SyncState get state => _s;
  @override
  int get pendingCount => _pending;
  @override
  int get blockedCount => _blocked;
  @override
  int get unsyncedCount => _pending + _blocked;
  @override
  DateTime? get lastSyncedAt => DateTime(2026, 10, 20, 9, 40);
}

/// The plan's events as the server sends them, for «أسبوع العرس».
class _WeekEventsApi extends PlanEventsApi {
  _WeekEventsApi(this.view) : super(ApiClient(tokenProvider: () async => null));

  final PlanEventsView view;

  @override
  Future<PlanEventsView> list(String weddingPlanId) async => view;
}

void main() {
  setUpAll(loadPreviewAppFonts);

  Widget shell(Widget body, {Widget? top, String? stage}) => PlanShellChrome(
    body: body,
    activeIndex: 0,
    onTabSelected: (_) {},
    topStatus: top,
  );

  Widget dash(
    DashboardSummary s,
    DateTime now, {
    Widget? assistant,
    PlanEventsView? events,
    DashboardHomeFunding? funding,
    DashboardHomeMahr? mahr,
    DashboardAfterWedding? afterWedding,
    VoidCallback? onOpenReviews,
  }) => AarastDashboardView(
    summary: s,
    userName: 'محمد',
    bottomPadding: 158,
    now: now,
    funding: funding,
    mahr: mahr,
    afterWedding: afterWedding,
    onOpenReviews: onOpenReviews,
    assistantEntry: assistant,
    events: events,
    onOpenEvents: () {},
    // D134: the wedding week's card, under the next step.
    onOpenWeek: () {},
    onNotifications: () {},
    onProfile: () {},
    onOpenPlan: () {},
    onOpenMoney: () {},
    onOpenTasks: () {},
    onOpenProviders: () {},
    onOpenGuests: () {},
    onOpenSharing: () {},
    onOpenNextStep: () {},
    onOpenImportantItem: (_) {},
  );

  // b04 and b05's events (D65): السمرة, المقيل and the wedding, with the
  // day's lunch and dinner (C8).
  final weekEvents = PlanEventsView(
    weddingPlanId: _planId,
    canEdit: true,
    suggestions: const [],
    items: [
      PlanEvent(
        id: 'e1',
        type: PlanEventType.samra,
        date: DateTime(2027, 1, 19),
        slot: PlanEventSlot.afterIsha,
        placeLabel: 'الديوان',
      ),
      PlanEvent(
        id: 'e2',
        type: PlanEventType.maqeel,
        date: DateTime(2027, 1, 20),
        slot: PlanEventSlot.afterDhuhr,
        placeLabel: 'بيت الوالد',
        note: 'القات عند صالح',
      ),
      PlanEvent(
        id: 'e3',
        type: PlanEventType.lunch,
        date: DateTime(2027, 1, 21),
        slot: PlanEventSlot.dhuhr,
        placeLabel: 'بيت الوالد',
        responsibleName: 'أبو علي',
      ),
      PlanEvent(
        id: 'e4',
        type: PlanEventType.wedding,
        date: DateTime(2027, 1, 21),
        slot: PlanEventSlot.afterAsr,
        placeLabel: 'قاعة سبأ',
      ),
      PlanEvent(
        id: 'e5',
        type: PlanEventType.dinner,
        date: DateTime(2027, 1, 21),
        slot: PlanEventSlot.afterIsha,
        placeLabel: 'قاعة سبأ',
        responsibleName: 'ضيافة الأصالة',
      ),
    ],
  );

  final now = DateTime(2026, 10, 20, 10);

  testWidgets('home fresh', (tester) async {
    await _shot(
      tester,
      'home_fresh',
      shell(dash(_fresh, now), stage: 'التخطيط'),
      h: 1000,
    );
  });

  testWidgets('home active', (tester) async {
    await _shot(
      tester,
      'home_active',
      shell(
        dash(
          _active,
          now,
          events: weekEvents,
          assistant: PlanAssistantEntry(
            weddingPlanId: _planId,
            api: _FakeAssistantApi(),
          ),
        ),
        stage: 'التخطيط',
      ),
      h: 1000,
    );
  });

  // The money card once the money in is known: the verdict chip, what is in
  // hand and promised, and under them the one bar and the one row (D113).
  testWidgets('home funding', (tester) async {
    await _shot(
      tester,
      'home_funding',
      shell(
        dash(
          _active,
          now,
          funding: const DashboardHomeFunding(
            inHand: 2900000,
            pledged: 250000,
            shortfall: null,
            sourcesCount: 2,
            ownerLeft: 3350000,
            // D113: the money tab's verdict as the home's short tag.
            verdict: (ok: true, conditional: false, words: 'تكفي'),
          ),
        ),
        stage: 'التخطيط',
      ),
      h: 1000,
    );
  });

  // D114: the owner's plan in both modes, and the inside mode on a 320
  // phone at text scale 1.3.
  for (final (name, inside, w, scale) in [
    ('home_mahr_inside', true, 390.0, 1.0),
    ('home_mahr_outside', false, 390.0, 1.0),
    ('home_mahr_inside_320_13', true, 320.0, 1.3),
  ]) {
    testWidgets(name, (tester) async {
      await _shot(
        tester,
        name,
        shell(
          dash(
            _ownerPlan(inside: inside),
            now,
            funding: _ownerFunding,
            mahr: _ownerMahr,
          ),
          stage: 'التخطيط',
        ),
        h: scale == 1 ? 1000 : 1300,
        w: w,
        textScale: scale,
      );
    });
  }

  testWidgets('home no date', (tester) async {
    final s = DashboardSummary.fromJson(
      _base(days: null, date: null, actions: _freshSteps),
    );
    await _shot(
      tester,
      'home_no_date',
      shell(dash(s, now), stage: 'البداية'),
      h: 1000,
    );
  });

  testWidgets('home week', (tester) async {
    await _shot(
      tester,
      'home_week',
      shell(
        dash(
          _stage(2, _wedding),
          DateTime(2027, 1, 19, 10),
          events: weekEvents,
        ),
        stage: 'الأسبوع الأخير',
      ),
      h: 1000,
    );
    // RA-MO-24: the hero says how many days are left («يومين على عرسك»);
    // the greeting above it does not say it again.
    expect(find.textContaining('يومين'), findsOneWidget);
    expect(find.text('أهلًا محمد'), findsOneWidget);
  });

  testWidgets('home day', (tester) async {
    await _shot(
      tester,
      'home_day',
      shell(
        dash(
          _stage(0, _wedding),
          DateTime(2027, 1, 21, 16),
          events: weekEvents,
        ),
        stage: 'اليوم الكبير',
      ),
      h: 1000,
    );
  });

  // D134 on the bride's plan (Rashad, 2026-11-27: everything done on the
  // groom's path holds on hers): the same card under her next step, in her
  // colour and her words.
  testWidgets('bride home with the week card', (tester) async {
    await _shot(
      tester,
      'bride_home_week_card',
      JourneyProfileScope(
        profile: JourneyProfile.bride,
        child: shell(dash(_active, now, events: weekEvents)),
      ),
      h: 1000,
    );
    expect(
      find.byKey(const ValueKey('aarast-dashboard-week-card')),
      findsOneWidget,
    );
  });

  // D134: «أسبوع العرس», the page the home's card opens: before the week
  // opens, inside it, and on the day; and inside it on the bride's plan.
  for (final (name, clock, profile) in [
    ('week_page_before', DateTime(2026, 10, 20, 10), JourneyProfile.groom),
    ('week_page', DateTime(2027, 1, 19, 10), JourneyProfile.groom),
    ('week_page_day', DateTime(2027, 1, 21, 16), JourneyProfile.groom),
    ('bride_week_page', DateTime(2027, 1, 19, 10), JourneyProfile.bride),
  ]) {
    testWidgets(name, (tester) async {
      pinAppClock(clock);
      addTearDown(() => pinAppClock(DateTime(2026, 10, 26, 12)));
      await _shot(
        tester,
        name,
        JourneyProfileScope(
          profile: profile,
          child: const WeddingWeekScreen(weddingPlanId: _planId),
        ),
        h: 1000,
        // The hero's photo is the app's real asset: it is decoded here, or
        // the picture would show the plan's colour alone.
        act: () async {
          await tester.runAsync(
            () => precacheImage(
              const AssetImage(JourneyCelebrationSky.asset),
              tester.element(find.byType(WeddingWeekScreen)),
            ),
          );
          await tester.pump(const Duration(milliseconds: 600));
        },
        providers: [
          Provider<ApiClient>.value(
            value: ApiClient(tokenProvider: () async => null),
          ),
          ChangeNotifierProvider<PlanEventsProvider>(
            create: (_) => PlanEventsProvider(api: _WeekEventsApi(weekEvents)),
          ),
        ],
      );
    });
  }

  testWidgets('home after', (tester) async {
    await _shot(
      tester,
      'home_after',
      shell(
        dash(_stage(-20, _wedding), DateTime(2027, 2, 10, 10)),
        stage: 'ما بعد العرس',
      ),
      h: 1000,
    );
  });

  // b07 as the app shows it once the money is read: what is still owed and
  // the providers to rate, then the same home with everything paid
  // (RA-MO-132). `home_after` above is the rarer moment before the money
  // arrives.
  testWidgets('home after the wedding, owing and settled', (tester) async {
    await _shot(
      tester,
      'home_after_owing',
      shell(
        dash(
          _stage(-20, _wedding),
          DateTime(2027, 2, 10, 10),
          afterWedding: const DashboardAfterWedding(
            left: 1900000,
            paid: 2300000,
            total: 4200000,
          ),
          onOpenReviews: () {},
        ),
      ),
      h: 1000,
    );
    await _shot(
      tester,
      'home_after_settled',
      shell(
        dash(
          _stage(-20, _wedding),
          DateTime(2027, 2, 10, 10),
          afterWedding: const DashboardAfterWedding(
            left: 0,
            paid: 4200000,
            total: 4200000,
          ),
          onOpenReviews: () {},
        ),
      ),
      h: 1000,
    );
  });

  testWidgets('home loading', (tester) async {
    await _shot(
      tester,
      'home_loading',
      shell(const AarastDashboardSkeleton(bottomPadding: 158)),
    );
  });

  testWidgets('home error', (tester) async {
    await _shot(
      tester,
      'home_error',
      shell(
        AarastDashboardState(
          bottomPadding: 158,
          icon: LucideIcons.cloudOff,
          // The screen's own words and colour (wedding_plan_dashboard_screen
          // `aarast-home-error`); this shot used to draw a red state with
          // words the app never shows (RA-TS-16).
          title: 'ما قدرنا نجيب خطتك',
          message: aarastBackendConnectionErrorMessage,
          actionLabel: 'جرّب مرة ثانية',
          onAction: () {},
        ),
      ),
    );
  });

  // RA-TS-19: w41's sheet used to be handed three made-up rows, one of them
  // a guest (a label the queue never writes: «التغيير المحلي») and a payment
  // titled «دفعة:» (the queue's word is «الدفعة»). The rows now come out of
  // the real queue through the real `loadPendingChanges`, so the picture
  // shows only what a phone can hold: a task and a payment waiting for the
  // network, and a task the server refused.
  Future<List<SingleChildWidget>> syncProviders(
    SyncState s,
    int pending,
    int blocked,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final database = JsonLocalDatabase(prefs);
    await database.initialize();
    final hourAgo = appNow().subtract(const Duration(hours: 2, minutes: 1));
    final queue = <(String, String, String, Map<String, dynamic>, bool)>[
      ('task', 'tasks/task-1', 'task-1', {'title': 'حجز المصور'}, blocked > 0),
      ('task', 'tasks/task-2', 'task-2', {'title': 'تجهيز الدعوات'}, false),
      (
        'cost_payment',
        'costs/cost-1/payments',
        'payment-1',
        {'name': 'قاعة ليالي صنعاء'},
        false,
      ),
    ];
    for (final (type, endpoint, localId, payload, refused) in queue.take(
      pending + blocked,
    )) {
      final item = await database.enqueueSync(
        entityType: type,
        operation: 'create',
        endpoint: '/api/v1/$endpoint',
        method: 'POST',
        payload: payload,
        planId: 'plan-1',
        localEntityId: localId,
        queueCreatedAt: hourAgo,
      );
      if (refused) {
        await database.markSyncItemBlocked(
          item.id,
          'validation failed',
          code: 'VALIDATION',
        );
      }
    }
    expect(await database.blockedSyncItems(), hasLength(blocked));
    expect(await database.pendingSyncItems(), hasLength(pending));
    final sync = _FakeSync(database, s, pending, blocked);
    return [ChangeNotifierProvider<OfflineSyncService>.value(value: sync)];
  }

  testWidgets('home offline pending', (tester) async {
    await _shot(
      tester,
      'home_offline',
      shell(dash(_active, now), top: const OfflineStatusBanner()),
      providers: await syncProviders(SyncState.offline, 3, 0),
      h: 1000,
    );
  });

  testWidgets('home sync blocked sheet', (tester) async {
    await _shot(
      tester,
      'home_sync_blocked',
      shell(dash(_active, now), top: const OfflineStatusBanner()),
      providers: await syncProviders(SyncState.syncError, 2, 1),
      act: () async {
        await tester.tap(find.byTooltip('شوف التغييرات اللي تنتظر'));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
        // The rows are the queue's own words (RA-TS-19): money and tasks.
        expect(find.textContaining('مهمة: حجز المصور'), findsOneWidget);
        expect(find.textContaining('مهمة: تجهيز الدعوات'), findsOneWidget);
        expect(find.textContaining('الدفعة: قاعة ليالي صنعاء'), findsOneWidget);
        expect(find.textContaining('ضيف'), findsNothing);
      },
    );
  });

  Future<List<SingleChildWidget>> notifProviders(
    List<AarastNotification> items,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = AuthStorage(prefs);
    await storage.saveSession(
      accessToken: 'token',
      user: const SafeUser(
        id: 'user-1',
        name: 'محمد',
        role: 'USER',
        status: 'ACTIVE',
      ),
    );
    return [
      Provider<AuthStorage>.value(value: storage),
      ChangeNotifierProvider<NotificationsProvider>(
        create: (_) => NotificationsProvider(_FakeNotificationsApi(items)),
      ),
    ];
  }

  testWidgets('notifications feed', (tester) async {
    await _shot(
      tester,
      'notifications',
      const NotificationsScreen(),
      providers: await notifProviders([
        _n(
          'n1',
          'QUOTE_OFFER_RECEIVED',
          'وصلك عرض سعر',
          'استوديو ضوء صنعاء أرسل عرض سعر للتصوير.',
          hoursAgo: 1,
          unread: true,
          priority: 'HIGH',
        ),
        _n(
          'n2',
          'PAYMENT_SCHEDULE_DUE_SOON',
          'موعد دفع قريب',
          'دفعة القاعة 500,000 ر.ي تستحق قريباً.',
          hoursAgo: 3,
          unread: true,
        ),
        _n(
          'n3',
          'TASK_OVERDUE',
          'مهمة متأخرة',
          'حجز القاعة - تجاوزت موعدها.',
          hoursAgo: 5,
        ),
        _n(
          'n4',
          'BOOKING_UPDATED',
          'تحديث على حجز',
          'قاعة سبأ أكدت الحجز.',
          hoursAgo: 30,
        ),
        _n(
          'n5',
          'GUEST_RESPONDED',
          'رد ضيف',
          'عبدالله الحمدي أكد حضوره.',
          hoursAgo: 50,
        ),
        _n(
          'n6',
          'WEDDING_COUNTDOWN',
          'العد التنازلي للعرس',
          'باقي 93 يوم على العرس.',
          hoursAgo: 72,
        ),
      ]),
      h: 1200,
    );
  });

  testWidgets('notifications empty', (tester) async {
    await _shot(
      tester,
      'notifications_empty',
      const NotificationsScreen(),
      providers: await notifProviders(const []),
    );
  });

  Widget assistant(PlanAssistantApi api) =>
      PlanAssistantScreen(weddingPlanId: _planId, api: api);

  testWidgets('assistant start', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _shot(tester, 'assistant', assistant(_FakeAssistantApi()), h: 1000);
  });

  testWidgets('assistant consent', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _shot(
      tester,
      'assistant_consent',
      assistant(_FakeAssistantApi()),
      act: () async {
        await tester.tap(find.text(PlanAssistantKind.cheaper.label));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });

  testWidgets('assistant answer', (tester) async {
    SharedPreferences.setMockInitialValues({});
    // The question's bubble carries the time it was asked, read from
    // appNow, which this folder pins (flutter_test_config.dart).
    await _shot(
      tester,
      'assistant_answer',
      // RA-BE-161: the consent is the server's record.
      assistant(
        _FakeAssistantApi(
          status_: PlanAssistantStatus(
            enabled: true,
            allowed: true,
            dailyLimit: 10,
            remainingToday: 10,
            consentedAt: DateTime.utc(2026, 11, 20),
          ),
        ),
      ),
      h: 1300,
      act: () async {
        await tester.tap(find.text(PlanAssistantKind.cheaper.label));
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump(const Duration(milliseconds: 500));
      },
    );
  });

  testWidgets('assistant limit', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _shot(
      tester,
      'assistant_limit',
      assistant(
        _FakeAssistantApi(
          status_: const PlanAssistantStatus(
            enabled: true,
            allowed: true,
            dailyLimit: 10,
            remainingToday: 0,
          ),
        ),
      ),
    );
  });

  testWidgets('assistant off', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await _shot(
      tester,
      'assistant_off',
      assistant(
        _FakeAssistantApi(
          status_: const PlanAssistantStatus(
            enabled: false,
            allowed: true,
            dailyLimit: 10,
            remainingToday: 10,
          ),
        ),
      ),
    );
  });

  testWidgets('device plan dashboard', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final authStorage = AuthStorage(prefs);
    final guest = GuestOnboardingStorage(prefs);
    final client = ApiClient(tokenProvider: authStorage.readAccessToken);
    final plansApi = WeddingPlansApi(client);
    final auth = AuthController(
      AuthRepository(client, authStorage),
      guestOnboardingStorage: guest,
    );
    await guest.saveDraft(
      GuestOnboardingDraft(
        guestPlanId: 'guest-plan-mohammed',
        planName: 'عرس محمد',
        createdAt: DateTime(2026, 10, 18),
        isGuestPlan: true,
        needsSync: true,
        selectedPath: GuestOnboardingPath.weddingUser,
        persona: GuestPersona.groom,
        governorate: 'أمانة العاصمة',
        city: 'صنعاء',
        district: 'السبعين',
        neighborhood: 'حدة',
        street: null,
        addressNote: null,
        // No date: the countdown reads the real clock, so a date would change
        // the shot every day.
        weddingDate: null,
        weddingDateUnknown: true,
        priorities: const ['budget', 'tasks'],
        currency: 'YER',
        estimatedBudget: '8000000',
        selectedCategoryKeys: const ['hall', 'photo'],
      ),
    );
    await auth.restoreSession();
    await _shot(
      tester,
      'device_plan',
      const DashboardEntryScreen(),
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        Provider<GuestOnboardingStorage>.value(value: guest),
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider<WeddingPlansProvider>(
          create: (_) => WeddingPlansProvider(plansApi),
        ),
        ChangeNotifierProvider<DashboardSummaryProvider>(
          create: (_) => DashboardSummaryProvider(weddingPlansApi: plansApi),
        ),
      ],
      h: 1060,
    );
  });
}

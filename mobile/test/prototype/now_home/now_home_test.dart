// Captures today's real home / notifications / assistant screens for the
// groom before/after review.
//   flutter test test/prototype/now_home/now_home_test.dart --update-goldens
@Tags(['golden'])
library;

import 'dart:typed_data';

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
import 'package:aarast_mobile/features/wedding_day/models/plan_event.dart';
import 'package:aarast_mobile/features/wedding_plans/data/plan_assistant_api.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/models/plan_assistant.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/dashboard_summary_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/screens/plan_assistant_screen.dart';
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

const _planId = 'plan-mohammed-salma';
final _wedding = DateTime(2027, 1, 21, 16);

Future<void> _shot(
  WidgetTester tester,
  String name,
  Widget home, {
  double h = 844,
  List<SingleChildWidget> providers = const [],
  Future<void> Function()? act,
}) async {
  tester.view.physicalSize = Size(390 * 2, h * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
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

final _fresh = DashboardSummary.fromJson(
  _base(days: 93, date: _wedding, progress: 0),
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

/// The usual golden comparison, but a diff of at most [tolerance] (a
/// fraction of the pixels) still passes.
class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile, this.tolerance);

  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= tolerance) return true;
    final error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
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

  /// w41: the sheet lists every change still on the phone, the refused one
  /// with its reason, the rest waiting for the network.
  @override
  Future<List<PendingChangeSummary>> loadPendingChanges() async => [
    PendingChangeSummary(
      id: 'change-1',
      entityType: 'guest',
      title: 'ضيف: عبدالله الحمدي',
      createdAt: appNow().subtract(const Duration(hours: 2, minutes: 1)),
      blocked: true,
      reason: 'رفض الخادم هذا التغيير',
    ),
    PendingChangeSummary(
      id: 'change-2',
      entityType: 'task',
      title: 'مهمة: حجز المصور',
      createdAt: appNow().subtract(const Duration(hours: 5, minutes: 1)),
      blocked: false,
    ),
    PendingChangeSummary(
      id: 'change-3',
      entityType: 'cost',
      title: 'دفعة: قاعة ليالي صنعاء',
      createdAt: appNow().subtract(const Duration(days: 1, hours: 1)),
      blocked: false,
    ),
  ];
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
    DashboardAfterWedding? afterWedding,
    VoidCallback? onOpenReviews,
  }) => AarastDashboardView(
    summary: s,
    userName: 'محمد',
    bottomPadding: 158,
    now: now,
    funding: funding,
    afterWedding: afterWedding,
    onOpenReviews: onOpenReviews,
    assistantEntry: assistant,
    events: events,
    onOpenEvents: () {},
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

  // The money card once the money in is known and the server names dues:
  // the verdict chip and the strip (late, a month of next year, after the
  // wedding), which no picture drew before.
  testWidgets('home dues', (tester) async {
    await _shot(
      tester,
      'home_dues',
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
            // The money tab's sentence at its real length (D103).
            verdict: (
              ok: true,
              words:
                  'معك 2.9 مليون يكفي دفعاتك وسداد السلفة بمواعيدها لين 1 فبراير، ويبقى 250 ألف',
            ),
            dues: [
              DashboardHomeDue(label: 'متأخرة', amount: 400000, overdue: true),
              DashboardHomeDue(label: 'يناير 2027', amount: 1250000),
              DashboardHomeDue(label: 'بعد العرس', amount: 1700000),
            ],
          ),
        ),
        stage: 'التخطيط',
      ),
      h: 1000,
    );
  });

  testWidgets('home no date', (tester) async {
    final s = DashboardSummary.fromJson(_base(days: null, date: null));
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

  Future<List<SingleChildWidget>> syncProviders(
    SyncState s,
    int pending,
    int blocked,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final sync = _FakeSync(JsonLocalDatabase(prefs), s, pending, blocked);
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
    SharedPreferences.setMockInitialValues({
      'aarast.assistant.consent.v1.device': true,
    });
    // The question's bubble carries the clock time it was asked (the screen
    // reads DateTime.now()), so these few pixels change every minute. Only
    // this shot tolerates a difference that small; a moved or missing widget
    // is far above it.
    final before = goldenFileComparator;
    goldenFileComparator = _TolerantComparator(
      (before as LocalFileComparator).basedir.resolve('now_home_test.dart'),
      0.0005,
    );
    addTearDown(() => goldenFileComparator = before);
    await _shot(
      tester,
      'assistant_answer',
      assistant(_FakeAssistantApi()),
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

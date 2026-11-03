import 'dart:async';

import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/budget_category.dart';
import 'package:aarast_mobile/features/home/data/dashboard_summary_sources.dart';
import 'package:aarast_mobile/features/home/screens/local_guest_dashboard_screen.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/data/local_plan_migration.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/onboarding/screens/local_plan_migration_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/active_wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/models/onboarding_complete.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// w09 «عندك خطة على هذا الجوال» with the real migration service over fake
/// plan and money APIs.
void main() {
  testWidgets(
    'an account with a plan sees both plans by name and two choices',
    (tester) async {
      final harness = await _Harness.create(tester);

      expect(find.text('عندك خطة على هذا الجوال'), findsOneWidget);
      expect(
        find.text('سويتها قبل ما تدخل. وحسابك فيه خطة من قبل.'),
        findsOneWidget,
      );
      // D75: each plan by the name and city the person gave it.
      expect(find.text('على هذا الجوال'), findsOneWidget);
      expect(find.text('عرس محمد · صنعاء'), findsOneWidget);
      expect(find.text('في حسابك'), findsOneWidget);
      // The open plan the account owns, not the one changed last.
      expect(find.text('عرس أحمد · تعز'), findsOneWidget);
      expect(find.textContaining('عرس سالم'), findsNothing);
      expect(harness.plans.summaryPlanIds, ['plan-open']);
      expect(find.text('خلّها خطة ثانية'), findsOneWidget);
      expect(find.text('مثلًا لو هي لعرس أخوك'), findsOneWidget);
      expect(find.text('تجاهلها'), findsOneWidget);
      expect(find.text('تنحذف من الجوال بس'), findsOneWidget);
      // Nothing is chosen for the person: «متابعة» waits for a choice.
      final next = find.byKey(const ValueKey('local-plan-continue'));
      expect(tester.widget<JourneyButton>(next).onPressed, isNull);
      await tester.tap(next, warnIfMissed: false);
      await _settle(tester);
      expect(harness.plans.importCalls, 0);
      expect(find.text('عندك خطة على هذا الجوال'), findsOneWidget);
      // There is no merge mode on the server.
      expect(find.text('ضمّها لخطتي'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    "D75: the bride's plan on the groom's account stays for her, not a second plan",
    (tester) async {
      final harness = await _Harness.create(
        tester,
        accountPersona: 'GROOM',
        draft: _draft.copyWith(
          planName: 'عرس سلمى',
          persona: GuestPersona.bride,
        ),
      );

      expect(find.byKey(const ValueKey('local-plan-second')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('local-plan-keep-for-owner')));
      await _settle(tester);
      await tester.tap(find.byKey(const ValueKey('local-plan-continue')));
      await _settle(tester);

      // Nothing imported, nothing dropped: the plan waits on the phone.
      expect(harness.plans.importCalls, 0);
      expect(harness.finished, [null]);
      expect(await harness.storage.loadGuestPlan(), isNotNull);
    },
  );

  testWidgets(
    "D75: an account without a plan does not take in the other side's plan",
    (tester) async {
      final harness = await _Harness.create(
        tester,
        plans: const [],
        accountPersona: 'GROOM',
        draft: _draft.copyWith(
          planName: 'عرس سلمى',
          persona: GuestPersona.bride,
        ),
      );

      expect(harness.plans.importCalls, 0);
      expect(
        find.byKey(const ValueKey('local-plan-keep-for-owner')),
        findsOneWidget,
      );
      expect(find.text('سويتها قبل ما تدخل.'), findsOneWidget);
    },
  );

  testWidgets('plans without a name show their real counts', (tester) async {
    final harness = await _Harness.create(
      tester,
      plans: [
        _plan('plan-recent', DateTime(2026, 10, 2), title: '', city: ''),
        _plan('plan-open', DateTime(2026, 9, 1), title: '', city: ''),
      ],
      draft: _draft.copyWith(planName: '', city: ''),
    );

    expect(find.text('5 بنود · 8 مهام'), findsOneWidget);
    expect(find.text('14 بند · 23 مهمة'), findsOneWidget);
    expect(harness.plans.summaryPlanIds, ['plan-open']);
  });

  testWidgets('a second plan imports as a new plan, then clears the phone', (
    tester,
  ) async {
    final harness = await _Harness.create(tester);
    final gate = Completer<OnboardingCompleteResponse>();
    harness.plans.onImport = () => gate.future;

    await tester.tap(find.text('خلّها خطة ثانية'));
    await tester.pump();
    await tester.tap(find.text('متابعة'));
    await tester.pump();

    expect(harness.plans.importCalls, 1);
    expect(harness.plans.lastPayload?['clientMigrationId'], 'local-guest-1');
    // Nothing leaves the phone until the server confirms.
    expect(await harness.storage.loadGuestPlan(), isNotNull);

    gate.complete(_response('plan-new'));
    await _settle(tester);

    expect(harness.finished, ['plan-new']);
    expect(await harness.storage.loadGuestPlan(), isNull);
    expect(find.text('عندك خطة على هذا الجوال'), findsNothing);
  });

  testWidgets('a failed import keeps the phone plan and the choice open', (
    tester,
  ) async {
    final harness = await _Harness.create(tester);
    harness.plans.onImport = () =>
        Future.error(const ApiException('تعذر استيراد الخطة المحلية.'));

    await tester.tap(find.text('خلّها خطة ثانية'));
    await tester.pump();
    await tester.tap(find.text('متابعة'));
    await _settle(tester);

    expect(find.text('تعذر استيراد الخطة المحلية.'), findsOneWidget);
    expect(find.text('عندك خطة على هذا الجوال'), findsOneWidget);
    expect(harness.finished, isEmpty);
    expect(await harness.storage.loadGuestPlan(), isNotNull);
  });

  testWidgets('dropping the phone plan needs two confirmations (C62)', (
    tester,
  ) async {
    final harness = await _Harness.create(tester);

    await tester.tap(find.text('تجاهلها'));
    await tester.pump();
    await tester.tap(find.text('متابعة'));
    await _settle(tester);

    // First confirmation was the choice; the second is asked.
    expect(find.text('تمسح الخطة اللي على الجوال؟'), findsOneWidget);
    expect(await harness.storage.loadGuestPlan(), isNotNull);

    await tester.tap(find.text('لا، خلّها'));
    await _settle(tester);
    expect(find.text('تمسح الخطة اللي على الجوال؟'), findsNothing);
    expect(find.text('عندك خطة على هذا الجوال'), findsOneWidget);
    expect(await harness.storage.loadGuestPlan(), isNotNull);
    expect(harness.finished, isEmpty);

    await tester.tap(find.text('متابعة'));
    await _settle(tester);
    await tester.tap(find.text('إيه، امسحها'));
    await _settle(tester);

    expect(harness.finished, [null]);
    expect(harness.plans.importCalls, 0);
    expect(await harness.storage.loadGuestPlan(), isNull);
  });

  testWidgets('an account without a plan saves the phone plan at once', (
    tester,
  ) async {
    final harness = await _Harness.create(
      tester,
      plans: const [],
      settle: false,
    );
    // The saving spinner stays until the entry screen swaps this one out.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(harness.plans.importCalls, 1);
    expect(find.text('عندك خطة على هذا الجوال'), findsNothing);
    expect(harness.finished, ['plan-new']);
    expect(await harness.storage.loadGuestPlan(), isNull);
  });

  testWidgets('an archived plan does not count as a plan in the account', (
    tester,
  ) async {
    final harness = await _Harness.create(
      tester,
      plans: [_plan('plan-old', DateTime(2026, 9, 1), status: 'ARCHIVED')],
      settle: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));

    expect(harness.plans.importCalls, 1);
    expect(harness.finished, ['plan-new']);
  });

  testWidgets('a failed account lookup keeps the plan and can try again', (
    tester,
  ) async {
    final harness = await _Harness.create(tester, listFails: true);
    await _settle(tester);

    expect(find.text('ما قدرنا نحفظها في حسابك'), findsOneWidget);
    expect(
      find.textContaining('ما قدرنا نشوف حسابك. تأكد من النت وجرّب مرة ثانية.'),
      findsOneWidget,
    );
    expect(find.textContaining('خطتك باقية على هذا الجوال'), findsOneWidget);
    expect(harness.plans.importCalls, 0);
    expect(await harness.storage.loadGuestPlan(), isNotNull);

    harness.plans.listFails = false;
    await tester.tap(find.text('جرّب مرة ثانية'));
    await _settle(tester);
    expect(find.text('عندك خطة على هذا الجوال'), findsOneWidget);
  });

  // J1-01 (D77): a plan the account could not take never locks the app.
  // A third way out opens it on the phone, with a strip that saves it later.
  testWidgets('J1-01: a failed save offers to open the plan on the phone', (
    tester,
  ) async {
    final harness = await _Harness.create(
      tester,
      plans: const [],
      onImport: () => Future.error(_offline),
    );

    expect(find.text('ما قدرنا نحفظها في حسابك'), findsOneWidget);
    // The real cause, not «check the internet» in general.
    expect(find.textContaining('ما فيه نت الحين'), findsOneWidget);
    expect(find.text('جرّب مرة ثانية'), findsOneWidget);
    expect(find.text('امسحها من الجوال'), findsOneWidget);
    expect(find.text('افتح خطتك على الجوال الحين'), findsOneWidget);
    expect(harness.finished, isEmpty);
  });

  testWidgets('J1-01: offline, the account lookup says so too', (
    tester,
  ) async {
    await _Harness.create(tester, listFails: true, listError: _offline);

    expect(find.textContaining('ما فيه نت الحين'), findsOneWidget);
    expect(find.text('افتح خطتك على الجوال الحين'), findsOneWidget);
  });

  testWidgets('J1-01: the plan opens on the phone with «ما انحفظت في حسابك بعد»', (
    tester,
  ) async {
    final harness = await _Harness.create(
      tester,
      plans: const [],
      onImport: () => Future.error(_offline),
    );

    await tester.tap(find.text('افتح خطتك على الجوال الحين'));
    await _settle(tester);

    expect(find.byType(LocalGuestDashboardScreen), findsOneWidget);
    expect(find.text('ما قدرنا نحفظها في حسابك'), findsNothing);
    expect(find.text('ما انحفظت في حسابك بعد'), findsOneWidget);
    expect(find.text('احفظها الحين'), findsOneWidget);
    // Remembered for this session, so the next home does not lock again.
    expect(harness.openedLocally, 1);
    expect(harness.finished, isEmpty);
    expect(await harness.storage.loadGuestPlan(), isNotNull);
  });

  testWidgets('J1-01: «احفظها الحين» tries the account again', (tester) async {
    final harness = await _Harness.create(
      tester,
      plans: const [],
      onImport: () => Future.error(_offline),
    );
    await tester.tap(find.text('افتح خطتك على الجوال الحين'));
    await _settle(tester);
    expect(harness.plans.importCalls, 1);

    await _tapStrip(tester);

    expect(harness.plans.importCalls, 2);
    // Still offline: the same three ways out, nothing lost.
    expect(find.text('افتح خطتك على الجوال الحين'), findsOneWidget);
    expect(await harness.storage.loadGuestPlan(), isNotNull);
  });

  testWidgets('J1-01: saved from the strip, it finishes like the first save', (
    tester,
  ) async {
    final harness = await _Harness.create(
      tester,
      plans: const [],
      onImport: () => Future.error(_offline),
    );
    await tester.tap(find.text('افتح خطتك على الجوال الحين'));
    await _settle(tester);
    harness.plans.onImport = () async => _response('plan-new');

    await _tapStrip(tester);

    expect(harness.finished, ['plan-new']);
    expect(await harness.storage.loadGuestPlan(), isNull);
  });

  testWidgets('J1-01: opened on the phone before, it saves itself once online', (
    tester,
  ) async {
    final harness = await _Harness.create(
      tester,
      plans: const [],
      startLocally: true,
    );

    expect(harness.plans.importCalls, 1);
    expect(harness.finished, ['plan-new']);
    expect(find.text('ما قدرنا نحفظها في حسابك'), findsNothing);
  });

  testWidgets('J1-01: opened on the phone before and still offline, it stays', (
    tester,
  ) async {
    final harness = await _Harness.create(
      tester,
      startLocally: true,
      listFails: true,
      listError: _offline,
    );

    expect(find.byType(LocalGuestDashboardScreen), findsOneWidget);
    expect(find.text('ما انحفظت في حسابك بعد'), findsOneWidget);
    expect(find.text('ما قدرنا نحفظها في حسابك'), findsNothing);
    expect(harness.finished, isEmpty);
  });

  testWidgets('J1-01: a quiet try never chooses for an account with a plan', (
    tester,
  ) async {
    final harness = await _Harness.create(tester, startLocally: true);

    expect(harness.plans.importCalls, 0);
    expect(find.byType(LocalGuestDashboardScreen), findsOneWidget);
    expect(find.text('عندك خطة على هذا الجوال'), findsNothing);
  });

  testWidgets('J1-13: a plan the account refuses says why', (tester) async {
    await _Harness.create(
      tester,
      plans: const [],
      onImport: () => Future.error(
        const ApiException(
          'تعذّر الحفظ: راجع البيانات المدخلة ثم حاول مرة أخرى.',
          statusCode: 400,
        ),
      ),
    );

    expect(
      find.textContaining('فيه شي في خطتك ما قبله الحساب'),
      findsOneWidget,
    );
    expect(find.textContaining('راجع البيانات المدخلة'), findsNothing);
    expect(find.text('افتح خطتك على الجوال الحين'), findsOneWidget);
  });
}

const _offline = ApiException(
  'تعذر تحميل البيانات الآن. تحقق من الاتصال وحاول مرة أخرى.',
  isNetworkFailure: true,
);

/// «احفظها الحين» on the phone plan's home.
Future<void> _tapStrip(WidgetTester tester) async {
  final strip = find.byKey(const Key('aarast-local-sync-action'));
  await tester.ensureVisible(strip);
  await tester.pump();
  await tester.tap(strip);
  await _settle(tester);
}

/// The page under the sheet keeps its spinner turning while the person
/// chooses, so the frames are pumped for a fixed time instead of settling.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

class _Harness {
  _Harness(this.storage, this.plans);

  final GuestOnboardingStorage storage;
  final _FakeWeddingPlansApi plans;
  final List<String?> finished = [];

  /// How many times the plan was opened on the phone instead (D77).
  int openedLocally = 0;

  static Future<_Harness> create(
    WidgetTester tester, {
    List<WeddingPlan>? plans,
    bool listFails = false,
    Object? listError,
    bool settle = true,
    GuestOnboardingDraft? draft,
    String? accountPersona,
    Future<OnboardingCompleteResponse> Function()? onImport,
    bool startLocally = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = GuestOnboardingStorage(preferences);
    await storage.saveDraft(draft ?? _draft);
    final api = _FakeWeddingPlansApi(
      plans:
          plans ??
          [
            _plan('plan-recent', DateTime(2026, 10, 2)),
            _plan('plan-open', DateTime(2026, 9, 1)),
          ],
      activeId: 'plan-open',
      tasksByPlan: const {'plan-open': 23, 'plan-recent': 4},
    )..listFails = listFails;
    if (listError != null) api.listError = listError;
    if (onImport != null) api.onImport = onImport;
    final harness = _Harness(storage, api);
    final service = LocalPlanMigrationService(
      guestStorage: storage,
      weddingPlansApi: api,
      financeApi: _FakeFinanceApi(const {'plan-open': 14, 'plan-recent': 2}),
    );

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    final auth = _PersonaAuth(preferences, accountPersona);
    final phonePlan = draft ?? _draft;
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<AuthController>.value(value: auth),
          Provider<AuthStorage>.value(value: AuthStorage(preferences)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          builder: (context, child) =>
              Directionality(textDirection: TextDirection.rtl, child: child!),
          home: LocalPlanMigrationScreen(
            snapshot: draft == null
                ? _snapshot
                : LocalPlanSnapshot(
                    draft: draft,
                    costs: _snapshot.costs,
                    costPayments: _snapshot.costPayments,
                    paymentSchedules: _snapshot.paymentSchedules,
                    tasks: _snapshot.tasks,
                    guests: _snapshot.guests,
                    categoryNameById: _snapshot.categoryNameById,
                  ),
            migrationService: service,
            onFinished: harness.finished.add,
            startLocally: startLocally,
            onOpenedLocally: () => harness.openedLocally += 1,
            // The entry screen's own phone home (D77).
            localPlan: (context, saveNow) => LocalGuestDashboardScreen(
              summary: LocalGuestDashboardSummary.fromPlan(phonePlan),
              onSaveToAccount: saveNow,
            ),
          ),
        ),
      ),
    );
    if (settle) {
      await _settle(tester);
    } else {
      await tester.pump();
    }
    return harness;
  }
}

/// An account on one side of a wedding (its persona), signed in.
class _PersonaAuth extends AuthController {
  _PersonaAuth(SharedPreferences preferences, this.persona)
    : super(
        AuthRepository(
          ApiClient(tokenProvider: () async => null),
          AuthStorage(preferences),
        ),
      );

  final String? persona;

  @override
  SafeUser? get user => SafeUser(
    id: 'user-1',
    name: 'محمد',
    role: 'USER',
    status: 'ACTIVE',
    persona: persona,
  );
}

/// The account's plans by name and city, as the server returns them.
const _planTitles = {'plan-open': 'عرس أحمد', 'plan-recent': 'عرس سالم'};
const _planCities = {'plan-open': 'تعز', 'plan-recent': 'عدن'};

final _draft = GuestOnboardingDraft(
  guestPlanId: 'local-guest-1',
  planName: 'عرس محمد',
  createdAt: DateTime(2026, 10, 20),
  isGuestPlan: true,
  needsSync: true,
  selectedPath: GuestOnboardingPath.weddingUser,
  persona: GuestPersona.groom,
  governorate: 'أمانة العاصمة',
  city: 'صنعاء',
  district: null,
  neighborhood: null,
  street: null,
  addressNote: null,
  weddingDate: DateTime(2027, 1, 21),
  weddingDateUnknown: false,
  priorities: const [],
  currency: 'YER',
  estimatedBudget: '7000000',
  selectedCategoryKeys: const ['القاعة'],
);

final _snapshot = LocalPlanSnapshot(
  draft: _draft,
  costs: const [],
  costPayments: const [],
  paymentSchedules: const [],
  tasks: [
    for (var i = 0; i < 8; i++) {'id': 'task-$i'},
  ],
  guests: const [],
  categoryNameById: const {
    'c1': 'القاعة',
    'c2': 'التصوير',
    'c3': 'الفنان',
    'c4': 'الزينة',
    'c5': 'الضيافة',
  },
);

WeddingPlan _plan(
  String id,
  DateTime updatedAt, {
  String status = 'PLANNING',
  String? title,
  String? city,
}) {
  return WeddingPlan(
    id: id,
    ownerUserId: 'user-1',
    title: title ?? _planTitles[id] ?? id,
    city: city ?? _planCities[id],
    currency: 'YER',
    status: status,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: updatedAt,
  );
}

OnboardingCompleteResponse _response(String planId) {
  return OnboardingCompleteResponse(
    user: const SafeUser(
      id: 'user-1',
      name: 'محمد',
      role: 'USER',
      status: 'ACTIVE',
    ),
    activeWeddingPlan: ActiveWeddingPlan.fromWeddingPlan(
      _plan(planId, DateTime(2026, 10, 24)),
    ),
    budgetCategories: const [],
  );
}

class _FakeWeddingPlansApi extends WeddingPlansApi {
  _FakeWeddingPlansApi({
    required this.plans,
    required this.activeId,
    required this.tasksByPlan,
  }) : super(ApiClient(tokenProvider: () async => null));

  final List<WeddingPlan> plans;
  final String? activeId;
  final Map<String, int> tasksByPlan;
  bool listFails = false;
  Object listError = const ApiException('offline');
  int importCalls = 0;
  Map<String, dynamic>? lastPayload;
  final List<String> summaryPlanIds = [];
  Future<OnboardingCompleteResponse> Function() onImport = () async =>
      _response('plan-new');

  @override
  Future<List<WeddingPlan>> getMyWeddingPlans() async {
    if (listFails) throw listError;
    return plans;
  }

  @override
  Future<ActiveWeddingPlan?> getActiveWeddingPlan() async {
    for (final plan in plans) {
      if (plan.id == activeId) return ActiveWeddingPlan.fromWeddingPlan(plan);
    }
    return null;
  }

  @override
  Future<DashboardSummary> getDashboardSummary(String planId) async {
    summaryPlanIds.add(planId);
    return DashboardSummary(
      planId: planId,
      title: planId,
      status: 'PLANNING',
      progressPercentage: 0,
      totalTasks: tasksByPlan[planId] ?? 0,
      completedTasks: 0,
      overdueTasks: 0,
      todayTasks: 0,
      guestCount: 0,
      confirmedGuests: 0,
      providerCount: 0,
      quoteRequestsCount: 0,
      unreadNotificationsCount: 0,
      importantItems: const [],
      planProviders: const [],
      importantNotifications: const [],
      permissions: const DashboardPermissionSummary(
        isOwner: true,
        canViewMoney: true,
        canManageTasks: true,
        canManageMoney: true,
        canManagePlan: true,
      ),
    );
  }

  @override
  Future<OnboardingCompleteResponse> importLocalPlan(
    Map<String, dynamic> payload,
  ) {
    importCalls += 1;
    lastPayload = payload;
    return onImport();
  }
}

class _FakeFinanceApi extends FinanceApi {
  _FakeFinanceApi(this.itemsByPlan)
    : super(ApiClient(tokenProvider: () async => null));

  final Map<String, int> itemsByPlan;

  @override
  Future<List<BudgetCategory>> getBudgetCategories(String planId) async => [
    for (var i = 0; i < (itemsByPlan[planId] ?? 0); i++)
      BudgetCategory.fromJson({'id': '$planId-$i', 'name': 'بند $i'}),
  ];
}

import 'package:aarast_mobile/core/utils/app_clock.dart';
import 'package:aarast_mobile/core/utils/plan_day.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/push/push_messaging_gateway.dart';
import 'package:aarast_mobile/core/push/push_notifications_controller.dart';
import 'package:aarast_mobile/core/push/push_registration_api.dart';
import 'package:dio/dio.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/core/utils/amount_words.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/marketplace/data/marketplace_api.dart';
import 'package:aarast_mobile/features/marketplace/models/marketplace_models.dart';
import 'package:aarast_mobile/core/utils/arabic_date_formatter.dart';
import 'package:aarast_mobile/core/utils/hijri_date.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/onboarding/models/wedding_location_draft.dart';
import 'package:aarast_mobile/features/sharing/data/sharing_api.dart';
import 'package:aarast_mobile/features/sharing/models/shared_member.dart';
import 'package:aarast_mobile/features/sharing/providers/sharing_provider.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/onboarding_complete.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:aarast_mobile/features/welcome_gateway/screens/smart_welcome_screen.dart';

import '../../support/preview_fonts.dart';
import '../../support/app_route_table.dart';
import '../../support/app_text_scale.dart';

// The start (D75, prototype a02 to a08): a door with one-tap ways in, one
// question per screen, the plan kept on the phone, and the account asked
// for only on saving.

GoRouter _router({String initialLocation = '/welcome'}) => GoRouter(
  initialLocation: initialLocation,
  routes: [
    GoRoute(
      path: appRoute('/welcome'),
      builder: (context, state) => const SmartWelcomeScreen(),
    ),
    // RA-MO-337: the invite screen, opened by the invite's id.
    GoRoute(
      path: appRoute('/invites/:token'),
      builder: (context, state) =>
          Scaffold(body: Text('opened:${state.uri.path}')),
    ),
    // w11 «خطة جديدة».
    GoRoute(
      path: appRoute('/wedding-plans/create'),
      builder: (context, state) => const SmartWelcomeScreen(newPlan: true),
    ),
    for (final route in [
      '/provider/apply',
      '/invites',
      '/login',
      '/home',
      '/register',
    ])
      GoRoute(
        path: route,
        builder: (context, state) => Scaffold(
          body: Text(
            'opened:$route'
            '${state.uri.hasQuery ? '?${state.uri.query}' : ''}',
          ),
        ),
      ),
  ],
);

class _SignedIn extends AuthController {
  _SignedIn(super.authRepository);

  @override
  AuthStatus get status => AuthStatus.authenticated;
}

/// RA-MO-337: the invites the server holds for the signed-in number.
class _MyInvites extends SharingProvider {
  _MyInvites(this.waiting)
    : super(SharingApi(ApiClient(tokenProvider: () async => null)));

  final List<PlanInvite> waiting;
  int asked = 0;
  List<PlanInvite> _read = const [];

  @override
  List<PlanInvite> get myInvites => _read;

  @override
  Future<void> loadMyInvites({String? token}) async {
    asked += 1;
    _read = waiting;
    notifyListeners();
  }
}

PlanInvite _invite({String status = 'PENDING', DateTime? expiresAt}) =>
    PlanInvite.fromJson({
      'id': 'invite-1',
      'weddingPlanId': 'plan-9',
      'status': status,
      'role': 'HELPER',
      'expiresAt': (expiresAt ?? DateTime.now().add(const Duration(days: 3)))
          .toIso8601String(),
      'weddingPlan': {'title': 'عرس محمد'},
      'inviter': {'name': 'محمد'},
    });

/// Records the plan the screen asks for; answers like the server would.
class _RecordingPlans extends WeddingPlansProvider {
  _RecordingPlans({required this.succeed})
    : super(WeddingPlansApi(ApiClient(tokenProvider: () async => null)));

  final bool succeed;
  OnboardingCompleteRequest? request;
  final List<String> keys = [];

  @override
  String? get errorMessage => succeed ? null : 'تعذر إنشاء خطتك.';

  @override
  Future<OnboardingCompleteResponse?> completeOnboarding(
    OnboardingCompleteRequest request, {
    required String clientRequestId,
  }) async {
    this.request = request;
    keys.add(clientRequestId);
    if (!succeed) return null;
    return OnboardingCompleteResponse.fromJson({
      'activeWeddingPlan': {'id': 'plan-new', 'title': request.title},
    });
  }
}

Future<GuestOnboardingStorage> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 900),
  double textScale = 1,
  WeddingPlansProvider? signedInPlans,
  FinanceApi? finance,
  MarketplaceApi? marketplace,
  bool signedIn = false,
  String initialLocation = '/welcome',
  GuestOnboardingDraft? keptPlan,
  PushNotificationsController? push,
  SharingProvider? sharing,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final preferences = await SharedPreferences.getInstance();
  final storage = GuestOnboardingStorage(preferences);
  if (keptPlan != null) await storage.saveDraft(keptPlan);
  final authStorage = AuthStorage(preferences);
  final apiClient = ApiClient(tokenProvider: () async => null);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        Provider<GuestOnboardingStorage>.value(value: storage),
        if (push != null)
          ChangeNotifierProvider<PushNotificationsController>.value(
            value: push,
          ),
        if (finance != null) Provider<FinanceApi>.value(value: finance),
        if (marketplace != null)
          Provider<MarketplaceApi>.value(value: marketplace),
        if (sharing != null)
          ChangeNotifierProvider<SharingProvider>.value(value: sharing),
        if (signedInPlans == null && signedIn)
          ChangeNotifierProvider<AuthController>(
            create: (_) => _SignedIn(AuthRepository(apiClient, authStorage)),
          ),
        if (signedInPlans != null) ...[
          ChangeNotifierProvider<AuthController>(
            create: (_) => _SignedIn(AuthRepository(apiClient, authStorage)),
          ),
          ChangeNotifierProvider<WeddingPlansProvider>.value(
            value: signedInPlans,
          ),
        ],
      ],
      child: MaterialApp.router(
        routerConfig: _router(initialLocation: initialLocation),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: appTextScaler(textScale)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return storage;
}

Future<void> _tap(WidgetTester tester, String text) async {
  // The steps are lazy lists: scroll until a far line is built.
  if (find.text(text).evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  final finder = find.text(text).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _tapKey(WidgetTester tester, String key) async {
  final finder = find.byKey(ValueKey(key));
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      200,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

/// The progress track's spoken count (D75: no drawn «1 من 3»).
Finder _progress(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);

JourneyButton _button(WidgetTester tester, String label) =>
    tester.widget<JourneyButton>(find.widgetWithText(JourneyButton, label));

JourneyTextAction _link(WidgetTester tester, String label) => tester
    .widget<JourneyTextAction>(find.widgetWithText(JourneyTextAction, label));

/// The door, «أنت العريس ولا العروسة؟» (one tap), and the name with no
/// date yet: the city and budget step is open.
Future<void> _answerUpToPlace(
  WidgetTester tester, {
  String persona = 'persona-groom',
  String name = 'محمد',
}) async {
  await _tapKey(tester, 'door-plan');
  await _tapKey(tester, persona);
  await tester.enterText(find.byType(TextField).first, name);
  await tester.pumpAndSettle();
  // «ما حددنا الموعد بعد» advances at once.
  await _tap(tester, 'ما حددنا الموعد بعد');
}

Future<void> _answerUpToReady(WidgetTester tester) async {
  await _answerUpToPlace(tester);
  await _tap(tester, 'صنعاء');
  await tester.enterText(find.byType(TextField).first, '7000000');
  await tester.pumpAndSettle();
  await _tap(tester, 'التالي');
  // a06: the mahr, not agreed yet.
  await _tap(tester, 'ما اتفقنا بعد');
}

void main() {
  setUpAll(loadPreviewAppFonts);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a02 opens three ways in and sign in, each with one tap', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('أهلًا فيك، من فين نبدأ؟'), findsOneWidget);
    expect(find.text('أسوّي خطة عرسي'), findsOneWidget);
    expect(find.text('معي رابط دعوة'), findsOneWidget);
    expect(find.text('أقدّم خدمة للأعراس'), findsOneWidget);
    for (final key in ['door-plan', 'door-invite', 'door-provider']) {
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('door-login')), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
    // D75: no choice to make first, so no «ابدأ».
    expect(find.text('ابدأ'), findsNothing);
    // C52: no account is promised before there is a plan.
    expect(find.text('أنشئ حسابي'), findsNothing);
  });

  testWidgets('D75: a plan on the phone opens, or a new one takes its place', (
    tester,
  ) async {
    final kept =
        GuestOnboardingDraft.quickLocalPlanSetup(
          planName: 'عرس أمل',
          persona: GuestPersona.bride,
          location: WeddingLocationDraft.fromLegacyFields(
            governorate: 'عدن',
            city: 'عدن',
          ),
          weddingDate: null,
          currency: 'YER',
          startingItemNames: const ['فستان العروسة'],
        ).copyWith(
          guestPlanId: 'local-guest-9',
          createdAt: DateTime(2026, 11, 1),
          isGuestPlan: true,
          needsSync: true,
        );
    final storage = await _pump(tester, keptPlan: kept);

    expect(find.text('افتح خطتي'), findsOneWidget);
    expect(find.text('عرس أمل، على هذا الجوال'), findsOneWidget);
    await _tapKey(tester, 'door-replace-plan');
    expect(find.text('تبدأ خطة جديدة بدل عرس أمل؟'), findsOneWidget);
    await _tapKey(tester, 'door-replace-confirm');

    expect(find.text('أنت العريس ولا العروسة؟'), findsOneWidget);
    expect(await storage.loadDraft(), isNull);
  });

  testWidgets('signed out, the provider door opens the provider sign-up', (
    tester,
  ) async {
    await _pump(tester);
    await _tapKey(tester, 'door-provider');
    expect(find.text('opened:/register?type=provider'), findsOneWidget);
  });

  testWidgets('signed in, the provider door opens provider apply', (
    tester,
  ) async {
    await _pump(tester, signedIn: true);
    await _tapKey(tester, 'door-provider');
    expect(find.text('opened:/provider/apply'), findsOneWidget);
  });

  testWidgets('the invite door opens the invitations', (tester) async {
    await _pump(tester);
    await _tapKey(tester, 'door-invite');
    expect(find.text('opened:/invites'), findsOneWidget);
  });

  // RA-MO-337: who signed up after the invite was sent had no way to it: the
  // invites waiting for his number were asked only with a link's token. The
  // door asks for them once he is signed in, and opens the one waiting by
  // its id, on the invite screen (q01 to q03).
  testWidgets(
    'signed in, an invite waiting for his number is the invite door',
    (tester) async {
      final sharing = _MyInvites([_invite()]);
      await _pump(tester, signedIn: true, sharing: sharing);

      expect(sharing.asked, 1);
      expect(find.text('عندك دعوة تنتظرك'), findsOneWidget);
      expect(find.text('من محمد · عرس محمد'), findsOneWidget);
      await _tapKey(tester, 'door-invite');
      expect(find.text('opened:/invites/invite-1'), findsOneWidget);
    },
  );

  testWidgets('an invite answered or ended is no waiting invite', (
    tester,
  ) async {
    final sharing = _MyInvites([
      _invite(status: 'ACCEPTED'),
      _invite(expiresAt: DateTime.now().subtract(const Duration(days: 1))),
    ]);
    await _pump(tester, signedIn: true, sharing: sharing);

    expect(find.text('عندك دعوة تنتظرك'), findsNothing);
    await _tapKey(tester, 'door-invite');
    expect(find.text('opened:/invites'), findsOneWidget);
  });

  testWidgets('signed out, no invite is asked for', (tester) async {
    final sharing = _MyInvites([_invite()]);
    await _pump(tester, sharing: sharing);
    expect(sharing.asked, 0);
    expect(find.text('معي رابط دعوة'), findsOneWidget);
  });

  testWidgets('«تسجيل الدخول» opens sign in', (tester) async {
    await _pump(tester);
    await _tapKey(tester, 'door-login');
    expect(find.text('opened:/login'), findsOneWidget);
  });

  testWidgets('a02b: one tap on the groom or the bride opens the name', (
    tester,
  ) async {
    await _pump(tester);
    await _tapKey(tester, 'door-plan');
    expect(find.text('أنت العريس ولا العروسة؟'), findsOneWidget);
    expect(find.text('العريس'), findsOneWidget);
    expect(find.text('العروسة'), findsOneWidget);
    // Nothing is chosen for the person, and nothing waits for «التالي».
    expect(find.text('التالي'), findsNothing);

    await _tapKey(tester, 'persona-bride');
    expect(find.text('ايش اسمك، ومتى العرس؟'), findsOneWidget);
    // The plan already speaks in the bride's words.
    expect(find.text('سلمى'), findsOneWidget);
  });

  testWidgets('a03 waits for a name and a day; no date yet goes on at once', (
    tester,
  ) async {
    await _pump(tester);
    await _tapKey(tester, 'door-plan');
    await _tapKey(tester, 'persona-groom');
    expect(find.text('ايش اسمك، ومتى العرس؟'), findsOneWidget);
    expect(_progress('السؤال 1 من 3'), findsOneWidget);
    expect(find.text('1 من 3'), findsNothing);

    // No name: «التالي» waits; the link says what is missing and stays.
    expect(_button(tester, 'التالي').onPressed, isNull);
    await _tap(tester, 'ما حددنا الموعد بعد');
    expect(find.text('اكتب اسمك أول'), findsOneWidget);
    expect(find.text('ايش اسمك، ومتى العرس؟'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'محمد');
    await tester.pumpAndSettle();
    expect(
      find.text('خطتك بتكون: عرس محمد', findRichText: true),
      findsOneWidget,
    );
    // A name without a day: «التالي» still waits for the day.
    expect(_button(tester, 'التالي').onPressed, isNull);
    expect(_link(tester, 'ما حددنا الموعد بعد').onPressed, isNotNull);

    await _tap(tester, 'ما حددنا الموعد بعد');
    expect(find.text('فين العرس، وكم ميزانيتك تقريبًا؟'), findsOneWidget);
    expect(_progress('السؤال 2 من 3'), findsOneWidget);
  });

  testWidgets('a05 spells the budget and needs a city', (tester) async {
    await _pump(tester);
    await _answerUpToPlace(tester);

    expect(find.text('ميزانية عرسك'), findsOneWidget);
    // D114: the mahr's place in the budget is the groom's to choose, with
    // the mahr question next; never said here as a fact.
    expect(
      find.text(
        'بعدها نسألك عن المهر، وتختار هل هو من الميزانية. وتقدر تغيّرها بعدين من صفحة المال.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('مش منها'), findsNothing);
    await tester.enterText(find.byType(TextField).first, '7000000');
    await tester.pumpAndSettle();
    expect(find.text('سبعة مليون ر.ي'), findsOneWidget);
    // No city: «التالي» waits; the link says what is missing and stays.
    expect(_button(tester, 'التالي').onPressed, isNull);
    await _tap(tester, 'أكمل بدون ميزانية');
    expect(find.text('اختر المدينة أول'), findsOneWidget);
    expect(find.text('فين العرس، وكم ميزانيتك تقريبًا؟'), findsOneWidget);

    await _tap(tester, 'صنعاء');
    await _tap(tester, 'التالي');
    expect(find.text('اتفقتوا على المهر؟'), findsOneWidget);
    await _tap(tester, 'ما اتفقنا بعد');
    expect(find.text('خطتك جاهزة يا محمد'), findsOneWidget);
  });

  testWidgets('a05 «أكمل بدون ميزانية» goes on at once without a total', (
    tester,
  ) async {
    final finance = _RecordingFinance();
    final storage = await _pump(tester, finance: finance);
    await _answerUpToPlace(tester);
    await _tap(tester, 'صنعاء');
    await tester.enterText(find.byType(TextField).first, '7000000');
    await tester.pumpAndSettle();

    await _tap(tester, 'أكمل بدون ميزانية');
    expect(find.text('اتفقتوا على المهر؟'), findsOneWidget);
    await _tap(tester, 'ما اتفقنا بعد');
    await _tapKey(tester, 'ready-later');

    final draft = await storage.loadDraft();
    expect(draft!.estimatedBudget, isNull);
    expect(draft.budgetSkipped, isTrue);
    expect(finance.budgets, [null]);
  });

  testWidgets('a06: the groom\'s mahr goes with his plan, outside the budget', (
    tester,
  ) async {
    final plans = _RecordingPlans(succeed: true);
    await _pump(tester, signedInPlans: plans);
    await _answerUpToPlace(tester);
    await _tap(tester, 'صنعاء');
    await tester.enterText(find.byType(TextField).first, '7000000');
    await tester.pumpAndSettle();
    await _tap(tester, 'التالي');

    expect(_progress('السؤال 3 من 3'), findsOneWidget);
    expect(find.text('اتفقتوا على المهر؟'), findsOneWidget);
    // D114: where it counts is his answer below, not a fact said here.
    expect(
      find.text('اللي بتسلّمه لأهل العروسة. نتابع كم سلّمت وكم باقي.'),
      findsOneWidget,
    );
    expect(
      find.text('أرقام المهر ما يشوفها غيرك، إلا اللي تسمح له يشوف المال.'),
      findsOneWidget,
    );
    // Nothing typed: «التالي» asks for the mahr.
    await _tap(tester, 'التالي');
    expect(find.text('اكتب كم المهر'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('mahr-total')),
        matching: find.byType(TextField),
      ),
      '3000000',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('mahr-settled')),
        matching: find.byType(TextField),
      ),
      '2000000',
    );
    await tester.pumpAndSettle();
    expect(find.text('ثلاثة مليون ر.ي'), findsOneWidget);
    expect(find.text('سلّمت منه'), findsOneWidget);
    expect(find.text('باقي مليون'), findsOneWidget);
    expect(find.text('موعد تسليم الباقي'), findsOneWidget);
    await _tap(tester, 'التالي');
    expect(
      find.text('الميزانية 7 مليون · المهر 3 مليون، باقي مليون'),
      findsOneWidget,
    );
    await _tap(tester, 'افتح خطتي');

    expect(plans.request!.mahr, {'total': '3000000', 'settled': '2000000'});
  });

  // D114, the owner's own numbers: budget 7 million, mahr 2 million of
  // which 500 thousand handed over. The choice comes once the mahr is
  // typed, where both figures are known and each answer can say them.
  group('D114 the mahr in the budget or on its own', () {
    Future<void> typeMahr(WidgetTester tester) async {
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('mahr-total')),
          matching: find.byType(TextField),
        ),
        '2000000',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const ValueKey('mahr-settled')),
          matching: find.byType(TextField),
        ),
        '500000',
      );
      await tester.pumpAndSettle();
    }

    Future<void> upToMahr(
      WidgetTester tester, {
      String persona = 'persona-groom',
    }) async {
      await _answerUpToPlace(tester, persona: persona);
      await _tap(tester, 'صنعاء');
      await tester.enterText(find.byType(TextField).first, '7000000');
      await tester.pumpAndSettle();
      await _tap(tester, 'التالي');
    }

    testWidgets('inside: the groom chooses it in his numbers, and it is '
        'sent', (tester) async {
      final plans = _RecordingPlans(succeed: true);
      await _pump(tester, signedInPlans: plans, size: const Size(390, 1400));
      await upToMahr(tester);

      expect(find.byKey(const ValueKey('mahr-budget-choice')), findsNothing);
      await typeMahr(tester);
      expect(find.text('المهر من الميزانية؟'), findsOneWidget);
      expect(
        find.text('الميزانية 7 مليون كلها للعرس، والمهر مليونين فوقها'),
        findsOneWidget,
      );
      expect(
        find.text(
          'من الميزانية 7 مليون يروح مليونين للمهر، ويبقى للعرس 5 مليون',
        ),
        findsOneWidget,
      );
      await _tapKey(tester, 'mahr-budget-inside');
      await _tap(tester, 'التالي');

      expect(
        find.text(
          'الميزانية 7 مليون، فيها المهر · المهر مليونين، باقي 1.5 مليون',
        ),
        findsOneWidget,
      );
      await _tap(tester, 'افتح خطتي');
      expect(plans.request!.budgetIncludesMahr, isTrue);
    });

    testWidgets('on its own (the start): nothing is sent', (tester) async {
      final plans = _RecordingPlans(succeed: true);
      await _pump(tester, signedInPlans: plans, size: const Size(390, 1400));
      await upToMahr(tester);
      await typeMahr(tester);
      await _tap(tester, 'التالي');

      expect(
        find.text('الميزانية 7 مليون · المهر مليونين، باقي 1.5 مليون'),
        findsOneWidget,
      );
      await _tap(tester, 'افتح خطتي');
      expect(plans.request!.budgetIncludesMahr, isNull);
    });

    testWidgets('kept on the phone, the plan keeps the answer', (tester) async {
      final finance = _RecordingFinance();
      final storage = await _pump(
        tester,
        finance: finance,
        size: const Size(390, 1400),
      );
      await upToMahr(tester);
      await typeMahr(tester);
      await _tapKey(tester, 'mahr-budget-inside');
      await _tap(tester, 'التالي');
      await _tapKey(tester, 'ready-later');

      final draft = await storage.loadDraft();
      expect(draft!.budgetIncludesMahr, isTrue);
      expect(draft.mahrInsideBudget, isTrue);
      expect(finance.includesMahr, [true]);
    });

    // Seen on an Android 16 emulator: with the keyboard up after typing the
    // mahr, the choice sat under it and «التالي» left the step without it.
    testWidgets('the keyboard up: the first «التالي» shows the choice, the '
        'next goes on', (tester) async {
      final plans = _RecordingPlans(succeed: true);
      await _pump(tester, signedInPlans: plans, size: const Size(320, 900));
      await upToMahr(tester);
      await typeMahr(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      final choice = find.byKey(const ValueKey('mahr-budget-choice'));
      bool shown() {
        if (choice.evaluate().isEmpty) return false;
        final rect = tester.getRect(choice);
        final view = tester.getRect(find.byType(Scrollable).first);
        final keyboardTop = 900 - tester.view.viewInsets.bottom;
        return rect.top >= view.top - 0.5 &&
            rect.bottom <= view.bottom + 0.5 &&
            rect.bottom <= keyboardTop;
      }

      expect(shown(), isFalse, reason: 'the keyboard hides it, as seen');
      await tester.tap(find.widgetWithText(JourneyButton, 'التالي'));
      await tester.pumpAndSettle();
      // Still on the step, the choice brought into view.
      expect(find.text('خطتك جاهزة يا محمد'), findsNothing);
      expect(find.byKey(const ValueKey('mahr-total')), findsOneWidget);
      expect(shown(), isTrue);
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
      expect(shown(), isTrue);

      await tester.tap(find.widgetWithText(JourneyButton, 'التالي'));
      await tester.pumpAndSettle();
      expect(find.text('خطتك جاهزة يا محمد'), findsOneWidget);
      await _tap(tester, 'افتح خطتي');
      expect(plans.request!.budgetIncludesMahr, isNull);
    });

    testWidgets('no choice to show: «التالي» goes on at once', (tester) async {
      await _pump(tester, size: const Size(320, 900));
      await _answerUpToPlace(tester);
      await _tap(tester, 'صنعاء');
      await _tap(tester, 'أكمل بدون ميزانية');
      await typeMahr(tester);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(JourneyButton, 'التالي'));
      await tester.pumpAndSettle();
      expect(find.text('خطتك جاهزة يا محمد'), findsOneWidget);
    });

    testWidgets('a bride is never asked', (tester) async {
      await _pump(tester, size: const Size(390, 1400));
      await upToMahr(tester, persona: 'persona-bride');
      await typeMahr(tester);

      expect(find.byKey(const ValueKey('mahr-budget-choice')), findsNothing);
    });

    testWidgets('320 wide with the text at 1.3', (tester) async {
      await _pump(tester, size: const Size(320, 1600), textScale: 1.3);
      await upToMahr(tester);
      await typeMahr(tester);
      expect(find.byKey(const ValueKey('mahr-budget-choice')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('a06: a settled part over the mahr is said under it', (
    tester,
  ) async {
    await _pump(tester, signedInPlans: _RecordingPlans(succeed: true));
    await _answerUpToPlace(tester);
    await _tap(tester, 'صنعاء');
    await tester.enterText(find.byType(TextField).first, '7000000');
    await tester.pumpAndSettle();
    await _tap(tester, 'التالي');
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('mahr-total')),
        matching: find.byType(TextField),
      ),
      '1000000',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('mahr-settled')),
        matching: find.byType(TextField),
      ),
      '2000000',
    );
    await tester.pumpAndSettle();
    await _tap(tester, 'التالي');

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('mahr-settled')),
        matching: find.text('أكثر من المهر نفسه'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('mahr-total')),
        matching: find.text('أكثر من المهر نفسه'),
      ),
      findsNothing,
    );
  });

  testWidgets('a06: the bride receives her mahr, in her words', (tester) async {
    final finance = _RecordingFinance();
    final storage = await _pump(tester, finance: finance);
    await _answerUpToPlace(tester, persona: 'persona-bride', name: 'سلمى');
    await _tap(tester, 'صنعاء');
    expect(find.text('أكملي بدون ميزانية'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '7000000');
    await tester.pumpAndSettle();
    await _tap(tester, 'التالي');

    expect(
      find.text(
        'اللي بتستلمينه من العريس. نحسبه برّا الميزانية ونقول لك كم باقي.',
      ),
      findsOneWidget,
    );
    expect(find.text('استلمتِ منه'), findsOneWidget);
    // D75: the «whose wedding» note left the mahr step.
    expect(find.textContaining('عرس النساء'), findsNothing);
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('mahr-total')),
        matching: find.byType(TextField),
      ),
      '3000000',
    );
    await tester.pumpAndSettle();
    expect(find.text('موعد استلام الباقي'), findsOneWidget);
    await _tap(tester, 'التالي');
    await _tap(tester, 'بعدين، خليني أشوف أول');

    final draft = await storage.loadDraft();
    expect(draft!.mahr?.total, '3000000');
    expect(draft.mahr?.settled, '0');
  });

  // The mahr step's own lines are said to the plan's owner too: a bride
  // reads «تسمحين» and «حفظتي», never the groom's words.
  testWidgets('a06: the mahr\'s privacy line is in her words', (tester) async {
    await _pump(tester);
    await _answerUpToPlace(tester, persona: 'persona-bride', name: 'سلمى');
    await _tap(tester, 'صنعاء');
    await _tap(tester, 'أكملي بدون ميزانية');
    expect(find.text('اتفقتوا على المهر؟'), findsOneWidget);

    expect(
      find.text('أرقام المهر ما يشوفها غيرك، إلا اللي تسمحين له يشوف المال.'),
      findsOneWidget,
    );
    expect(find.textContaining('تسمح له'), findsNothing);
  });

  testWidgets('a05 groups the amount as typed and keeps whole riyals', (
    tester,
  ) async {
    await _pump(tester);
    await _answerUpToPlace(tester);

    String typed() =>
        tester.widget<TextField>(find.byType(TextField).first).controller!.text;

    await tester.enterText(find.byType(TextField).first, '7000000');
    await tester.pumpAndSettle();
    expect(typed(), '7,000,000');

    // A decimal point never turns 1500.5 into 15005 riyals. (It used to,
    // with the words under the field to notice it by; RA-MO-113: a pasted
    // «5000000.00» became five hundred million the same way. The fraction
    // goes with its point: whole riyals.)
    await tester.enterText(find.byType(TextField).first, '1500.5');
    await tester.pumpAndSettle();
    expect(typed(), '1,500');
    expect(find.text(amountInWords(1500, currency: 'ر.ي')), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '5000000.00');
    await tester.pumpAndSettle();
    expect(typed(), '5,000,000');
    expect(find.text(amountInWords(5000000, currency: 'ر.ي')), findsOneWidget);
  });

  testWidgets('a05 takes any city typed by name', (tester) async {
    await _pump(tester);
    await _answerUpToPlace(tester);

    await _tap(tester, 'مدينة ثانية');
    expect(find.text('اختر المدينة'), findsOneWidget);
    await tester.enterText(find.byType(TextField).last, '  ذمار ');
    await tester.pumpAndSettle();
    await _tap(tester, 'اختر هذي المدينة');

    expect(find.text('اختر المدينة'), findsNothing);
    await _tap(tester, 'أكمل بدون ميزانية');
    await _tap(tester, 'ما اتفقنا بعد');
    expect(find.text('عرس محمد · ذمار'), findsOneWidget);
  });

  testWidgets('a03 picks the day in the month with its Hijri date', (
    tester,
  ) async {
    await _pump(tester);
    await _tapKey(tester, 'door-plan');
    await _tapKey(tester, 'persona-groom');
    await tester.enterText(find.byType(TextField).first, 'محمد');
    await tester.pumpAndSettle();

    final now = appNow();
    final month = DateTime(now.year, now.month + 2);
    await _tap(tester, arabicMonthName(month.month));
    expect(
      find.text('يوم العرس في ${arabicMonthName(month.month)} ${month.year}'),
      findsOneWidget,
    );

    final day = DateTime(month.year, month.month, 15);
    await _pickDay(tester, day);

    _expectDayField(tester, day);
    await _tap(tester, 'التالي');
    expect(find.text('فين العرس، وكم ميزانيتك تقريبًا؟'), findsOneWidget);
  });

  testWidgets('a03 «موعدنا بعد» opens the eighteen later months', (
    tester,
  ) async {
    await _pump(tester);
    await _tapKey(tester, 'door-plan');
    await _tapKey(tester, 'persona-groom');
    await tester.enterText(find.byType(TextField).first, 'محمد');
    await tester.pumpAndSettle();

    final now = appNow();
    final lastOnScreen = DateTime(now.year, now.month + 5);
    await _tap(tester, 'موعدنا بعد ${arabicMonthName(lastOnScreen.month)}');
    expect(find.text('اختر شهر العرس'), findsOneWidget);
    for (final i in [6, 23]) {
      final month = DateTime(now.year, now.month + i);
      expect(
        find.text('${arabicMonthName(month.month)} ${month.year}'),
        findsOneWidget,
      );
    }
    final beyond = DateTime(now.year, now.month + 24);
    expect(
      find.text('${arabicMonthName(beyond.month)} ${beyond.year}'),
      findsNothing,
    );

    final month = DateTime(now.year, now.month + 8);
    await _tap(tester, '${arabicMonthName(month.month)} ${month.year}');
    expect(
      find.text('يوم العرس في ${arabicMonthName(month.month)} ${month.year}'),
      findsOneWidget,
    );
    final day = DateTime(month.year, month.month, 15);
    await _pickDay(tester, day);

    // The cell now names the chosen month.
    expect(
      find.text('${arabicMonthName(month.month)} ${month.year}'),
      findsOneWidget,
    );
    _expectDayField(tester, day);
  });

  testWidgets('a08 keeps the plan on the phone with its starting items', (
    tester,
  ) async {
    final finance = _RecordingFinance();
    final storage = await _pump(tester, finance: finance);
    await _answerUpToReady(tester);

    expect(find.text('خطتك جاهزة يا محمد'), findsOneWidget);
    expect(find.text('عرس محمد · صنعاء'), findsOneWidget);
    expect(find.text('الميزانية 7 مليون'), findsOneWidget);
    expect(find.textContaining('بند لعرسك'), findsOneWidget);
    // This plan has no date yet (x01), so nothing claims to sit on one.
    expect(find.textContaining('مقترحة'), findsOneWidget);
    expect(find.textContaining('على موعدك'), findsNothing);
    expect(find.textContaining('ترتبها لما تحدد الموعد'), findsOneWidget);
    // No directory to ask: the city without a number.
    expect(find.text('مزودين صنعاء'), findsOneWidget);
    // Looking first says what it risks.
    expect(find.textContaining('خطتك الحين على هذا الجوال بس'), findsOneWidget);
    expect(find.text('احفظ خطتي برقم جوالي'), findsOneWidget);

    await _tapKey(tester, 'ready-later');
    expect(find.text('opened:/home'), findsOneWidget);

    final GuestOnboardingDraft? draft = await storage.loadDraft();
    expect(draft, isNotNull);
    expect(draft!.planName, 'عرس محمد');
    expect(draft.city, 'صنعاء');
    expect(draft.weddingDate, isNull);
    expect(draft.weddingDateUnknown, isTrue);
    expect(draft.estimatedBudget, '7000000');
    expect(draft.currency, 'YER');
    expect(draft.isCompleteGuestPlan, isTrue);
    // C1: the plan starts with its wedding items, never the mahr.
    expect(draft.selectedCategoryKeys, isNotEmpty);
    expect(draft.selectedCategoryKeys, isNot(contains('المهر والاتفاقات')));
    // The items a05 promised are in the plan's money from the start, so
    // «المال» opens on them and never on an empty setup screen.
    expect(finance.planIds, [draft.guestPlanId]);
    expect(finance.budgets, ['7000000']);
    expect(finance.names, draft.selectedCategoryKeys);
  });

  testWidgets('a08 counts the city\'s providers from the directory', (
    tester,
  ) async {
    final marketplace = _CountingMarketplace(total: 12);
    await _pump(tester, marketplace: marketplace);
    await _answerUpToReady(tester);

    expect(find.text('12 مزود في صنعاء'), findsOneWidget);
    expect(marketplace.askedCityIds, ['city-sanaa']);
  });

  testWidgets('a08 says a city typed by hand has no providers yet, online', (
    tester,
  ) async {
    final marketplace = _CountingMarketplace(total: 12);
    await _pump(tester, marketplace: marketplace);
    await _answerUpToPlace(tester);
    await _tap(tester, 'مدينة ثانية');
    await tester.enterText(find.byType(TextField).last, 'ذمار');
    await tester.pumpAndSettle();
    await _tap(tester, 'اختر هذي المدينة');
    await _tap(tester, 'أكمل بدون ميزانية');
    await _tap(tester, 'ما اتفقنا بعد');

    // The directory answered and has no such city: a real «none yet», not
    // a promise for when the internet is back.
    expect(
      find.text('ما في مزودين في ذمار بعد. نضيفهم أول ما ينضمون.'),
      findsOneWidget,
    );
    expect(find.textContaining('أول ما يرجع النت'), findsNothing);
    expect(marketplace.askedCityIds, isEmpty);
  });

  testWidgets('a08 says when the city has no providers yet', (tester) async {
    await _pump(tester, marketplace: _CountingMarketplace(total: 0));
    await _answerUpToReady(tester);

    expect(find.text('مزودين صنعاء'), findsOneWidget);
    expect(
      find.text('ما في مزودين في صنعاء بعد. نضيفهم أول ما ينضمون.'),
      findsOneWidget,
    );
  });

  testWidgets('a08 stays and says so when the phone cannot save the plan', (
    tester,
  ) async {
    final storage = await _pump(tester, finance: _RecordingFinance(fail: true));
    await _answerUpToReady(tester);

    await _tapKey(tester, 'ready-later');

    expect(find.text('opened:/home'), findsNothing);
    expect(
      find.text('ما قدرنا نحفظ الخطة على جوالك. جرّب مرة ثانية.'),
      findsOneWidget,
    );
    expect(await storage.loadDraft(), isNull);
  });

  testWidgets('saving with the phone number opens register over the plan', (
    tester,
  ) async {
    final storage = await _pump(tester);
    await _answerUpToReady(tester);
    await _tapKey(tester, 'ready-save');
    expect(find.text('opened:/register'), findsOneWidget);
    expect(await storage.loadDraft(), isNotNull);

    // Pushed over «جاهزة»: back returns to it with every answer.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('خطتك جاهزة يا محمد'), findsOneWidget);
  });

  testWidgets('signed in, «افتح خطتي» creates the plan on the server', (
    tester,
  ) async {
    final plans = _RecordingPlans(succeed: true);
    final storage = await _pump(tester, signedInPlans: plans);
    await _answerUpToReady(tester);
    expect(find.text('احفظ خطتي برقم جوالي'), findsNothing);
    expect(find.byKey(const ValueKey('ready-later')), findsNothing);

    await _tap(tester, 'افتح خطتي');
    expect(find.text('opened:/home'), findsOneWidget);
    final request = plans.request!;
    expect(request.title, 'عرس محمد');
    expect(request.persona, 'GROOM');
    expect(request.city, 'صنعاء');
    expect(request.weddingDate, isNull);
    expect(request.estimatedBudget, '7000000');
    expect(request.currency, 'YER');
    expect(request.selectedCategories, isNotEmpty);
    expect(await storage.loadDraft(), isNull);
  });

  // RA-MO-360: the first plan made is the reason to say what the alerts are
  // for; a plan that was not made is not.
  Future<PushNotificationsController> signedInPush() async {
    final preferences = await SharedPreferences.getInstance();
    final push = PushNotificationsController(
      preferences: preferences,
      gateway: _AskingGateway(),
      registrationApi: _NoRegistry(),
    );
    addTearDown(push.dispose);
    await push.initialize();
    await push.bindAuthenticatedUser('user-1');
    return push;
  }

  testWidgets('signed in, the plan made is the moment to say what the alerts '
      'are for', (tester) async {
    final push = await signedInPush();
    await _pump(
      tester,
      signedInPlans: _RecordingPlans(succeed: true),
      push: push,
    );
    await _answerUpToReady(tester);
    expect(push.hasPendingPermissionExplanation, isFalse);

    await _tap(tester, 'افتح خطتي');
    await tester.pump();

    expect(find.text('opened:/home'), findsOneWidget);
    expect(push.hasPendingPermissionExplanation, isTrue);
  });

  testWidgets('signed in, a plan that was not made says nothing of alerts', (
    tester,
  ) async {
    final push = await signedInPush();
    await _pump(
      tester,
      signedInPlans: _RecordingPlans(succeed: false),
      push: push,
    );
    await _answerUpToReady(tester);

    await _tap(tester, 'افتح خطتي');
    await tester.pump();

    expect(push.hasPendingPermissionExplanation, isFalse);
  });

  // RA-MO-124: the day went as a time with no zone, which the server read in
  // its own zone; it goes as the day, as every plan day does.
  testWidgets('signed in, the wedding day reaches the server as a day', (
    tester,
  ) async {
    final plans = _RecordingPlans(succeed: true);
    await _pump(tester, signedInPlans: plans);
    await _tapKey(tester, 'door-plan');
    await _tapKey(tester, 'persona-groom');
    await tester.enterText(find.byType(TextField).first, 'محمد');
    await tester.pumpAndSettle();
    final now = appNow();
    final month = DateTime(now.year, now.month + 2);
    await _tap(tester, arabicMonthName(month.month));
    final day = DateTime(month.year, month.month, 15);
    await _pickDay(tester, day);
    await _tap(tester, 'التالي');
    await _tap(tester, 'صنعاء');
    await tester.enterText(find.byType(TextField).first, '7000000');
    await tester.pumpAndSettle();
    await _tap(tester, 'التالي');
    await _tap(tester, 'ما اتفقنا بعد');
    await _tap(tester, 'افتح خطتي');

    final sent = plans.request!.weddingDate;
    expect(sent, planDayToJson(day));
    expect(sent, isNot(contains('T')));
  });

  testWidgets('signed in, a failed save stays and says so', (tester) async {
    final plans = _RecordingPlans(succeed: false);
    await _pump(tester, signedInPlans: plans);
    await _answerUpToReady(tester);
    await _tap(tester, 'افتح خطتي');
    expect(find.text('خطتك جاهزة يا محمد'), findsOneWidget);
    expect(find.text('تعذر إنشاء خطتك.'), findsOneWidget);

    // RA-BE-71: trying the same plan again is the same plan to the server.
    await _tap(tester, 'افتح خطتي');
    expect(plans.keys, hasLength(2));
    expect(plans.keys.toSet(), hasLength(1));
  });

  // w11 «خطة جديدة» makes another plan with the designed steps, from
  // «أنت العريس ولا العروسة؟»: the door offers signing in and the provider
  // path.
  testWidgets('a new plan starts at the groom or the bride and is made on the '
      'server', (tester) async {
    final plans = _RecordingPlans(succeed: true);
    await _pump(
      tester,
      signedInPlans: plans,
      initialLocation: '/wedding-plans/create',
    );
    expect(find.text('أهلًا فيك، من فين نبدأ؟'), findsNothing);
    expect(find.byKey(const ValueKey('door-login')), findsNothing);
    expect(find.text('أنت العريس ولا العروسة؟'), findsOneWidget);

    await _tapKey(tester, 'persona-groom');
    await tester.enterText(find.byType(TextField).first, 'محمد');
    await tester.pumpAndSettle();
    await _tap(tester, 'ما حددنا الموعد بعد');
    await _tap(tester, 'صنعاء');
    await tester.enterText(find.byType(TextField).first, '7000000');
    await tester.pumpAndSettle();
    await _tap(tester, 'التالي');
    await _tap(tester, 'ما اتفقنا بعد');
    await _tap(tester, 'افتح خطتي');

    expect(find.text('opened:/home'), findsOneWidget);
    expect(plans.request!.title, 'عرس محمد');
    // «ما اتفقنا بعد»: the plan goes without a mahr.
    expect(plans.request!.mahr, isNull);
  });

  testWidgets('back on a new plan\'s first step leaves the steps', (
    tester,
  ) async {
    await _pump(
      tester,
      signedInPlans: _RecordingPlans(succeed: true),
      initialLocation: '/wedding-plans/create',
    );
    await tester.tap(find.byTooltip('رجوع').first);
    await tester.pumpAndSettle();
    expect(find.text('opened:/home'), findsOneWidget);
  });

  testWidgets('the phone\'s back key walks the steps and keeps the answers', (
    tester,
  ) async {
    await _pump(tester);
    await _answerUpToReady(tester);
    expect(find.text('ايش اسمك، ومتى العرس؟'), findsNothing);

    // a08 → a06 → a05 → a03, the same path as the arrow.
    for (var i = 0; i < 2; i++) {
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
    }
    expect(find.text('فين العرس، وكم ميزانيتك تقريبًا؟'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('ايش اسمك، ومتى العرس؟'), findsOneWidget);
    // The name typed on a03 is still there.
    expect(find.text('محمد'), findsWidgets);
  });

  testWidgets('the back key on a new plan\'s later step stays on the page', (
    tester,
  ) async {
    await _pump(
      tester,
      signedInPlans: _RecordingPlans(succeed: true),
      initialLocation: '/wedding-plans/create',
    );
    await _tapKey(tester, 'persona-groom');
    expect(find.text('ايش اسمك، ومتى العرس؟'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('أنت العريس ولا العروسة؟'), findsOneWidget);
    expect(find.text('opened:/home'), findsNothing);
  });

  testWidgets('every step fits 320 px with doubled text', (tester) async {
    await _pump(tester, size: const Size(320, 1400), textScale: 2);
    expect(tester.takeException(), isNull);
    await _tapKey(tester, 'door-plan');
    expect(tester.takeException(), isNull);
    await _tapKey(tester, 'persona-groom');
    await tester.enterText(find.byType(TextField).first, 'عبدالرحمن');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _tap(tester, 'ما حددنا الموعد بعد');
    expect(tester.takeException(), isNull);
    await _tap(tester, 'صنعاء');
    await _tap(tester, 'أكمل بدون ميزانية');
    expect(find.text('اتفقتوا على المهر؟'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _tap(tester, 'ما اتفقنا بعد');
    expect(find.text('خطتك جاهزة يا عبدالرحمن'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // J1-02: every answered step is kept on the phone, so a closed app
  // resumes where it stopped, from the door.
  testWidgets('J1-02: a closed app resumes the steps with the name and day', (
    tester,
  ) async {
    await _pump(tester);
    await _tapKey(tester, 'door-plan');
    await _tapKey(tester, 'persona-bride');
    await tester.enterText(find.byType(TextField).first, 'سلمى');
    await tester.pumpAndSettle();
    final now = appNow();
    final month = DateTime(now.year, now.month + 2);
    await _tap(tester, arabicMonthName(month.month));
    final day = DateTime(month.year, month.month, 15);
    await _pickDay(tester, day);
    await _tap(tester, 'التالي');
    expect(find.text('فين العرس، وكم ميزانيتك تقريبًا؟'), findsOneWidget);

    // The app closes and opens again on the same phone.
    await tester.pumpWidget(const SizedBox.shrink());
    await _pump(tester);

    expect(find.text('كمّل خطتي'), findsOneWidget);
    expect(find.text('عرس سلمى، من حيث وقفتي'), findsOneWidget);
    await _tapKey(tester, 'door-plan');
    expect(find.text('فين العرس، وكم ميزانيتك تقريبًا؟'), findsOneWidget);
    // Still her plan, in her words.
    expect(find.text('أكملي بدون ميزانية'), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('ايش اسمك، ومتى العرس؟'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'سلمى',
    );
    _expectDayField(tester, day);
  });

  testWidgets('J1-02: «جاهزة» keeps the plan on the phone as it opens', (
    tester,
  ) async {
    final finance = _RecordingFinance();
    final storage = await _pump(tester, finance: finance);
    await _answerUpToReady(tester);

    // No button tapped: the note «خطتك الحين على هذا الجوال» is already true.
    expect(find.textContaining('خطتك الحين على هذا الجوال بس'), findsOneWidget);
    final draft = await storage.loadDraft();
    expect(draft?.isCompleteGuestPlan, isTrue);
    expect(draft!.planName, 'عرس محمد');
    expect(finance.planIds, [draft.guestPlanId]);
    // The answers on the way there gave way to the plan.
    expect(await storage.loadProgress(), isNull);
  });

  // RA-MO-114: what was typed in a step was kept only as the step was left;
  // the system closing the app in the background lost it.
  testWidgets('going to the background keeps what was typed in a step', (
    tester,
  ) async {
    final storage = await _pump(tester);
    await _tapKey(tester, 'door-plan');
    await _tapKey(tester, 'persona-groom');
    await tester.enterText(find.byType(TextField).first, 'سالم');
    await tester.pumpAndSettle();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    await tester.pump();

    final progress = await storage.loadProgress();
    expect(progress?.draft.planName, 'عرس سالم');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });

  testWidgets('J1-02: saving with the number after that keeps the one plan', (
    tester,
  ) async {
    final finance = _RecordingFinance();
    final storage = await _pump(tester, finance: finance);
    await _answerUpToReady(tester);
    final kept = (await storage.loadDraft())!.guestPlanId;

    await _tapKey(tester, 'ready-save');
    expect(find.text('opened:/register'), findsOneWidget);
    expect(finance.planIds, [kept]);
    expect((await storage.loadDraft())!.guestPlanId, kept);

    // Back on «جاهزة», a changed answer is kept on the same plan.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('اتفقتوا على المهر؟'), findsOneWidget);
    await _tap(tester, 'ما اتفقنا بعد');
    expect(finance.planIds, [kept, kept]);
    expect((await storage.loadDraft())!.guestPlanId, kept);
  });

  testWidgets('J1-14: a city picked from «مدينة ثانية» clears the warning', (
    tester,
  ) async {
    await _pump(tester);
    await _answerUpToPlace(tester);
    await _tap(tester, 'أكمل بدون ميزانية');
    expect(find.text('اختر المدينة أول'), findsOneWidget);

    await _tap(tester, 'مدينة ثانية');
    await tester.enterText(find.byType(TextField).last, 'ذمار');
    await tester.pumpAndSettle();
    await _tap(tester, 'اختر هذي المدينة');

    expect(find.text('ذمار'), findsOneWidget);
    expect(find.text('اختر المدينة أول'), findsNothing);
  });

  testWidgets('J1-18: a waiting «التالي» says what it waits for', (
    tester,
  ) async {
    await _pump(tester);
    await _tapKey(tester, 'door-plan');
    await _tapKey(tester, 'persona-groom');

    expect(_button(tester, 'التالي').onPressed, isNull);
    expect(find.text('اكتب اسمك واختر الشهر'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'محمد');
    await tester.pumpAndSettle();
    expect(find.text('اكتب اسمك واختر الشهر'), findsNothing);
    expect(find.text('اختر الشهر'), findsOneWidget);

    final now = appNow();
    final month = DateTime(now.year, now.month + 2);
    await _tap(tester, arabicMonthName(month.month));
    await _pickDay(tester, DateTime(month.year, month.month, 15));
    expect(_button(tester, 'التالي').onPressed, isNotNull);
    expect(find.text('اختر الشهر'), findsNothing);

    await _tap(tester, 'التالي');
    expect(find.text('اختر المدينة واكتب الميزانية'), findsOneWidget);
    await _tap(tester, 'صنعاء');
    expect(find.text('اكتب الميزانية'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, '7000000');
    await tester.pumpAndSettle();
    expect(_button(tester, 'التالي').onPressed, isNotNull);
    expect(find.text('اكتب الميزانية'), findsNothing);
  });

  testWidgets('J1-18: the bride reads what is missing in her words', (
    tester,
  ) async {
    await _pump(tester);
    await _tapKey(tester, 'door-plan');
    await _tapKey(tester, 'persona-bride');
    expect(find.text('اكتبي اسمك واختاري الشهر'), findsOneWidget);
    await tester.enterText(find.byType(TextField).first, 'سلمى');
    await tester.pumpAndSettle();
    await _tap(tester, 'ما حددنا الموعد بعد');
    expect(find.text('اختاري المدينة واكتبي الميزانية'), findsOneWidget);
  });

  // D112 (Q-16), the owner's word: progress kept from an unfinished start
  // stays, and a wedding day that has passed since is dropped from it. It
  // used to come back as it was, a plan dated in the past (RA-MO-121).
  testWidgets('progress kept with a day now past comes back without the day, '
      'at the step that asks for it', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    final today = appNow();
    await GuestOnboardingStorage(preferences).saveProgress(
      GuestOnboardingDraft.quickLocalPlanSetup(
        planName: 'عرس سامي',
        persona: GuestPersona.groom,
        location: WeddingLocationDraft.fromLegacyFields(
          governorate: 'صنعاء',
          city: 'صنعاء',
        ),
        weddingDate: DateTime(today.year, today.month, today.day - 20),
        currency: 'YER',
      ),
      step: 'mahr',
    );
    await _pump(tester);

    expect(find.text('كمّل خطتي'), findsOneWidget);
    await _tapKey(tester, 'door-plan');

    // Back at the name and the day, with the name kept and no day chosen.
    expect(find.text('ايش اسمك، ومتى العرس؟'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField).first).controller!.text,
      'سامي',
    );
    expect(find.text('اتفقتوا على المهر؟'), findsNothing);
  });

  // J1-16: only the groom's rest of the mahr becomes a payment the server
  // reminds of; the bride is promised no reminder.
  testWidgets('J1-16: the mahr\'s reminder is promised to the groom only', (
    tester,
  ) async {
    Future<void> openMahr(GuestPersona persona) async {
      final preferences = await SharedPreferences.getInstance();
      await GuestOnboardingStorage(preferences).saveProgress(
        GuestOnboardingDraft.quickLocalPlanSetup(
          planName: 'عرس سلمى',
          persona: persona,
          location: WeddingLocationDraft.fromLegacyFields(
            governorate: 'صنعاء',
            city: 'صنعاء',
          ),
          weddingDate: null,
          currency: 'YER',
          mahr: DraftMahr(
            total: '3000000',
            remainingDueDate: DateTime(appNow().year + 1, 3, 1),
          ),
        ),
        step: 'mahr',
      );
      await _pump(tester);
      await _tapKey(tester, 'door-plan');
      expect(find.text('اتفقتوا على المهر؟'), findsOneWidget);
    }

    await openMahr(GuestPersona.bride);
    expect(find.textContaining('نذكّر'), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await openMahr(GuestPersona.groom);
    expect(find.textContaining('نذكّرك قبل الموعد'), findsOneWidget);
  });

  testWidgets('J1-09: the name stops at the account\'s 120 letters', (
    tester,
  ) async {
    await _pump(tester);
    await _tapKey(tester, 'door-plan');
    await _tapKey(tester, 'persona-groom');
    await tester.enterText(find.byType(TextField).first, 'م' * 130);
    await tester.pumpAndSettle();

    expect(
      tester
          .widget<TextField>(find.byType(TextField).first)
          .controller!
          .text
          .length,
      120,
    );
    // No counter under the field.
    expect(find.text('120/120'), findsNothing);
  });
}

/// Picks [day] in the open day sheet by its spoken label.
Future<void> _pickDay(WidgetTester tester, DateTime day) async {
  final hijri = HijriDate.fromGregorian(day)!;
  await tester.tap(
    find.bySemanticsLabel(
      RegExp('^${formatArabicWeekdayDayMonth(day)}، ${hijri.dayAndMonth}'),
    ),
  );
  await tester.pumpAndSettle();
}

/// «يوم العرس»: the day with its year, the Hijri date under it, and the
/// Ramadan word when it is close.
void _expectDayField(WidgetTester tester, DateTime day) {
  final hijri = HijriDate.fromGregorian(day)!;
  expect(find.text('يوم العرس'), findsOneWidget);
  expect(
    find.text('${formatArabicWeekdayDayMonth(day)} ${day.year}'),
    findsOneWidget,
  );
  expect(find.text(hijri.full), findsOneWidget);
  final ramadan = HijriDate.ramadanOnOrAfter(day);
  final before = ramadan?.$1
      .difference(DateTime.utc(day.year, day.month, day.day))
      .inDays;
  expect(
    find.textContaining('عرسك قبل رمضان بـ', skipOffstage: false),
    before != null && before > 0 && before <= 60
        ? findsOneWidget
        : findsNothing,
  );
}

/// The provider directory: the cities and one city's provider count.
class _CountingMarketplace extends MarketplaceApi {
  _CountingMarketplace({required this.total})
    : super(ApiClient(tokenProvider: () async => null));

  final int total;
  final askedCityIds = <String?>[];

  @override
  Future<List<MarketplaceCity>> getCities() async => const [
    MarketplaceCity(id: 'city-sanaa', nameAr: 'صنعاء'),
    MarketplaceCity(id: 'city-aden', nameAr: 'عدن'),
  ];

  @override
  Future<MarketplaceProviderPage> getProvidersPage({
    String? search,
    String? cityId,
    String? categoryId,
    List<String>? categoryIds,
    bool? featured,
    DateTime? eventDate,
    int page = 1,
    int limit = 30,
  }) async {
    askedCityIds.add(cityId);
    return MarketplaceProviderPage(
      items: const [],
      currentPage: 1,
      total: total,
      totalPages: 1,
      hasMore: false,
    );
  }
}

class _RecordingFinance extends FinanceApi {
  _RecordingFinance({this.fail = false})
    : super(ApiClient(tokenProvider: () async => null));

  final bool fail;
  final planIds = <String>[];
  final budgets = <String?>[];
  final names = <String>[];
  final includesMahr = <bool?>[];

  @override
  Future<MoneyBudgetReplaceResult> replaceMoneyBudget({
    required String planId,
    required String? totalBudget,
    required String currency,
    required List<({String? id, String name, String? allocatedAmount})>
    categories,
    String? expectedBudgetVersion,
    bool? budgetIncludesMahr,
  }) async {
    if (fail) throw StateError('disk full');
    planIds.add(planId);
    budgets.add(totalBudget);
    includesMahr.add(budgetIncludesMahr);
    names.addAll([for (final category in categories) category.name]);
    return MoneyBudgetReplaceResult(
      summary: MoneySummary.empty(planId),
      categories: const [],
      idMap: const {},
    );
  }
}

class _AskingGateway implements PushMessagingGateway {
  @override
  bool get isAvailable => true;

  @override
  Stream<void> get tokenChanges => const Stream<void>.empty();

  @override
  Stream<PushNotificationTap> get notificationTaps =>
      const Stream<PushNotificationTap>.empty();

  @override
  Stream<PushForegroundNotification> get foregroundNotifications =>
      const Stream<PushForegroundNotification>.empty();

  @override
  Future<void> initialize() async {}

  @override
  Future<PushAuthorizationStatus> authorizationStatus() async =>
      PushAuthorizationStatus.notDetermined;

  @override
  Future<PushAuthorizationStatus> requestPermission() async =>
      PushAuthorizationStatus.authorized;

  @override
  Future<String> ensureRegistrationAndGetInstallationId() async => 'fid-1';

  @override
  Future<PushNotificationTap?> consumeInitialNotificationTap() async => null;
}

class _NoRegistry implements PushInstallationRegistry {
  @override
  Future<void> registerAndroid(String fid, {CancelToken? cancelToken}) async {}

  @override
  Future<void> unregisterAndroid(
    String fid, {
    CancelToken? cancelToken,
    String? bearerToken,
  }) async {}
}

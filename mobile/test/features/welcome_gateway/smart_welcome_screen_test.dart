import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/onboarding_complete.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:aarast_mobile/features/welcome_gateway/screens/smart_welcome_screen.dart';

// The redesigned start (prototype a02 to a08): one question per screen,
// the plan kept on the phone, and the account asked for only on saving.

GoRouter _router() => GoRouter(
  initialLocation: '/welcome',
  routes: [
    GoRoute(
      path: '/welcome',
      builder: (context, state) => const SmartWelcomeScreen(),
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
        builder: (context, state) => Scaffold(body: Text('opened:$route')),
      ),
  ],
);

class _SignedIn extends AuthController {
  _SignedIn(super.authRepository);

  @override
  AuthStatus get status => AuthStatus.authenticated;
}

/// Records the plan the screen asks for; answers like the server would.
class _RecordingPlans extends WeddingPlansProvider {
  _RecordingPlans({required this.succeed})
    : super(WeddingPlansApi(ApiClient(tokenProvider: () async => null)));

  final bool succeed;
  OnboardingCompleteRequest? request;

  @override
  String? get errorMessage => succeed ? null : 'تعذر إنشاء خطتك.';

  @override
  Future<OnboardingCompleteResponse?> completeOnboarding(
    OnboardingCompleteRequest request,
  ) async {
    this.request = request;
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
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  final preferences = await SharedPreferences.getInstance();
  final storage = GuestOnboardingStorage(preferences);
  final authStorage = AuthStorage(preferences);
  final apiClient = ApiClient(tokenProvider: () async => null);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<AuthStorage>.value(value: authStorage),
        Provider<GuestOnboardingStorage>.value(value: storage),
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
        routerConfig: _router(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
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

Future<void> _answerUpToReady(WidgetTester tester) async {
  await _tap(tester, 'ابدأ');
  await _tap(tester, 'التالي');
  await tester.enterText(find.byType(TextField).first, 'محمد');
  await tester.pumpAndSettle();
  await _tap(tester, 'ما حددنا الموعد بعد');
  await _tap(tester, 'التالي');
  await _tap(tester, 'صنعاء');
  await tester.enterText(find.byType(TextField).first, '7000000');
  await tester.pumpAndSettle();
  await _tap(tester, 'جهّز خطتي');
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('a02 offers a plan or a service, sign in and invitations', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('أهلًا فيك'), findsOneWidget);
    expect(find.text('أنشئ خطتك'), findsOneWidget);
    expect(find.text('مزود خدمة'), findsOneWidget);
    expect(find.text('عندي حساب'), findsOneWidget);
    expect(find.text('عندي رابط دعوة'), findsOneWidget);
    expect(find.text('ابدأ'), findsOneWidget);
    // C52: no account is promised before there is a plan.
    expect(find.text('أنشئ حسابي'), findsNothing);
  });

  testWidgets('the provider choice opens provider apply', (tester) async {
    await _pump(tester);
    await _tap(tester, 'مزود خدمة');
    await _tap(tester, 'ابدأ');
    expect(find.text('opened:/provider/apply'), findsOneWidget);
  });

  testWidgets('sign in and invitation open their own routes', (tester) async {
    await _pump(tester);
    await _tap(tester, 'عندي رابط دعوة');
    expect(find.text('opened:/invites'), findsOneWidget);
  });

  testWidgets('عندي حساب opens sign in', (tester) async {
    await _pump(tester);
    await _tap(tester, 'عندي حساب');
    expect(find.text('opened:/login'), findsOneWidget);
  });

  testWidgets('a02b asks whose plan, the groom chosen by default', (
    tester,
  ) async {
    await _pump(tester);
    await _tap(tester, 'ابدأ');
    expect(find.text('خطة مين؟'), findsOneWidget);
    expect(find.text('العريس'), findsOneWidget);
    expect(find.text('العروسة'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('العريس')),
      isSemantics(isSelected: true, isButton: true),
    );
    expect(
      tester.getSemantics(find.text('العروسة')),
      isSemantics(isSelected: false, isButton: true),
    );
  });

  testWidgets('a03 waits for a name and a day or «ما حددنا الموعد بعد»', (
    tester,
  ) async {
    await _pump(tester);
    await _tap(tester, 'ابدأ');
    await _tap(tester, 'التالي');
    expect(find.text('أهلًا بك! ايش اسمك، ومتى العرس؟'), findsOneWidget);
    expect(find.text('1 من 2'), findsOneWidget);

    await _tap(tester, 'التالي');
    expect(find.text('أهلًا بك! ايش اسمك، ومتى العرس؟'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'محمد');
    await tester.pumpAndSettle();
    expect(
      find.text('خطتك بتكون: عرس محمد', findRichText: true),
      findsOneWidget,
    );
    await _tap(tester, 'التالي');
    expect(find.text('وين العرس، وكم ميزانيتك تقريبًا؟'), findsNothing);

    await _tap(tester, 'ما حددنا الموعد بعد');
    await _tap(tester, 'التالي');
    expect(find.text('وين العرس، وكم ميزانيتك تقريبًا؟'), findsOneWidget);
    expect(find.text('2 من 2'), findsOneWidget);
  });

  testWidgets('a05 spells the budget and needs a city', (tester) async {
    await _pump(tester);
    await _tap(tester, 'ابدأ');
    await _tap(tester, 'التالي');
    await tester.enterText(find.byType(TextField).first, 'محمد');
    await tester.pumpAndSettle();
    await _tap(tester, 'ما حددنا الموعد بعد');
    await _tap(tester, 'التالي');

    await tester.enterText(find.byType(TextField).first, '7000000');
    await tester.pumpAndSettle();
    expect(find.text('سبعة مليون ريال'), findsOneWidget);
    await _tap(tester, 'جهّز خطتي');
    expect(find.textContaining('خطتك جاهزة'), findsNothing);

    await _tap(tester, 'صنعاء');
    await _tap(tester, 'جهّز خطتي');
    expect(find.text('خطتك جاهزة يا محمد'), findsOneWidget);
  });

  testWidgets('a08 keeps the plan on the phone with its starting items', (
    tester,
  ) async {
    final storage = await _pump(tester);
    await _answerUpToReady(tester);

    expect(find.text('خطتك جاهزة يا محمد'), findsOneWidget);
    expect(find.text('عرس محمد · صنعاء'), findsOneWidget);
    expect(find.textContaining('بند لعرسك'), findsOneWidget);
    expect(find.textContaining('مهمة مقترحة على موعدك'), findsOneWidget);
    expect(find.text('مزودين صنعاء بأسعارهم'), findsOneWidget);

    await _tap(tester, 'بعدين، خلني أشوف أول');
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
  });

  testWidgets('saving with the phone number opens register', (tester) async {
    await _pump(tester);
    await _answerUpToReady(tester);
    await _tap(tester, 'احفظ خطتي برقم جوالي');
    expect(find.text('opened:/register'), findsOneWidget);
  });

  testWidgets('signed in, «افتح خطتي» creates the plan on the server', (
    tester,
  ) async {
    final plans = _RecordingPlans(succeed: true);
    final storage = await _pump(tester, signedInPlans: plans);
    await _answerUpToReady(tester);
    expect(find.text('احفظ خطتي برقم جوالي'), findsNothing);

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

  testWidgets('signed in, a failed save stays and says so', (tester) async {
    final plans = _RecordingPlans(succeed: false);
    await _pump(tester, signedInPlans: plans);
    await _answerUpToReady(tester);
    await _tap(tester, 'افتح خطتي');
    expect(find.text('خطتك جاهزة يا محمد'), findsOneWidget);
    expect(find.text('تعذر إنشاء خطتك.'), findsOneWidget);
  });

  testWidgets('every step fits 320 px with doubled text', (tester) async {
    await _pump(tester, size: const Size(320, 1400), textScale: 2);
    expect(tester.takeException(), isNull);
    await _tap(tester, 'ابدأ');
    expect(tester.takeException(), isNull);
    await _tap(tester, 'التالي');
    await tester.enterText(find.byType(TextField).first, 'عبدالرحمن');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await _tap(tester, 'ما حددنا الموعد بعد');
    await _tap(tester, 'التالي');
    expect(tester.takeException(), isNull);
    await _tap(tester, 'صنعاء');
    await _tap(tester, 'أكمل بدون ميزانية');
    await _tap(tester, 'جهّز خطتي');
    expect(find.text('خطتك جاهزة يا عبدالرحمن'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

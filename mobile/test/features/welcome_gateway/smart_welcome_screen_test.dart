import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/welcome_gateway/screens/smart_welcome_screen.dart';
import 'package:aarast_mobile/features/wedding_plans/widgets/wedding_plan_creation_form.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Smart Welcome Gateway renders correctly', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>(create: (_) => AuthStorage(preferences)),
          Provider<GuestOnboardingStorage>(
            create: (_) => GuestOnboardingStorage(preferences),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SmartWelcomeScreen())),
      ),
    );

    expect(find.text('اختر المسار المناسب لك'), findsOneWidget);
    expect(find.text('إنشاء خطتك'), findsOneWidget);
    expect(find.text('وصلتني دعوة لخطة'), findsOneWidget);
    expect(find.text('أنا مزود خدمة'), findsOneWidget);
    expect(find.text('لديك حساب؟'), findsOneWidget);
    expect(find.text('تسجيل الدخول'), findsOneWidget);
  });

  testWidgets('Organizer path shows role selection', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>(create: (_) => AuthStorage(preferences)),
          Provider<GuestOnboardingStorage>(
            create: (_) => GuestOnboardingStorage(preferences),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SmartWelcomeScreen())),
      ),
    );

    await tester.tap(find.text('إنشاء خطتك'));
    await tester.pumpAndSettle();

    // ترويسة الخطوة هي المصدر الوحيد للعنوان — لا عنوان مكرّر في جسم الخطوة.
    expect(find.text('دورك يحدد التفاصيل'), findsOneWidget);
    expect(
      find.text('اختيار بسيط يساعدنا نرتب التجربة لك بوضوح.'),
      findsOneWidget,
    );
    expect(find.text('خلنا نتعرف عليك'), findsNothing);
    expect(find.text('العريس'), findsOneWidget);
    expect(find.text('أتابع الخطة والميزانية'), findsOneWidget);
    expect(find.text('العروسة'), findsOneWidget);
    expect(find.text('أرتب التفاصيل والاختيارات'), findsOneWidget);
    expect(find.text('مساهم / مشارك في الخطة'), findsNothing);
    expect(find.text('أساعد في التنظيم والمتابعة'), findsNothing);
    expect(find.text('خلّينا نجهز أساس خطتك'), findsNothing);
  });

  testWidgets('Provider path opens provider apply route', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/welcome',
      routes: [
        GoRoute(
          path: '/welcome',
          builder: (context, state) => const SmartWelcomeScreen(),
        ),
        GoRoute(
          path: '/provider/apply',
          builder: (context, state) =>
              const Scaffold(body: Text('provider-apply-opened')),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>(create: (_) => AuthStorage(preferences)),
          Provider<GuestOnboardingStorage>(
            create: (_) => GuestOnboardingStorage(preferences),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    // Three path cards now (organizer / invite / provider) — the provider
    // card can sit below the fold, so bring it into view before tapping.
    await tester.ensureVisible(find.text('أنا مزود خدمة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أنا مزود خدمة'));
    await tester.pumpAndSettle();

    expect(find.text('provider-apply-opened'), findsOneWidget);
  });

  testWidgets('Invite and login entry points open their own routes', (
    tester,
  ) async {
    final preferences = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/welcome',
      routes: [
        GoRoute(
          path: '/welcome',
          builder: (context, state) => const SmartWelcomeScreen(),
        ),
        GoRoute(
          path: '/invites',
          builder: (context, state) =>
              const Scaffold(body: Text('invite-access-opened')),
        ),
        GoRoute(
          path: '/login',
          builder: (context, state) =>
              const Scaffold(body: Text('login-opened')),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>(create: (_) => AuthStorage(preferences)),
          Provider<GuestOnboardingStorage>(
            create: (_) => GuestOnboardingStorage(preferences),
          ),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.ensureVisible(find.text('وصلتني دعوة لخطة'));
    await tester.tap(find.text('وصلتني دعوة لخطة'));
    await tester.pumpAndSettle();
    expect(find.text('invite-access-opened'), findsOneWidget);

    router.go('/welcome');
    await tester.pumpAndSettle();
    final loginButton = find.widgetWithText(TextButton, 'تسجيل الدخول');
    await tester.ensureVisible(loginButton);
    await tester.pumpAndSettle();
    await tester.tap(loginButton);
    await tester.pumpAndSettle();
    expect(find.text('login-opened'), findsOneWidget);
  });

  testWidgets('Organizer path saves complete local plan setup', (tester) async {
    final preferences = await SharedPreferences.getInstance();
    final guestStorage = GuestOnboardingStorage(preferences);

    final router = GoRouter(
      initialLocation: '/welcome',
      routes: [
        GoRoute(
          path: '/welcome',
          builder: (context, state) => const SmartWelcomeScreen(),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) =>
              const Scaffold(body: Text('dashboard-opened')),
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>(create: (_) => AuthStorage(preferences)),
          Provider<GuestOnboardingStorage>.value(value: guestStorage),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );

    await tester.pumpAndSettle();

    // Verify we landed on welcome
    expect(find.text('اختر المسار المناسب لك'), findsOneWidget);

    // Tap Organizer
    await tester.tap(find.text('إنشاء خطتك'));
    await tester.pumpAndSettle();

    // Tap Groom, then continue after the selected state is visible.
    await tester.tap(find.text('العريس'));
    await tester.pumpAndSettle();
    expect(find.byIcon(LucideIcons.checkCircle), findsOneWidget);

    final continueButton = find.text('التالي');
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    // Verify quick setup
    expect(find.text('إنشاء خطة زفاف'), findsOneWidget);
    expect(find.text('ميزانية أولية'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('wedding-plan-title-field')),
      'My Wedding',
    );
    await tester.pumpAndSettle();

    // The same structured location form is used for first and additional plans.
    expect(
      find.textContaining('اختر المحافظة ثم المديرية بالترتيب'),
      findsOneWidget,
    );
    final governorateField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'المحافظة *',
    );
    await tester.enterText(governorateField, 'صنعاء');
    await tester.pumpAndSettle();
    final districtField = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'المديرية *',
    );
    await tester.enterText(districtField, 'بني الحارث');
    await tester.pumpAndSettle();

    final dateField = find.byKey(const ValueKey('wedding-plan-date-field'));
    await tester.ensureVisible(dateField);
    await tester.pumpAndSettle();
    await tester.tap(dateField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('ميزانية أولية'));
    await tester.tap(find.text('ميزانية أولية'));
    await tester.pumpAndSettle();

    final budgetField = find.byKey(const ValueKey('wedding-plan-budget-field'));
    await tester.enterText(budgetField, '3000000');
    await tester.pumpAndSettle();

    // Change currency
    await tester.tap(find.text('ر.ي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ر.س').last);
    await tester.pumpAndSettle();

    final locationValues = tester
        .widgetList<TextField>(find.byType(TextField))
        .map((field) => field.controller?.text)
        .whereType<String>()
        .toList();
    final locationFields = {
      for (final field in tester.widgetList<TextField>(find.byType(TextField)))
        field.decoration?.labelText: field.controller?.text,
    };
    expect(locationValues, contains('صنعاء'));
    expect(locationValues, contains('بني الحارث'));
    expect(locationFields['المحافظة *'], 'صنعاء');
    expect(locationFields['المديرية *'], 'بني الحارث');
    expect(find.text('اختر التاريخ'), findsNothing);

    // Tap Start Planning
    final startButton = find.text('إنشاء الخطة');
    await tester.ensureVisible(startButton);
    await tester.pumpAndSettle();
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    // Verify it navigated away from welcome to /home
    expect(find.text('عنوان الخطة مطلوب'), findsNothing);
    if (find.byType(WeddingPlanCreationFields).evaluate().isNotEmpty) {
      final form = tester.widget<WeddingPlanCreationFields>(
        find.byType(WeddingPlanCreationFields),
      );
      expect(form.errorMessage, isNull);
    }
    expect(find.text('dashboard-opened'), findsOneWidget);

    // Verify draft was saved
    final draft = await guestStorage.loadDraft();
    final guestPlan = await guestStorage.loadGuestPlan();
    expect(guestPlan, isNotNull);
    expect(draft?.planName, 'My Wedding');
    expect(draft?.governorate, 'صنعاء');
    expect(draft?.city, 'بني الحارث');
    expect(draft?.weddingDate, isNotNull);
    expect(draft?.weddingDateUnknown, isFalse);
    expect(draft?.estimatedBudget, '3000000');
    expect(draft?.currency, 'SAR');
  });

  testWidgets(
    'Quick setup blocks dashboard until required plan data is complete',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      final guestStorage = GuestOnboardingStorage(preferences);

      final router = GoRouter(
        initialLocation: '/welcome',
        routes: [
          GoRoute(
            path: '/welcome',
            builder: (context, state) => const SmartWelcomeScreen(),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) =>
                const Scaffold(body: Text('dashboard-opened')),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<AuthStorage>(create: (_) => AuthStorage(preferences)),
            Provider<GuestOnboardingStorage>.value(value: guestStorage),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('إنشاء خطتك'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('العروسة'));
      await tester.pumpAndSettle();
      final continueButton = find.text('التالي');
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(find.text('إنشاء خطة زفاف'), findsOneWidget);

      final startButton = find.text('إنشاء الخطة');
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      expect(find.text('dashboard-opened'), findsNothing);
      expect(await guestStorage.loadGuestPlan(), isNull);
      expect(find.text('عنوان الخطة مطلوب'), findsOneWidget);
    },
  );

  testWidgets('Quick setup fields stay overflow-free at 320px RTL width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 760);
    addTearDown(tester.view.reset);

    final controllers = List.generate(8, (_) => TextEditingController());
    controllers[0].text = 'خطة زفاف عربية طويلة لاختبار تكبير النص';
    controllers[1].text = 'أمانة العاصمة';
    controllers[2].text = 'صنعاء القديمة';
    controllers[3].text = 'حي طويل لاختبار التفاف النص العربي';
    controllers[4].text = 'حي الأنصار';
    controllers[7].text = '3000000';
    addTearDown(() {
      for (final controller in controllers) {
        controller.dispose();
      }
    });

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: WeddingPlanCreationFields(
                titleController: controllers[0],
                governorateController: controllers[1],
                cityOrDistrictController: controllers[2],
                areaOrNeighborhoodController: controllers[3],
                neighborhoodController: controllers[4],
                streetController: controllers[5],
                detailedAddressController: controllers[6],
                budgetController: controllers[7],
                currency: 'YER',
                weddingDate: DateTime(2026, 12, 1),
                showOptionalAddress: true,
                onSelectDate: () {},
                onCurrencyChanged: (_) {},
                onToggleOptionalAddress: () {},
                onChanged: () {},
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('ميزانية أولية'));
    await tester.tap(find.text('ميزانية أولية'));
    await tester.pumpAndSettle();

    expect(find.byType(WeddingPlanCreationFields), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Path and role selection stay overflow-free at 320px RTL width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 760);
    addTearDown(tester.view.reset);

    final preferences = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AuthStorage>(create: (_) => AuthStorage(preferences)),
          Provider<GuestOnboardingStorage>(
            create: (_) => GuestOnboardingStorage(preferences),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: SmartWelcomeScreen())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('اختر المسار المناسب لك'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('إنشاء خطتك'));
    await tester.pumpAndSettle();

    expect(find.text('دورك يحدد التفاصيل'), findsOneWidget);
    expect(find.text('التالي'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

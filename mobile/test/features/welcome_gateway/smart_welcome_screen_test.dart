import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';

import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/onboarding/data/guest_onboarding_storage.dart';
import 'package:aarast_mobile/features/welcome_gateway/screens/smart_welcome_screen.dart';
import 'package:aarast_mobile/features/welcome_gateway/widgets/premium_setup_fields.dart';

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
    expect(find.text('اختيار بسيط يساعدنا نرتب التجربة لك بوضوح.'), findsOneWidget);
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
    expect(find.text('افتح لوحة واضحة'), findsOneWidget);
    expect(find.text('الميزانية والعملة'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'My Wedding');
    await tester.pumpAndSettle();

    // Verify location
    expect(find.text('المدينة / الموقع'), findsOneWidget);
    expect(
      find.text('اكتب المدينة أو المنطقة الآن، ويمكن تعديلها لاحقًا من الخطة.'),
      findsOneWidget,
    );
    final locationField = find.descendant(
      of: find.byType(PremiumLocationCard),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(locationField, 'صنعاء');
    await tester.pumpAndSettle();

    final dateField = find.byType(PremiumDateField);
    await tester.ensureVisible(dateField);
    await tester.pumpAndSettle();
    await tester.tap(dateField);
    await tester.pumpAndSettle();
    await tester.tap(find.text('15').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Verify budget formatting
    final budgetField = find.descendant(
      of: find.byType(PremiumBudgetField),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(budgetField, '3000000');
    await tester.pumpAndSettle();

    // It should display Arabic text with default currency
    expect(find.text('ثلاثة ملايين ريال يمني'), findsOneWidget);

    // Change currency
    await tester.tap(find.text('ر.ي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ر.س').last);
    await tester.pumpAndSettle();

    // Verify currency text updated
    expect(find.text('ثلاثة ملايين ريال سعودي'), findsOneWidget);

    // Tap Start Planning
    final startButton = find.text('حفظ ومتابعة');
    await tester.ensureVisible(startButton);
    await tester.pumpAndSettle();
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    // Verify it navigated away from welcome to /home
    expect(find.text('dashboard-opened'), findsOneWidget);

    // Verify draft was saved
    final draft = await guestStorage.loadDraft();
    final guestPlan = await guestStorage.loadGuestPlan();
    expect(guestPlan, isNotNull);
    expect(draft?.planName, 'My Wedding');
    expect(draft?.governorate, 'صنعاء');
    expect(draft?.city, 'صنعاء');
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

      expect(find.text('افتح لوحة واضحة'), findsOneWidget);

      final startButton = find.text('حفظ ومتابعة');
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pumpAndSettle();
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      expect(find.text('dashboard-opened'), findsNothing);
      expect(await guestStorage.loadGuestPlan(), isNull);
      expect(find.textContaining('أكمل اسم الخطة'), findsOneWidget);
    },
  );

  testWidgets('Quick setup fields stay overflow-free at 320px RTL width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 760);
    addTearDown(tester.view.reset);

    final budgetController = TextEditingController(text: '3000000');
    final locationController = TextEditingController(
      text: 'صنعاء القديمة - شارع طويل لاختبار التفاف النص العربي',
    );
    addTearDown(budgetController.dispose);
    addTearDown(locationController.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    PremiumDateField(selectedDate: null, onTap: () {}),
                    const SizedBox(height: 16),
                    PremiumBudgetField(
                      controller: budgetController,
                      initialCurrency: 'YER',
                      onCurrencyChanged: (_) {},
                    ),
                    const SizedBox(height: 16),
                    PremiumLocationCard(controller: locationController),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(PremiumLocationCard), findsOneWidget);
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

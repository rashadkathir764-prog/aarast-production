import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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

    expect(find.text('كيف تحب تبدأ؟'), findsOneWidget);
    expect(find.text('أريد تنظيم زفافي'), findsOneWidget);
    expect(find.text('أنا مزود خدمة'), findsOneWidget);
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

    await tester.tap(find.text('أريد تنظيم زفافي'));
    await tester.pumpAndSettle();

    expect(find.text('من أنت؟'), findsOneWidget);
    expect(find.text('العريس'), findsOneWidget);
    expect(find.text('أتابع الخطة والميزانية'), findsOneWidget);
    expect(find.text('العروسة'), findsOneWidget);
    expect(find.text('أرتب التفاصيل والاختيارات'), findsOneWidget);
    expect(find.text('مساهم / مشارك في الخطة'), findsOneWidget);
    expect(find.text('أساعد في التنظيم والمتابعة'), findsOneWidget);
    expect(find.text('خلّينا نجهز أساس خطتك'), findsNothing);
  });

  testWidgets('Provider path shows coming soon', (tester) async {
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

    await tester.tap(find.text('أنا مزود خدمة'));
    await tester.pumpAndSettle();

    expect(find.text('مسار مزودي الخدمة'), findsOneWidget);
    expect(
      find.text(
        'قريبًا ستتمكن من عرض خدماتك واستقبال طلبات العملاء من داخل أعرست.',
      ),
      findsOneWidget,
    );
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
    expect(find.text('كيف تحب تبدأ؟'), findsOneWidget);

    // Tap Organizer
    await tester.tap(find.text('أريد تنظيم زفافي'));
    await tester.pumpAndSettle();

    // Tap Groom, then continue after the selected state is visible.
    await tester.tap(find.text('العريس'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

    final continueButton = find.text('متابعة');
    await tester.ensureVisible(continueButton);
    await tester.tap(continueButton);
    await tester.pumpAndSettle();

    // Verify quick setup
    expect(find.text('أكمل بيانات خطتك'), findsOneWidget);
    expect(find.text('الميزانية والعملة'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'My Wedding');
    await tester.pumpAndSettle();

    // Verify location
    expect(find.text('المدينة / الموقع'), findsOneWidget);
    expect(find.text('تحديد الموقع على الخريطة قريبًا'), findsOneWidget);
    final locationField = find.descendant(
      of: find.byType(PremiumLocationCard),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(locationField, 'صنعاء');
    await tester.pumpAndSettle();

    await tester.tap(find.byType(PremiumDateField));
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
      await tester.tap(find.text('أريد تنظيم زفافي'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('العروسة'));
      await tester.pumpAndSettle();
      final continueButton = find.text('متابعة');
      await tester.ensureVisible(continueButton);
      await tester.tap(continueButton);
      await tester.pumpAndSettle();

      expect(find.text('أكمل بيانات خطتك'), findsOneWidget);

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

    expect(find.text('كيف تحب تبدأ؟'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('أريد تنظيم زفافي'));
    await tester.pumpAndSettle();

    expect(find.text('من أنت؟'), findsOneWidget);
    expect(find.text('متابعة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

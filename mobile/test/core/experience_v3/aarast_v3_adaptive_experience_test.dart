import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons/lucide_icons.dart';

void main() {
  group('Aarast adaptive route contracts', () {
    const routes = <String, String>{
      '/': 'startup',
      '/welcome': 'welcome',
      '/dev/guest-onboarding': 'welcome',
      '/login': 'auth',
      '/home': 'context-selection',
      '/providers': 'providers',
      '/providers/provider-1': 'provider-detail',
      '/providers/provider-1/quote': 'provider-form',
      '/provider/dashboard': 'provider-workspace',
      '/conversations': 'conversations',
      '/conversations/conversation-1': 'conversation',
      '/notifications': 'notifications',
      '/invites': 'sharing',
      '/invites/invite-token': 'sharing',
      '/more': 'utility',
      '/settings': 'utility',
      '/support': 'utility',
      '/wedding-plans': 'plans',
      '/wedding-plans/create': 'plan-form',
      '/wedding-plans/plan-1/dashboard': 'home',
      '/wedding-plans/plan-1/plan-center': 'plan-detail',
      '/wedding-plans/plan-1/events': 'plan-events',
      '/wedding-plans/plan-1/moments/week': 'home',
      '/wedding-plans/plan-1/tasks': 'tasks',
      '/wedding-plans/plan-1/tasks/create': 'task-form',
      '/wedding-plans/plan-1/guests': 'guests',
      '/wedding-plans/plan-1/guests/add': 'guest-form',
      '/wedding-plans/plan-1/providers': 'providers',
      '/wedding-plans/plan-1/money': 'money',
      '/wedding-plans/plan-1/money/budget': 'money-form',
      '/wedding-plans/plan-1/money/costs/cost-1': 'money-detail',
      '/wedding-plans/plan-1/money/categories/category-1': 'money-detail',
      '/wedding-plans/plan-1/money/categories/category-1/edit': 'money-form',
      '/wedding-plans/plan-1/money/costs/cost-1/edit': 'money-form',
      '/wedding-plans/plan-1/money/costs/cost-1/payments/create': 'money-form',
      '/wedding-plans/plan-1/money/payments/payment-1': 'money-detail',
      '/wedding-plans/plan-1/money/costs/cost-1/schedules/schedule-1/pay':
          'money-form',
      '/wedding-plans/plan-1/money/costs/cost-1/schedules/schedule-1':
          'money-detail',
      '/wedding-plans/plan-1/sharing': 'sharing',
      '/wedding-plans/plan-1/sharing/add': 'sharing-form',
      '/wedding-plans/plan-1/contributions': 'contribution-history',
      '/shared/wedding-plans': 'plans',
    };

    for (final entry in routes.entries) {
      test('${entry.key} resolves ${entry.value}', () {
        final contract = AarastV3ScreenCatalog.resolve(entry.key);
        expect(contract.id, entry.value);
        expect(contract.states, contains(AarastV3ScreenStateKind.ready));
        expect(contract.location.trim(), isNotEmpty);
        expect(contract.purpose.trim(), isNotEmpty);
      });
    }

    test('unknown routes fail visibly into the unmapped contract', () {
      expect(AarastV3ScreenCatalog.resolve('/future/unknown').id, 'unmapped');
    });

    test('money remains sensitive and the wedding events read offline', () {
      expect(
        AarastV3ScreenCatalog.money.privacy,
        AarastV3PrivacyLevel.sensitive,
      );
      expect(AarastV3ScreenCatalog.planEvents.supportsOffline, isTrue);
    });
  });

  testWidgets('attention surface stays compact at 320px and enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'Tajawal'),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 700),
            textScaler: TextScaler.linear(1.3),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: AarastV3AttentionSurface(
                  eyebrow: 'يحتاج انتباهك',
                  title: 'لديك دفعة خلال يومين',
                  reason: 'راجع المبلغ قبل موعده حتى تبقى خطتك واضحة.',
                  icon: LucideIcons.wallet,
                  actionLabel: 'تسجيل دفعة',
                  onAction: () => tapped = true,
                  tone: AarastV3AttentionTone.warning,
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('تسجيل دفعة'), findsOneWidget);
    await tester.tap(find.text('تسجيل دفعة'));
    expect(tapped, isTrue);
  });

  testWidgets('attention action stacks on a narrow physical-phone profile', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(384, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(384, 780),
            textScaler: TextScaler.linear(1.15),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: AarastV3AttentionSurface(
                  eyebrow: 'ابدأ من الأساس',
                  title: 'حدّد ميزانية تقريبية',
                  reason: 'يكفي رقم أولي يساعدك على قراءة قرارات الخطة بوضوح.',
                  icon: LucideIcons.wallet,
                  actionLabel: 'إعداد الميزانية',
                  onAction: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final reasonBottom = tester.getBottomLeft(
      find.text('يكفي رقم أولي يساعدك على قراءة قرارات الخطة بوضوح.'),
    );
    final actionTop = tester.getTopLeft(find.text('إعداد الميزانية'));
    expect(actionTop.dy, greaterThan(reasonBottom.dy));
    expect(
      tester.getSize(find.byType(AarastV3AttentionSurface)).height,
      lessThan(190),
    );
  });

  testWidgets('route shell exposes the resolved contract to descendants', (
    tester,
  ) async {
    final route = ValueNotifier<String>('/wedding-plans/plan-1/money');
    addTearDown(route.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: AarastV3AdaptiveExperienceShell(
          routeListenable: route,
          readLocation: () => route.value,
          child: Builder(
            builder: (context) => Text(AarastV3ExperienceScope.of(context).id),
          ),
        ),
      ),
    );

    expect(find.text('money'), findsOneWidget);
    route.value = '/wedding-plans/plan-1/tasks';
    await tester.pump();
    expect(find.text('tasks'), findsOneWidget);
  });

  testWidgets('state surfaces stay compact and truthful at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: AarastV3StateSurface.offline(),
            ),
          ),
        ),
      ),
    );

    expect(find.text(AarastV3Copy.offlineTitle), findsOneWidget);
    expect(find.text(AarastV3Copy.offlineMessage), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byType(AarastV3StateSurface)).height,
      lessThan(120),
    );
  });
}

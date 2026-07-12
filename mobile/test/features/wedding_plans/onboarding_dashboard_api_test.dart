import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/features/wedding_plans/data/wedding_plans_api.dart';
import 'package:aarast_mobile/features/wedding_plans/models/active_wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/models/onboarding_complete.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/providers/wedding_plans_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('onboarding and dashboard API integration', () {
    test(
      'completeOnboarding posts api v1 payload and parses response',
      () async {
        late RequestOptions capturedRequest;
        final api = WeddingPlansApi(
          _client((options) {
            capturedRequest = options;
            return _onboardingResponseJson();
          }),
        );

        final response = await api.completeOnboarding(
          const OnboardingCompleteRequest(
            path: 'USER',
            persona: 'BRIDE',
            title: 'خطتنا الذهبية',
            city: 'صنعاء',
            location: {
              'governorate': 'صنعاء',
              'city': 'صنعاء',
              'district': 'السبعين',
            },
            weddingDate: '2026-12-24',
            priorities: ['budget', 'tasks'],
            estimatedBudget: '120000',
            currency: 'SAR',
            selectedCategories: ['القاعة', 'التصوير'],
          ),
        );

        expect(capturedRequest.path, '/api/v1/onboarding/complete');
        expect(capturedRequest.data['path'], 'USER');
        expect(capturedRequest.data['persona'], 'BRIDE');
        expect(capturedRequest.data['estimatedBudget'], '120000');
        expect(response.activePlanId, 'plan-1');
        expect(response.activeWeddingPlan.title, 'خطتنا الذهبية');
        expect(response.activeWeddingPlan.persona, 'BRIDE');
        expect(response.budgetCategories.map((item) => item.name), [
          'القاعة',
          'التصوير',
        ]);
      },
    );

    test(
      'getActiveWeddingPlan parses active plan and provider state',
      () async {
        final api = WeddingPlansApi(
          _client((options) {
            expect(options.path, '/api/v1/wedding-plans/active');
            return _activePlanJson();
          }),
        );
        final provider = WeddingPlansProvider(api);

        await provider.loadActiveWeddingPlan();

        expect(provider.activePlan, isA<ActiveWeddingPlan>());
        expect(provider.activePlan?.id, 'plan-1');
        expect(provider.hasActivePlan, isTrue);
        expect(provider.shouldOpenOnboarding, isFalse);
        expect(provider.errorMessage, isNull);
      },
    );

    test(
      'getActiveWeddingPlan returns null when backend has no active plan',
      () async {
        final api = WeddingPlansApi(_client((_) => null));

        final activePlan = await api.getActiveWeddingPlan();

        expect(activePlan, isNull);
      },
    );

    test('createWeddingPlan marks the created plan active locally', () async {
      final api = WeddingPlansApi(
        _client((options) {
          expect(options.path, '/api/v1/wedding-plans');
          return _activePlanJson(id: 'plan-new', title: 'New plan');
        }),
      );
      final provider = WeddingPlansProvider(api);

      final plan = await provider.createWeddingPlan(title: 'New plan');

      expect(plan?.id, 'plan-new');
      expect(provider.activePlan?.id, 'plan-new');
      expect(provider.selectedPlan?.id, 'plan-new');
    });

    test('WeddingPlan preserves administrative preferences from the API', () {
      final plan = WeddingPlan.fromJson({
        ..._activePlanJson(),
        'priorities': ['budget', 'providers'],
        'onboardingPath': 'USER',
        'persona': 'GROOM',
      });

      expect(plan.priorities, ['budget', 'providers']);
      expect(plan.onboardingPath, 'USER');
      expect(plan.persona, 'GROOM');
    });

    test('editing and archiving keep active plan state truthful', () async {
      final api = WeddingPlansApi(
        _client((options) {
          if (options.path.endsWith('/archive')) {
            return {
              ..._activePlanJson(title: 'الخطة المعدلة'),
              'status': 'ARCHIVED',
              'priorities': ['providers'],
            };
          }
          if (options.method == 'PATCH') {
            return {
              ..._activePlanJson(title: 'الخطة المعدلة'),
              'priorities': ['providers'],
              'persona': 'BRIDE',
            };
          }
          return _activePlanJson();
        }),
      );
      final provider = WeddingPlansProvider(api);

      await provider.createWeddingPlan(title: 'الخطة الذهبية');
      await provider.updateWeddingPlan('plan-1', {
        'title': 'الخطة المعدلة',
        'priorities': ['providers'],
      });

      expect(provider.activePlan?.title, 'الخطة المعدلة');
      expect(provider.activePlan?.priorities, ['providers']);

      await provider.archiveWeddingPlan('plan-1');

      expect(provider.activePlan, isNull);
      expect(provider.selectedPlan?.status, 'ARCHIVED');
    });

    test('setActiveWeddingPlan uses api v1 set-active endpoint', () async {
      late RequestOptions capturedRequest;
      final api = WeddingPlansApi(
        _client((options) {
          capturedRequest = options;
          return _activePlanJson(id: 'plan-2', title: 'Second plan');
        }),
      );

      final active = await api.setActiveWeddingPlan('plan-2');

      expect(capturedRequest.path, '/api/v1/wedding-plans/plan-2/set-active');
      expect(capturedRequest.method, 'POST');
      expect(active.id, 'plan-2');
      expect(active.title, 'Second plan');
    });

    test(
      'getDashboardSummary uses api v1 summary endpoint and parses counts',
      () async {
        late RequestOptions capturedRequest;
        final api = WeddingPlansApi(
          _client((options) {
            capturedRequest = options;
            return _dashboardSummaryJson();
          }),
        );

        final summary = await api.getDashboardSummary('plan-1');

        expect(
          capturedRequest.path,
          '/api/v1/wedding-plans/plan-1/dashboard-summary',
        );
        expect(summary.planId, 'plan-1');
        expect(summary.progressPercentage, 68);
        expect(summary.daysRemaining, 30);
        expect(summary.budgetTotal, '120000.00');
        expect(summary.spentTotal, '28450.00');
        expect(summary.totalTasks, 29);
        expect(summary.completedTasks, 20);
        expect(summary.guestCount, 186);
        expect(summary.confirmedGuests, 120);
        expect(summary.canViewMoney, isTrue);
      },
    );

    test('DashboardSummary parses hidden finance permissions safely', () {
      final summary = DashboardSummary.fromJson({
        ..._dashboardSummaryJson(),
        'budgetTotal': null,
        'spentTotal': null,
        'remainingBudget': null,
        'commitmentTotal': null,
        'commitmentPaidTotal': null,
        'commitmentOutstandingTotal': null,
        'dueInstallmentsCount': null,
        'permissions': {
          ..._permissionsJson(),
          'canViewBudget': false,
          'canViewExpenses': false,
          'canViewFinancialRecords': false,
        },
      });

      expect(summary.canViewMoney, isFalse);
      expect(summary.budgetTotal, isNull);
      expect(summary.dueInstallmentsCount, isNull);
    });
  });
}

ApiClient _client(Object? Function(RequestOptions options) responder) {
  final client = ApiClient(tokenProvider: () async => 'token');
  client.dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.resolve(
          Response<Object?>(
            requestOptions: options,
            statusCode: 200,
            data: responder(options),
          ),
        );
      },
    ),
  );
  return client;
}

Map<String, dynamic> _onboardingResponseJson() {
  return {
    'user': {
      'id': 'user-1',
      'name': 'سارة',
      'phone': '+967777000000',
      'role': 'USER',
      'status': 'ACTIVE',
    },
    'activeWeddingPlan': _activePlanJson(),
    'budgetCategories': [
      {
        'id': 'category-1',
        'weddingPlanId': 'plan-1',
        'name': 'القاعة',
        'targetAmount': null,
        'createdAt': '2026-06-19T10:00:00.000Z',
        'updatedAt': '2026-06-19T10:00:00.000Z',
      },
      {
        'id': 'category-2',
        'weddingPlanId': 'plan-1',
        'name': 'التصوير',
        'targetAmount': null,
        'createdAt': '2026-06-19T10:00:00.000Z',
        'updatedAt': '2026-06-19T10:00:00.000Z',
      },
    ],
  };
}

Map<String, dynamic> _activePlanJson({
  String id = 'plan-1',
  String title = 'خطتنا الذهبية',
}) {
  return {
    'id': id,
    'ownerUserId': 'user-1',
    'title': title,
    'city': 'صنعاء',
    'location': {'city': 'صنعاء'},
    'weddingDate': '2026-12-24T00:00:00.000Z',
    'priorities': ['budget', 'tasks'],
    'estimatedBudget': '120000.00',
    'currency': 'SAR',
    'onboardingPath': 'USER',
    'persona': 'BRIDE',
    'onboardingCompletedAt': '2026-06-19T10:00:00.000Z',
    'status': 'PLANNING',
    'createdAt': '2026-06-19T10:00:00.000Z',
    'updatedAt': '2026-06-19T10:00:00.000Z',
  };
}

Map<String, dynamic> _dashboardSummaryJson() {
  return {
    'planId': 'plan-1',
    'title': 'الخطة الذهبية',
    'weddingDate': '2026-12-24T00:00:00.000Z',
    'city': 'صنعاء',
    'status': 'PLANNING',
    'daysRemaining': 30,
    'progressPercentage': 68,
    'budgetTotal': '120000.00',
    'spentTotal': '28450.00',
    'remainingBudget': '91550.00',
    'commitmentTotal': '3500.00',
    'commitmentPaidTotal': '0.00',
    'commitmentOutstandingTotal': '3500.00',
    'dueInstallmentsCount': 1,
    'totalTasks': 29,
    'completedTasks': 20,
    'overdueTasks': 1,
    'todayTasks': 2,
    'guestCount': 186,
    'confirmedGuests': 120,
    'providerCount': 12,
    'quoteRequestsCount': 3,
    'unreadNotificationsCount': 4,
    'currentUserRole': 'OWNER',
    'permissions': _permissionsJson(),
  };
}

Map<String, dynamic> _permissionsJson() {
  return {
    'isOwner': true,
    'role': 'OWNER',
    'canViewBudget': true,
    'canViewExpenses': true,
    'canViewFinancialRecords': true,
    'canManageTasks': true,
    'canManageFinancialRecords': true,
    'canManagePlan': true,
  };
}

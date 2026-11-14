import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/features/finance/data/finance_api_contracts.dart';
import 'package:aarast_mobile/features/finance/data/finance_local_data_source.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/home/data/dashboard_summary_sources.dart';
import 'package:aarast_mobile/features/onboarding/models/guest_onboarding_draft.dart';
import 'package:aarast_mobile/features/wedding_plans/models/active_wedding_plan.dart';
import 'package:aarast_mobile/features/wedding_plans/models/dashboard_summary.dart';
import 'package:aarast_mobile/features/wedding_plans/models/onboarding_complete.dart';
import 'package:aarast_mobile/features/wedding_plans/models/wedding_plan.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// D114: the owner's real plan kept on the phone: a 7,000,000 budget, a
// 2,000,000 mahr of which 500,000 handed over, nothing else agreed. The
// money tab and the home say what the account says once the plan is saved
// there (backend money-plan-fixtures, «owner's numbers»), the mahr outside
// the budget and inside it.

const _planId = 'local-guest-plan';

Future<OfflineSyncService> _offline() async {
  SharedPreferences.setMockInitialValues({});
  final database = JsonLocalDatabase(await SharedPreferences.getInstance());
  await database.initialize();
  final offline = OfflineSyncService(
    database: database,
    apiClient: ApiClient(tokenProvider: () async => null),
  );
  await offline.initialize();
  return offline;
}

LocalFinancePlanContext _owner({bool? inside}) => LocalFinancePlanContext(
  estimatedBudget: '7000000',
  currency: 'YER',
  persona: 'GROOM',
  mahrTotal: '2000000',
  mahrSettled: '500000',
  budgetIncludesMahr: inside,
);

GuestOnboardingDraft _draft({bool? inside}) => GuestOnboardingDraft(
  guestPlanId: _planId,
  planName: 'عرسنا',
  createdAt: DateTime.utc(2026, 11, 1),
  isGuestPlan: true,
  needsSync: true,
  selectedPath: GuestOnboardingPath.weddingUser,
  persona: GuestPersona.groom,
  governorate: 'صنعاء',
  city: 'صنعاء',
  district: null,
  neighborhood: null,
  street: null,
  addressNote: null,
  weddingDate: DateTime.now().add(const Duration(days: 120)),
  weddingDateUnknown: false,
  priorities: const [],
  currency: 'YER',
  estimatedBudget: '7000000',
  selectedCategoryKeys: const [],
  mahr: const DraftMahr(total: '2000000', settled: '500000'),
  budgetIncludesMahr: inside,
);

Map<String, Object?> _budget(MoneySummary summary) => {
  'includesMahr': summary.budget.includesMahr,
  'confirmedCost': moneyValue(summary.budget.confirmedCost),
  'paid': moneyValue(summary.budget.paid),
  'outstanding': moneyValue(summary.budget.outstanding),
  'remaining': moneyValue(summary.budget.remaining),
  'unallocated': moneyValue(summary.budget.unallocated),
  'count': summary.budget.count,
  'budgetLeft': moneyValue(summary.expected?.budgetLeft),
};

num moneyValue(String? value) => num.tryParse(value ?? '') ?? 0;

void main() {
  test(
    'the money tab: the owner\'s numbers with the mahr outside the budget',
    () async {
      final local = FinanceLocalDataSource(await _offline());
      final summary = await local.moneySummary(
        _planId,
        estimatedBudget: '7000000',
        persona: 'GROOM',
        draftMahr: _owner(),
      );
      expect(_budget(summary), {
        'includesMahr': false,
        'confirmedCost': 0,
        'paid': 0,
        'outstanding': 0,
        'remaining': 7000000,
        'unallocated': 7000000,
        'count': 0,
        'budgetLeft': 7000000,
      });
      // Every agreement, the draft mahr's with it, as the account counts it.
      expect(moneyValue(summary.costs.total), 2000000);
      expect(moneyValue(summary.costs.paid), 500000);
      expect(moneyValue(summary.costs.outstanding), 1500000);
      expect(moneyValue(summary.expected?.mahr.expected), 2000000);
      expect(summary.mahr?.side, MahrSide.pays);
      expect(moneyValue(summary.mahr?.total), 2000000);
      expect(moneyValue(summary.mahr?.settled), 500000);
      expect(moneyValue(summary.mahr?.remaining), 1500000);
    },
  );

  test(
    'the money tab: the owner\'s numbers with the mahr inside the budget',
    () async {
      final local = FinanceLocalDataSource(await _offline());
      final off = await local.moneySummary(
        _planId,
        estimatedBudget: '7000000',
        persona: 'GROOM',
        draftMahr: _owner(),
      );
      final on = await local.moneySummary(
        _planId,
        estimatedBudget: '7000000',
        persona: 'GROOM',
        draftMahr: _owner(inside: true),
      );
      expect(_budget(on), {
        'includesMahr': true,
        'confirmedCost': 2000000,
        'paid': 500000,
        'outstanding': 1500000,
        'remaining': 5000000,
        'unallocated': 5000000,
        'count': 0,
        'budgetLeft': 5000000,
      });
      // «منها المهر»: the wedding's own figures stay the same in both.
      expect(on.weddingAgreed, 0);
      expect(on.weddingPaid, 0);
      expect(on.weddingOutstanding, 0);
      expect(off.weddingAgreed, 0);
      expect(on.costs.total, off.costs.total);
      expect(on.costs.paid, off.costs.paid);
      expect(on.costs.outstanding, off.costs.outstanding);
      expect(on.outstanding?.owner, off.outstanding?.owner);
      expect(on.mahr?.remaining, off.mahr?.remaining);
    },
  );

  test(
    'the money tab\'s own save of the budget names the choice first',
    () async {
      final offline = await _offline();
      final local = FinanceLocalDataSource(offline);
      await local.saveBudget(
        planId: _planId,
        totalBudget: '7000000',
        currency: 'YER',
        categories: const [],
        budgetIncludesMahr: true,
      );
      // A later save that does not name it keeps it.
      await local.saveBudget(
        planId: _planId,
        totalBudget: '7000000',
        currency: 'YER',
        categories: const [],
      );
      final summary = await local.moneySummary(
        _planId,
        persona: 'GROOM',
        draftMahr: _owner(inside: false),
      );
      expect(summary.budget.includesMahr, true);
      expect(moneyValue(summary.budget.remaining), 5000000);
    },
  );

  test('the wedding\'s own figures, the mahr apart, with it inside', () async {
    final offline = await _offline();
    await offline.database.saveCachedItem(
      table: OfflineTables.cachedCosts,
      json: {
        'id': 'hall',
        'planId': _planId,
        'weddingPlanId': _planId,
        'title': 'القاعة',
        'totalAmount': '3000000',
        'paidAmount': '1000000',
        'status': 'PARTIALLY_PAID',
      },
    );
    await offline.database.saveCachedItem(
      table: OfflineTables.cachedCostPayments,
      json: {
        'id': 'pay-hall',
        'planId': _planId,
        'weddingPlanId': _planId,
        'costId': 'hall',
        'amount': '1000000',
        'entryType': 'PAYMENT',
      },
    );
    final summary = await FinanceLocalDataSource(offline).moneySummary(
      _planId,
      estimatedBudget: '7000000',
      persona: 'GROOM',
      draftMahr: _owner(inside: true),
    );
    expect(moneyValue(summary.budget.confirmedCost), 5000000);
    expect(moneyValue(summary.budget.paid), 1500000);
    expect(moneyValue(summary.budget.remaining), 2000000);
    expect(summary.budget.count, 1);
    expect(summary.weddingAgreed, 3000000);
    expect(summary.weddingPaid, 1000000);
    expect(summary.weddingOutstanding, 2000000);
  });

  test('a bride\'s plan never counts the mahr inside the budget', () async {
    final local = FinanceLocalDataSource(await _offline());
    final summary = await local.moneySummary(
      _planId,
      estimatedBudget: '7000000',
      persona: 'BRIDE',
      draftMahr: const LocalFinancePlanContext(
        mahrTotal: '2000000',
        mahrSettled: '500000',
        budgetIncludesMahr: true,
      ),
    );
    expect(summary.budget.includesMahr, false);
    expect(moneyValue(summary.budget.remaining), 7000000);
    // Her mahr comes in: the plan's questions until it is saved as money.
    expect(summary.mahr?.side, MahrSide.receives);
    expect(moneyValue(summary.mahr?.remaining), 1500000);
  });

  group('the home', () {
    Future<LocalGuestDashboardSummary> home({bool? inside}) async {
      final offline = await _offline();
      final metrics = await LocalDashboardMetrics.load(
        database: offline.database,
        planId: _planId,
        persona: 'GROOM',
        draft: _draft(inside: inside),
      );
      return LocalGuestDashboardSummary.fromPlan(
        _draft(inside: inside),
        metrics: metrics,
      );
    }

    test(
      'agrees with the money tab with the mahr outside the budget',
      () async {
        final summary = await home();
        // D79: «اتفقت على» holds the mahr; it was left out on the phone.
        expect(summary.confirmedCostTotal, '2000000');
        expect(summary.paidTotal, '500000');
        expect(summary.outstandingTotal, '1500000');
        final dashboard = summary.toDashboardSummary();
        expect(dashboard.moneySummary.remainingBudget, '7000000');
        expect(dashboard.moneySummary.overBudget, false);
        expect(dashboard.budgetIncludesMahr, false);
      },
    );

    test('agrees with the money tab with the mahr inside the budget', () async {
      final summary = await home(inside: true);
      expect(summary.confirmedCostTotal, '2000000');
      final dashboard = summary.toDashboardSummary();
      expect(dashboard.moneySummary.remainingBudget, '5000000');
      expect(dashboard.moneySummary.overBudget, false);
      expect(dashboard.budgetIncludesMahr, true);
    });

    test(
      'over the budget by the expected cost, as the account (D105)',
      () async {
        final offline = await _offline();
        await offline.database.saveCachedItem(
          table: OfflineTables.cachedBudgetCategories,
          json: {
            'id': 'food',
            'planId': _planId,
            'weddingPlanId': _planId,
            'name': 'الأكل',
            'estimatedAmount': '2500000',
          },
        );
        await offline.database.saveCachedItem(
          table: OfflineTables.cachedCosts,
          json: {
            'id': 'hall',
            'planId': _planId,
            'weddingPlanId': _planId,
            'title': 'القاعة',
            'totalAmount': '3000000',
            'paidAmount': '0',
            'status': 'CONFIRMED',
          },
        );
        Future<LocalGuestDashboardSummary> read(bool? inside) async =>
            LocalGuestDashboardSummary.fromPlan(
              _draft(inside: inside),
              metrics: await LocalDashboardMetrics.load(
                database: offline.database,
                planId: _planId,
                persona: 'GROOM',
                draft: _draft(inside: inside),
              ),
            );
        final off = (await read(null)).toDashboardSummary();
        // 7,000,000 less the hall and the food's estimate: inside the budget,
        // though the agreements alone with the mahr are 5,000,000.
        expect(off.moneySummary.remainingBudget, '4000000');
        expect(off.moneySummary.overBudget, false);
        final on = (await read(true)).toDashboardSummary();
        expect(on.moneySummary.remainingBudget, '2000000');
        // 3,000,000 + 2,500,000 expected + the mahr's 2,000,000 > 7,000,000.
        expect(on.moneySummary.overBudget, true);
        expect(
          on.financialWarnings.map((warning) => warning.type),
          contains('BUDGET_EXCEEDED'),
        );
        expect(
          off.financialWarnings.map((warning) => warning.type),
          isNot(contains('BUDGET_EXCEEDED')),
        );
      },
    );
  });

  group('the models and the writes', () {
    test(
      'a server that does not send the choice reads as the mahr outside',
      () {
        expect(MoneyBudgetSummary.fromJson(const {}).includesMahr, false);
        expect(
          MoneyBudgetSummary.fromJson(const {
            'includesMahr': true,
          }).includesMahr,
          true,
        );
        final plan = {
          'id': 'p',
          'ownerUserId': 'u',
          'title': 'عرس',
          'currency': 'YER',
        };
        expect(WeddingPlan.fromJson(plan).budgetIncludesMahr, false);
        expect(
          WeddingPlan.fromJson({
            ...plan,
            'budgetIncludesMahr': null,
          }).budgetIncludesMahr,
          false,
        );
        final inside = ActiveWeddingPlan.fromJson({
          ...plan,
          'budgetIncludesMahr': true,
        });
        expect(inside.budgetIncludesMahr, true);
        expect(inside.toWeddingPlan().budgetIncludesMahr, true);
        expect(DashboardSummary.fromJson(const {}).budgetIncludesMahr, false);
      },
    );

    test(
      'the plan\'s questions keep the answer, and a new persona drops it',
      () {
        final draft = _draft(inside: true);
        final saved = GuestOnboardingDraft.fromJson(draft.toJson());
        expect(saved.budgetIncludesMahr, true);
        expect(saved.mahrInsideBudget, true);
        // A draft saved before D114 has no answer, and writes none.
        expect(_draft().toJson().containsKey('budgetIncludesMahr'), false);
        expect(
          GuestOnboardingDraft.fromJson(_draft().toJson()).budgetIncludesMahr,
          null,
        );
        final bride = draft.copyWith(persona: GuestPersona.bride);
        expect(bride.budgetIncludesMahr, null);
        expect(bride.mahrInsideBudget, false);
        expect(draft.copyWith(planName: 'عرسنا').budgetIncludesMahr, true);
      },
    );

    test('the onboarding sends the answer only when it was given', () {
      expect(
        const OnboardingCompleteRequest(
          estimatedBudget: '7000000',
        ).toJson().containsKey('budgetIncludesMahr'),
        false,
      );
      expect(
        const OnboardingCompleteRequest(
          persona: 'GROOM',
          estimatedBudget: '7000000',
          budgetIncludesMahr: true,
        ).toJson()['budgetIncludesMahr'],
        true,
      );
    });
  });
}

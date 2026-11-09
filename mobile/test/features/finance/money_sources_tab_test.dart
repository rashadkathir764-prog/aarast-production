import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/core/routing/app_router.dart';
import 'package:aarast_mobile/core/theme/app_theme.dart';
import 'package:aarast_mobile/core/utils/plan_day.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/data/finance_local_data_source.dart';
import 'package:aarast_mobile/features/finance/data/funding_api.dart';
import 'package:aarast_mobile/features/finance/models/funding_source.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:aarast_mobile/features/finance/providers/funding_provider.dart';
import 'package:aarast_mobile/features/finance/screens/money_overview_screen.dart';
import 'package:aarast_mobile/features/finance/widgets/funding_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

// c05 «من وين» (D103, D104, D108) on a plan kept on the phone: what he holds
// and how, against what is on him; what reached him, what is promised and
// whether it arrived; the family person by person; the loans.

const _planId = 'guest-plan-sources-tab';

class _NoNetwork extends ApiClient {
  _NoNetwork() : super(tokenProvider: () async => null);
}

String _day(int offset) {
  final today = sanaaToday();
  return DateTime.utc(
    today.year,
    today.month,
    today.day + offset,
  ).toIso8601String();
}

/// In: savings 900,000; the father's support 500,000 (recorded as «أبوي»,
/// no contributor named); a loan of 400,000 (200,000 paid back, 200,000 in
/// 60 days). Promised: the father 300,000 in 10 days; the uncle's gift
/// 200,000 with no day. Out of his own money: 400,000 on the hall. The
/// photographer (350,000) is the father's, 100,000 of it paid.
/// «معك» = 1,800,000 − 400,000 − 200,000 = 1,200,000.
Future<(FinanceProvider, FundingProvider)> _plan({
  String persona = 'GROOM',
}) async {
  SharedPreferences.setMockInitialValues({});
  final database = JsonLocalDatabase(await SharedPreferences.getInstance());
  await database.initialize();
  final offline = OfflineSyncService(
    database: database,
    apiClient: _NoNetwork(),
  );
  await offline.initialize();
  await FinanceLocalDataSource(offline).saveBudget(
    planId: _planId,
    totalBudget: '3000000',
    currency: 'YER',
    categories: const [
      {'id': 'c-hall', 'weddingPlanId': _planId, 'name': 'القاعة'},
      {'id': 'c-photo', 'weddingPlanId': _planId, 'name': 'التصوير'},
    ],
  );
  Future<void> put(String table, Map<String, dynamic> json) => database
      .saveCachedItem(table: table, json: {...json, 'weddingPlanId': _planId});
  await put(OfflineTables.cachedCosts, {
    'id': 'k-hall',
    'budgetCategoryId': 'c-hall',
    'title': 'قاعة الريان',
    'totalAmount': '1200000',
    'paidAmount': '400000',
    'status': 'PARTIALLY_PAID',
    'entryKind': 'AGREEMENT',
    'estimateCover': 'WHOLE',
  });
  await put(OfflineTables.cachedCosts, {
    'id': 'k-photo',
    'budgetCategoryId': 'c-photo',
    'title': 'المصور',
    'totalAmount': '350000',
    'paidAmount': '100000',
    'status': 'PARTIALLY_PAID',
    'entryKind': 'AGREEMENT',
    'estimateCover': 'WHOLE',
    'payer': 'FAMILY',
    'payerName': 'أبوي',
  });
  for (final (id, costId, amount) in [
    ('p-hall', 'k-hall', '400000'),
    ('p-photo', 'k-photo', '100000'),
  ]) {
    await put(OfflineTables.cachedCostPayments, {
      'id': id,
      'costId': costId,
      'amount': amount,
      'entryType': 'PAYMENT',
      'paidAt': _day(-20),
    });
  }
  for (final (id, amount, day) in [
    ('s-late', '300000', -3),
    ('s-next', '500000', 12),
  ]) {
    await put(OfflineTables.cachedPaymentSchedules, {
      'id': id,
      'costId': 'k-hall',
      'amount': amount,
      'status': 'PENDING',
      'dueDate': _day(day),
      'createdAt': _day(-30),
    });
  }
  for (final source in [
    {
      'id': 'f-save',
      'kind': 'SAVINGS',
      'sourceName': 'مدخراتي',
      'amount': '900000',
      'status': 'RECEIVED',
    },
    {
      'id': 'f-father',
      'kind': 'FAMILY_SUPPORT',
      'sourceName': 'أبوي',
      'amount': '500000',
      'status': 'RECEIVED',
    },
    {
      'id': 'f-promise',
      'kind': 'FAMILY_SUPPORT',
      'sourceName': 'أبوي',
      'amount': '300000',
      'status': 'PLEDGED',
      'expectedAt': _day(10),
    },
    {
      'id': 'f-uncle',
      'kind': 'GIFT',
      'sourceName': 'خالي',
      'amount': '200000',
      'status': 'PLEDGED',
    },
    {
      'id': 'f-loan',
      'kind': 'LOAN',
      'sourceName': 'سلفة من صاحبي',
      'amount': '400000',
      'status': 'RECEIVED',
      'repayments': [
        {
          'id': 'r-1',
          'fundingSourceId': 'f-loan',
          'amount': '200000',
          'dueDate': _day(-10),
          'status': 'PAID',
        },
        {
          'id': 'r-2',
          'fundingSourceId': 'f-loan',
          'amount': '200000',
          'dueDate': _day(60),
          'status': 'PLANNED',
        },
      ],
    },
  ]) {
    await put(OfflineTables.cachedFundingSources, {
      'repayments': const [],
      ...source,
    });
  }
  return (
    FinanceProvider(
      FinanceApi(
        _NoNetwork(),
        offline: offline,
        localPlanContextLoader: (_) async =>
            LocalFinancePlanContext(currency: 'YER', persona: persona),
      ),
    ),
    FundingProvider(FundingApi(_NoNetwork(), offline: offline)),
  );
}

Future<void> _open(
  WidgetTester tester,
  (FinanceProvider, FundingProvider) providers, {
  String personaCode = 'groom',
}) async {
  tester.view.physicalSize = const Size(320, 760);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    initialLocation: AppRouter.money(_planId),
    routes: [
      GoRoute(
        path: '/wedding-plans/:id/money',
        builder: (_, _) => MoneyOverviewScreen(
          weddingPlanId: _planId,
          personaCode: personaCode,
        ),
        routes: [
          for (final path in const ['funding', 'payers'])
            GoRoute(
              path: path,
              builder: (_, state) => Scaffold(body: Text(state.uri.toString())),
            ),
        ],
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: providers.$1),
        ChangeNotifierProvider.value(value: providers.$2),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: JourneyProfileScope(
              profile: personaCode == 'bride'
                  ? JourneyProfile.bride
                  : JourneyProfile.groom,
              child: child!,
            ),
          ),
        ),
      ),
    ),
  );
  await _settle(tester);
  await tester.tap(find.byKey(const ValueKey('journey-tab-3')));
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

Future<void> _show(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

String _said(WidgetTester tester, Finder of) => [
  for (final text in tester.widgetList<Text>(
    find.descendant(of: of, matching: find.byType(Text)),
  ))
    text.data ?? text.textSpan?.toPlainText() ?? '',
].join(' ');

void main() {
  testWidgets('«معك» and how, against what is on him, and the cover', (
    tester,
  ) async {
    final providers = await tester.runAsync(_plan);
    await _open(tester, providers!);

    final hero = find.byKey(const ValueKey('money-cash-hero'));
    expect(_said(tester, hero), contains('1.2 مليون'));
    // In 1,800,000; out of it, 400,000 on the hall and 200,000 paid back.
    expect(_said(tester, hero), contains('وصلك 1.8 مليون'));
    expect(_said(tester, hero), contains('منها 600,000'));
    // The photographer is the father's: only the hall is on him.
    expect(_said(tester, hero), contains('من العرس 800,000'));
    expect(_said(tester, hero), contains('سلف ترجعها 200,000'));
    // 900 after the late 300; 400 after the hall's 500; 200 after the
    // repayment: covered without the promises, with the loan.
    expect(_said(tester, hero), contains('يكفي دفعاتك وسداد السلفة بمواعيدها'));
    expect(_said(tester, hero), contains('ويبقى 200,000'));
    // The uncle's gift has no day: left out, and said.
    expect(_said(tester, hero), contains('وعد خالي'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('what reached him, what is promised; it arrived', (tester) async {
    final providers = await tester.runAsync(_plan);
    await _open(tester, providers!);
    final (finance, _) = providers;

    final received = find.byKey(const ValueKey('money-sources-received'));
    await _show(tester, received);
    for (final id in ['f-save', 'f-father', 'f-loan']) {
      expect(
        find.descendant(
          of: received,
          matching: find.byKey(ValueKey('money-source-$id')),
        ),
        findsOneWidget,
        reason: id,
      );
    }
    // «مدخراتي» is not said twice.
    expect(
      find.descendant(of: received, matching: find.text('مدخراتي')),
      findsOneWidget,
    );

    final promise = find.byKey(const ValueKey('money-source-f-promise'));
    await _show(tester, promise);
    expect(_said(tester, promise), contains('موعدها'));
    final uncle = find.byKey(const ValueKey('money-source-f-uncle'));
    expect(_said(tester, uncle), contains('ما تحدد موعدها'));

    await tester.tap(
      find.byKey(const ValueKey('money-pledge-arrived-f-promise')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('money-pledge-arrived-yes')));
    await _settle(tester);
    // 1,200,000 + 300,000.
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('money-cash-figure'))).data,
      contains('1.5 مليون'),
    );
    expect(moneyValue(finance.summary.funding?.availableCash), 1500000);
  });

  testWidgets('the family, person by person; the loan and its way back', (
    tester,
  ) async {
    final providers = await tester.runAsync(_plan);
    await _open(tester, providers!);

    // «أبوي»: his support (named only as the source), what he paid the
    // photographer, what is left on it, and his promise: one person.
    final father = find.byKey(const ValueKey('money-family-0'));
    await _show(tester, father);
    final said = _said(tester, father);
    expect(said, contains('أبوي'));
    expect(said, contains('وصلك 500,000'));
    expect(said, contains('مدفوع للمحلات 100,000'));
    expect(said, contains('باقي 250,000'));
    expect(said, contains('موعود 300,000'));
    expect(said, contains('600,000')); // 500,000 + 100,000 to date
    // The uncle only promised: that is his figure, not «0».
    final uncle = find.byKey(const ValueKey('money-family-1'));
    expect(_said(tester, uncle), contains('200,000'));
    expect(_said(tester, uncle), contains('موعود'));
    expect(_said(tester, uncle), isNot(contains('0 ر.ي')));

    final loan = find.byKey(const ValueKey('money-loan-track-f-loan'));
    await _show(tester, loan);
    expect(_said(tester, loan), contains('باقي 200,000'));
    expect(_said(tester, loan), contains('الجاية'));
    expect(_said(tester, loan), contains('✓'));
  });

  testWidgets('the source form offers the names the plan already has', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: SingleChildScrollView(
              child: FundingSourceFormSheet(knownPeople: ['أبوي', 'خالي']),
            ),
          ),
        ),
      ),
    );
    // Family support is the default kind: the names are offered.
    await tester.tap(find.byKey(const ValueKey('funding-person-1')));
    await tester.pump();
    expect(find.text('خالي'), findsWidgets);
    final field = tester.widget<EditableText>(
      find.descendant(
        of: find.byKey(const ValueKey('funding-name')),
        matching: find.byType(EditableText),
      ),
    );
    expect(field.controller.text, 'خالي');
    // Savings are no one's: no names.
    await tester.tap(
      find.byKey(const ValueKey('funding-kind-${FundingKind.savings}')),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('funding-person-0')), findsNothing);
  });

  // RA-MO-71: the bride, owner of her plan, read «سلف ترجعها».
  testWidgets('the bride\'s loans speak to her', (tester) async {
    final providers = await tester.runAsync(() => _plan(persona: 'BRIDE'));
    await _open(tester, providers!, personaCode: 'bride');

    final hero = find.byKey(const ValueKey('money-cash-hero'));
    expect(_said(tester, hero), contains('سلف ترجعينها 200,000'));
  });
}

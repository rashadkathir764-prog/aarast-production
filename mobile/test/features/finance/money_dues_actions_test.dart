import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/offline/local_database_json.dart';
import 'package:aarast_mobile/core/offline/offline_sync_service.dart';
import 'package:aarast_mobile/core/offline/offline_tables.dart';
import 'package:aarast_mobile/core/utils/plan_day.dart';
import 'package:aarast_mobile/features/finance/data/finance_api.dart';
import 'package:aarast_mobile/features/finance/data/finance_local_data_source.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:aarast_mobile/features/finance/models/wedding_cost.dart';
import 'package:aarast_mobile/features/finance/providers/finance_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

// «الدفعات»'s writes (D106) through the provider the screens use, on a plan
// kept on the phone: paying less or more than a date asks, moving a date and
// back, its own reminder day, and taking a partial payment back.

const _planId = 'guest-plan-dues-actions';

class _NoNetwork extends ApiClient {
  _NoNetwork() : super(tokenProvider: () async => null);
}

DateTime _today() => sanaaToday();

String _day(int offset) {
  final today = _today();
  return DateTime.utc(
    today.year,
    today.month,
    today.day + offset,
  ).toIso8601String();
}

/// The hall: 1,200,000 agreed, nothing paid; 300,000 three days late,
/// 500,000 in twelve days, the rest (400,000) with no date.
Future<FinanceProvider> _provider() async {
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
    ],
  );
  Future<void> put(String table, Map<String, dynamic> json) => database
      .saveCachedItem(table: table, json: {...json, 'weddingPlanId': _planId});
  await put(OfflineTables.cachedCosts, {
    'id': 'k-hall',
    'budgetCategoryId': 'c-hall',
    'title': 'قاعة الريان',
    'totalAmount': '1200000',
    'paidAmount': '0',
    'status': 'PENDING',
    'entryKind': 'AGREEMENT',
    'estimateCover': 'WHOLE',
  });
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
  final provider = FinanceProvider(
    FinanceApi(
      _NoNetwork(),
      offline: offline,
      localPlanContextLoader: (_) async =>
          const LocalFinancePlanContext(currency: 'YER', persona: 'GROOM'),
    ),
  );
  await provider.loadMoney(_planId);
  await provider.loadCostDetails('k-hall');
  return provider;
}

MoneyObligation _line(FinanceProvider provider, String id) =>
    provider.summary.obligations.singleWhere((line) => line.id == id);

WeddingCost _hall(FinanceProvider provider) => provider.costById('k-hall')!;

void main() {
  // RA-BE-25 on the phone (RA-MO-51): the dates its being paid in full
  // cancelled come back once money is owed on it again, as the server does.
  test(
    'dates cancelled by paying in full come back when it is owed again',
    () async {
      final provider = await _provider();
      final payment = await provider.recordPayment(
        cost: _hall(provider),
        amount: '1200000',
      );
      expect(payment, isNotNull, reason: provider.errorMessage);
      expect(provider.scheduleById('s-next')!.status, 'CANCELLED');

      final reversed = await provider.reversePayment(
        payment: payment!,
        cost: _hall(provider),
        reason: 'غلط في المبلغ',
      );
      expect(reversed, isTrue, reason: provider.errorMessage);
      expect(provider.scheduleById('s-late')!.status, 'PENDING');
      expect(provider.scheduleById('s-next')!.status, 'PENDING');
      expect(moneyValue(provider.scheduleById('s-next')!.amount), 500000);
      expect(_line(provider, 's-next').amount, isNotNull);
    },
  );

  test('a raised total brings them back, never above what is left', () async {
    final provider = await _provider();
    await provider.recordPayment(cost: _hall(provider), amount: '1200000');
    expect(provider.scheduleById('s-late')!.status, 'CANCELLED');

    // 1,600,000 now: 400,000 is owed again.
    final saved = await provider.updateCost(
      cost: _hall(provider),
      budgetCategoryId: 'c-hall',
      title: 'قاعة الريان',
      totalAmount: '1600000',
    );
    expect(saved, isTrue, reason: provider.errorMessage);
    expect(provider.scheduleById('s-late')!.status, 'PENDING');
    expect(moneyValue(provider.scheduleById('s-late')!.amount), 300000);
    expect(provider.scheduleById('s-next')!.status, 'PENDING');
    expect(moneyValue(provider.scheduleById('s-next')!.amount), 400000);
  });

  test('paying less than a date asks lowers the date by it', () async {
    final provider = await _provider();
    final payment = await provider.paySchedule(
      schedule: provider.scheduleById('s-late')!,
      cost: _hall(provider),
      amount: '100000',
    );
    expect(payment, isNotNull, reason: provider.errorMessage);
    expect(payment!.lowersScheduleId, 's-late');
    final late = _line(provider, 's-late');
    expect(moneyValue(late.amount), 200000);
    expect(moneyValue(late.scheduledAmount), 300000);
    expect(moneyValue(late.paidTowards), 100000);
    expect(late.isOverdue, isTrue);
    expect(moneyValue(_hall(provider).paidAmount), 100000);
    // What is left on the agreement: 1,100,000; the undated rest stays.
    expect(
      moneyValue(
        provider.summary.obligations
            .where((line) => line.kind == MoneyObligationKind.undated)
            .single
            .amount,
      ),
      400000,
    );
  });

  test(
    'paying more pays the date, and the rest goes on the agreement',
    () async {
      final provider = await _provider();
      final payment = await provider.paySchedule(
        schedule: provider.scheduleById('s-late')!,
        cost: _hall(provider),
        amount: '400000',
      );
      expect(payment, isNotNull, reason: provider.errorMessage);
      expect(
        provider.summary.obligations.where((line) => line.id == 's-late'),
        isEmpty,
      );
      expect(moneyValue(_hall(provider).paidAmount), 400000);
      // The next date is untouched; the extra came off the undated rest.
      expect(moneyValue(_line(provider, 's-next').amount), 500000);
      expect(
        moneyValue(
          provider.summary.obligations
              .where((line) => line.kind == MoneyObligationKind.undated)
              .single
              .amount,
        ),
        300000,
      );
    },
  );

  test(
    'a date agreed again moves, and keeps its first day until back',
    () async {
      final provider = await _provider();
      final first = provider.scheduleById('s-next')!.dueDate;
      final later = DateTime.parse(_day(20));
      expect(
        await provider.moveSchedule(
          schedule: provider.scheduleById('s-next')!,
          cost: _hall(provider),
          dueDate: later,
        ),
        isTrue,
        reason: provider.errorMessage,
      );
      var line = _line(provider, 's-next');
      expect(planDayToJson(line.dueDate!), planDayToJson(later));
      expect(planDayToJson(line.rescheduledFrom!), planDayToJson(first));
      expect(moneyValue(line.amount), 500000);

      expect(
        await provider.moveSchedule(
          schedule: provider.scheduleById('s-next')!,
          cost: _hall(provider),
          dueDate: first,
        ),
        isTrue,
        reason: provider.errorMessage,
      );
      line = _line(provider, 's-next');
      expect(line.rescheduledFrom, isNull);
    },
  );

  test('a late date agreed again is no longer late', () async {
    final provider = await _provider();
    expect(
      await provider.moveSchedule(
        schedule: provider.scheduleById('s-late')!,
        cost: _hall(provider),
        dueDate: DateTime.parse(_day(5)),
      ),
      isTrue,
      reason: provider.errorMessage,
    );
    expect(_line(provider, 's-late').isOverdue, isFalse);
  });

  test('its own reminder day lies between today and the date', () async {
    final provider = await _provider();
    final ok = await provider.setScheduleReminder(
      schedule: provider.scheduleById('s-next')!,
      cost: _hall(provider),
      remindAt: DateTime.parse(_day(9)),
    );
    expect(ok, isTrue, reason: provider.errorMessage);
    expect(
      planDayToJson(_line(provider, 's-next').remindAt!),
      planDayToJson(DateTime.parse(_day(9))),
    );

    // After the date: refused, in Arabic.
    final late = await provider.setScheduleReminder(
      schedule: provider.scheduleById('s-next')!,
      cost: _hall(provider),
      remindAt: DateTime.parse(_day(15)),
    );
    expect(late, isFalse);
    expect(provider.errorMessage, isNotNull);
    expect(provider.errorMessage, isNot(matches(RegExp('[A-Za-z]{4}'))));

    // Back to the default.
    expect(
      await provider.setScheduleReminder(
        schedule: provider.scheduleById('s-next')!,
        cost: _hall(provider),
        remindAt: null,
      ),
      isTrue,
    );
    expect(_line(provider, 's-next').remindAt, isNull);
  });

  test(
    'taking a partial payment back gives the date its amount back',
    () async {
      final provider = await _provider();
      final payment = await provider.paySchedule(
        schedule: provider.scheduleById('s-late')!,
        cost: _hall(provider),
        amount: '100000',
      );
      expect(payment, isNotNull);
      final reversed = await provider.reversePayment(
        payment: payment!,
        cost: _hall(provider),
        reason: 'غلطت في المبلغ',
      );
      expect(reversed, isTrue, reason: provider.errorMessage);
      final late = _line(provider, 's-late');
      expect(moneyValue(late.amount), 300000);
      expect(moneyValue(late.paidTowards), 0);
      expect(moneyValue(_hall(provider).paidAmount), 0);
    },
  );
}

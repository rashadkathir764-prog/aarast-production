// The money tab's answers as the server works them out (D102-D109): what the
// wedding is expected to cost, what is left and on whom, every obligation on
// its day, the dues by month, whether the owner's money covers what is on
// him in time, and the family person by person. The phone shows them; it
// works none of them out for an account plan (C2). A server before D102
// sends none of them: each is null or empty then.

import '../../../core/utils/plan_day.dart';

/// D105, D109: agreements plus the estimates they have not settled.
class MoneyExpectedTotals {
  const MoneyExpectedTotals({
    this.agreed = '0',
    this.estimateLeft = '0',
    this.expected = '0',
    this.unknownCount = 0,
  });

  factory MoneyExpectedTotals.fromJson(Map<String, dynamic> json) {
    return MoneyExpectedTotals(
      agreed: _money(json['agreed']),
      estimateLeft: _money(json['estimateLeft']),
      expected: _money(json['expected']),
      unknownCount: _int(json['unknownCount']),
    );
  }

  final String agreed;

  /// The estimate no agreement settled yet.
  final String estimateLeft;
  final String expected;

  /// Items with no estimate and no agreement for the whole of them: while
  /// any, the recorded cost is not final («مو نهائية»).
  final int unknownCount;
}

class MoneyExpected {
  const MoneyExpected({
    this.wedding = const MoneyExpectedTotals(),
    this.mahr = const MoneyExpectedTotals(),
    this.total = '0',
    this.budgetLeft,
  });

  factory MoneyExpected.fromJson(Map<String, dynamic> json) {
    return MoneyExpected(
      wedding: MoneyExpectedTotals.fromJson(_map(json['wedding'])),
      mahr: MoneyExpectedTotals.fromJson(_map(json['mahr'])),
      total: _money(json['total']),
      budgetLeft: _moneyOrNull(json['budgetLeft']),
    );
  }

  /// The wedding's items: what the budget is compared with (C1).
  final MoneyExpectedTotals wedding;
  final MoneyExpectedTotals mahr;

  /// The whole wedding, the mahr with it («تكلفة العرس المسجّلة»).
  final String total;

  /// The budget less the wedding items' expected cost; negative: over it.
  /// Null without a budget.
  final String? budgetLeft;
}

/// D102: what is left to pay, and on whom.
class MoneyOutstanding {
  const MoneyOutstanding({
    this.total = '0',
    this.owner = '0',
    this.ownerMahr = '0',
    this.others = '0',
  });

  factory MoneyOutstanding.fromJson(Map<String, dynamic> json) {
    return MoneyOutstanding(
      total: _money(json['total']),
      owner: _money(json['owner']),
      ownerMahr: _money(json['ownerMahr']),
      others: _money(json['others']),
    );
  }

  /// «باقي على العرس كله».
  final String total;

  /// «عليك من العرس»: his agreements, shared ones and the mahr he pays.
  final String owner;

  /// Of [owner], the mahr.
  final String ownerMahr;

  /// On the family and the other side.
  final String others;
}

enum MoneyObligationKind { due, undated, loanRepayment, loanUnplanned }

MoneyObligationKind? _obligationKind(Object? value) => switch (value) {
  'DUE' => MoneyObligationKind.due,
  'UNDATED' => MoneyObligationKind.undated,
  'LOAN_REPAYMENT' => MoneyObligationKind.loanRepayment,
  'LOAN_UNPLANNED' => MoneyObligationKind.loanUnplanned,
  _ => null,
};

/// D102, D106: one thing still to pay.
class MoneyObligation {
  const MoneyObligation({
    required this.kind,
    required this.id,
    required this.title,
    required this.amount,
    this.weddingCostId,
    this.budgetCategoryId,
    this.fundingSourceId,
    this.note,
    this.scheduledAmount = '0',
    this.paidTowards = '0',
    this.dueDate,
    this.isOverdue = false,
    this.remindAt,
    this.rescheduledFrom,
    this.payer,
    this.payerName,
    this.ownerMoney = true,
    this.mahr = false,
  });

  static MoneyObligation? fromJson(Map<String, dynamic> json) {
    final kind = _obligationKind(json['kind']);
    final id = json['id']?.toString();
    if (kind == null || id == null || id.isEmpty) return null;
    return MoneyObligation(
      kind: kind,
      id: id,
      weddingCostId: _string(json['weddingCostId']),
      budgetCategoryId: _string(json['budgetCategoryId']),
      fundingSourceId: _string(json['fundingSourceId']),
      title: json['title']?.toString() ?? '',
      note: _string(json['note']),
      amount: _money(json['amount']),
      scheduledAmount: _money(json['scheduledAmount']),
      paidTowards: _money(json['paidTowards']),
      dueDate: planDayFromJson(json['dueDate']),
      isOverdue: json['isOverdue'] == true,
      remindAt: planDayFromJson(json['remindAt']),
      rescheduledFrom: planDayFromJson(json['rescheduledFrom']),
      payer: _string(json['payer']),
      payerName: _string(json['payerName']),
      ownerMoney: json['ownerMoney'] != false,
      mahr: json['mahr'] == true,
    );
  }

  final MoneyObligationKind kind;

  /// The date ([MoneyObligationKind.due]), the agreement (undated), the
  /// repayment, or the loan (its part with no plan).
  final String id;
  final String? weddingCostId;
  final String? budgetCategoryId;
  final String? fundingSourceId;
  final String title;
  final String? note;

  /// Still to pay on it now.
  final String amount;

  /// A date as agreed, before partial payments («اندفع X من Y»).
  final String scheduledAmount;
  final String paidTowards;
  final DateTime? dueDate;
  final bool isOverdue;
  final DateTime? remindAt;
  final DateTime? rescheduledFrom;
  final String? payer;
  final String? payerName;

  /// On the owner (D59): his agreements and his loans.
  final bool ownerMoney;
  final bool mahr;

  bool get isLoan =>
      kind == MoneyObligationKind.loanRepayment ||
      kind == MoneyObligationKind.loanUnplanned;
  bool get isPartlyPaid => _value(paidTowards) > 0;
}

class MoneyBucket {
  const MoneyBucket({this.amount = '0', this.ownerAmount = '0', this.count = 0});

  factory MoneyBucket.fromJson(Map<String, dynamic> json) {
    return MoneyBucket(
      amount: _money(json['amount']),
      ownerAmount: _money(json['ownerAmount']),
      count: _int(json['count']),
    );
  }

  final String amount;

  /// Of [amount], on the owner.
  final String ownerAmount;
  final int count;
}

/// D102: the wedding's dues by month (loans are not wedding dues).
class MoneyDuesByMonth {
  const MoneyDuesByMonth({
    this.months = const [],
    this.overdue = const MoneyBucket(),
    this.undated = const MoneyBucket(),
  });

  factory MoneyDuesByMonth.fromJson(Map<String, dynamic> json) {
    return MoneyDuesByMonth(
      months: [
        for (final month in _listOfMaps(json['months']))
          if (_month(month['month']) case final key?)
            (month: key, bucket: MoneyBucket.fromJson(month)),
      ],
      overdue: MoneyBucket.fromJson(_map(json['overdue'])),
      undated: MoneyBucket.fromJson(_map(json['undated'])),
    );
  }

  /// In order; each month is its first day.
  final List<({DateTime month, MoneyBucket bucket})> months;
  final MoneyBucket overdue;
  final MoneyBucket undated;
}

enum MoneyCoverageVerdict { nothingDue, covered, coveredIfPledges, short }

MoneyCoverageVerdict? _verdict(Object? value) => switch (value) {
  'NOTHING_DUE' => MoneyCoverageVerdict.nothingDue,
  'COVERED' => MoneyCoverageVerdict.covered,
  'COVERED_IF_PLEDGES' => MoneyCoverageVerdict.coveredIfPledges,
  'SHORT' => MoneyCoverageVerdict.short,
  _ => null,
};

class MoneyCoverageShort {
  const MoneyCoverageShort({
    required this.amount,
    required this.title,
    required this.id,
    this.date,
  });

  static MoneyCoverageShort? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    return MoneyCoverageShort(
      amount: _money(json['amount']),
      title: json['title']?.toString() ?? '',
      id: json['id']?.toString() ?? '',
      date: planDayFromJson(json['date']),
    );
  }

  final String amount;
  final String title;
  final String id;

  /// Null: an undated line (counted last).
  final DateTime? date;
}

class MoneyCoverageRun {
  const MoneyCoverageRun({this.firstShort, this.deepest, this.end = '0'});

  factory MoneyCoverageRun.fromJson(Map<String, dynamic> json) {
    return MoneyCoverageRun(
      firstShort: MoneyCoverageShort.fromJson(json['firstShort']),
      deepest: MoneyCoverageShort.fromJson(json['deepest']),
      end: _money(json['end']),
    );
  }

  /// The first line the money does not reach, and by how much that day.
  final MoneyCoverageShort? firstShort;

  /// The deepest it falls: what would make everything paid on its day.
  final MoneyCoverageShort? deepest;

  /// Left after everything; negative: short by that much.
  final String end;
}

enum MoneyCoverageStepKind {
  due,
  mahr,
  undated,
  loanRepayment,
  loanUnplanned,
  pledge,
}

MoneyCoverageStepKind? _stepKind(Object? value) => switch (value) {
  'DUE' => MoneyCoverageStepKind.due,
  'MAHR' => MoneyCoverageStepKind.mahr,
  'UNDATED' => MoneyCoverageStepKind.undated,
  'LOAN_REPAYMENT' => MoneyCoverageStepKind.loanRepayment,
  'LOAN_UNPLANNED' => MoneyCoverageStepKind.loanUnplanned,
  'PLEDGE' => MoneyCoverageStepKind.pledge,
  _ => null,
};

/// One line of «كيف حسبناها؟».
class MoneyCoverageStep {
  const MoneyCoverageStep({
    required this.kind,
    required this.id,
    required this.title,
    required this.amount,
    required this.balance,
    this.date,
    this.late = false,
    this.note,
  });

  static MoneyCoverageStep? fromJson(Map<String, dynamic> json) {
    final kind = _stepKind(json['kind']);
    if (kind == null) return null;
    return MoneyCoverageStep(
      kind: kind,
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      note: _string(json['note']),
      amount: _money(json['amount']),
      balance: _money(json['balance']),
      date: planDayFromJson(json['date']),
      late: json['late'] == true,
    );
  }

  final MoneyCoverageStepKind kind;
  final String id;
  final String title;
  final String? note;
  final String amount;

  /// What is left after it.
  final String balance;

  /// The day it counts on (a late line counts today); null: last.
  final DateTime? date;
  final bool late;

  bool get inflow => kind == MoneyCoverageStepKind.pledge;
}

enum MoneyPledgeLeftOut { noDate, late }

class MoneyCoveragePledge {
  const MoneyCoveragePledge({
    required this.id,
    required this.sourceName,
    required this.amount,
    this.expectedAt,
    this.leftOut,
  });

  factory MoneyCoveragePledge.fromJson(Map<String, dynamic> json) {
    return MoneyCoveragePledge(
      id: json['id']?.toString() ?? '',
      sourceName: json['sourceName']?.toString() ?? '',
      amount: _money(json['amount']),
      expectedAt: planDayFromJson(json['expectedAt']),
      leftOut: switch (json['reason']) {
        'NO_DATE' => MoneyPledgeLeftOut.noDate,
        'LATE' => MoneyPledgeLeftOut.late,
        _ => null,
      },
    );
  }

  final String id;
  final String sourceName;
  final String amount;
  final DateTime? expectedAt;

  /// Why it was not counted; null: it was.
  final MoneyPledgeLeftOut? leftOut;
}

/// D103: the owner's money against what is on him, on its days.
class MoneyCoverage {
  const MoneyCoverage({
    required this.verdict,
    this.cash = '0',
    this.total = '0',
    this.undated = '0',
    this.lastDate,
    this.hasLoan = false,
    this.withoutPledges = const MoneyCoverageRun(),
    this.withPledges = const MoneyCoverageRun(),
    this.steps = const [],
    this.pledgesCounted = const [],
    this.pledgesIgnored = const [],
    this.estimatesLeft = '0',
    this.endAfterEstimates = '0',
  });

  static MoneyCoverage? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final verdict = _verdict(json['verdict']);
    if (verdict == null) return null;
    final estimates = _map(json['estimates']);
    return MoneyCoverage(
      verdict: verdict,
      cash: _money(json['cash']),
      total: _money(json['total']),
      undated: _money(json['undated']),
      lastDate: planDayFromJson(json['lastDate']),
      hasLoan: json['hasLoan'] == true,
      withoutPledges: MoneyCoverageRun.fromJson(_map(json['withoutPledges'])),
      withPledges: MoneyCoverageRun.fromJson(_map(json['withPledges'])),
      steps: [
        for (final step in _listOfMaps(json['steps']))
          ?MoneyCoverageStep.fromJson(step),
      ],
      pledgesCounted: [
        for (final pledge in _listOfMaps(json['pledgesCounted']))
          MoneyCoveragePledge.fromJson(pledge),
      ],
      pledgesIgnored: [
        for (final pledge in _listOfMaps(json['pledgesIgnored']))
          MoneyCoveragePledge.fromJson(pledge),
      ],
      estimatesLeft: _money(estimates['left']),
      endAfterEstimates: _money(estimates['endAfter']),
    );
  }

  final MoneyCoverageVerdict verdict;

  /// «معك» now (D104).
  final String cash;

  /// Everything on him: his share, the mahr with it, his loans.
  final String total;

  /// Of [total], what has no day (counted last).
  final String undated;
  final DateTime? lastDate;
  final bool hasLoan;
  final MoneyCoverageRun withoutPledges;
  final MoneyCoverageRun withPledges;

  /// «كيف حسبناها؟»: the account with the promised money that counts.
  final List<MoneyCoverageStep> steps;
  final List<MoneyCoveragePledge> pledgesCounted;
  final List<MoneyCoveragePledge> pledgesIgnored;

  /// The estimates' «if»: still expected, and what would be left after them.
  final String estimatesLeft;
  final String endAfterEstimates;

  /// The day and amount the sentence names: short with the promises
  /// ([MoneyCoverageVerdict.short]), or without them (covered only if).
  MoneyCoverageShort? get namedShort => switch (verdict) {
    MoneyCoverageVerdict.short => withPledges.firstShort,
    MoneyCoverageVerdict.coveredIfPledges => withoutPledges.firstShort,
    _ => null,
  };
}

/// D108: one person of the family.
class MoneyContributor {
  const MoneyContributor({
    this.name,
    this.payer,
    this.gave = '0',
    this.promised = '0',
    this.paid = '0',
    this.left = '0',
    this.costsCount = 0,
  });

  factory MoneyContributor.fromJson(Map<String, dynamic> json) {
    return MoneyContributor(
      name: _string(json['name']),
      payer: _string(json['payer']),
      gave: _money(json['gave']),
      promised: _money(json['promised']),
      paid: _money(json['paid']),
      left: _money(json['left']),
      costsCount: _int(json['costsCount']),
    );
  }

  /// Null: agreements of one payer with no name («الأهل»).
  final String? name;
  final String? payer;

  /// Reached the owner (in «وصلك»).
  final String gave;
  final String promised;

  /// Paid straight to the shops (never in «وصلك», D59).
  final String paid;
  final String left;
  final int costsCount;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<Map<String, dynamic>> _listOfMaps(Object? value) => value is List
    ? [
        for (final item in value)
          if (item is Map) Map<String, dynamic>.from(item),
      ]
    : const [];

String? _string(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

String _money(Object? value) => _moneyOrNull(value) ?? '0';

String? _moneyOrNull(Object? value) {
  final text = _string(value);
  return text == null || double.tryParse(text) == null ? null : text;
}

double _value(String text) => double.tryParse(text) ?? 0;

int _int(Object? value) => int.tryParse(value?.toString() ?? '') ?? 0;

DateTime? _month(Object? value) {
  final match = RegExp(r'^(\d{4})-(\d{2})$').firstMatch(value?.toString() ?? '');
  if (match == null) return null;
  return DateTime(int.parse(match.group(1)!), int.parse(match.group(2)!));
}

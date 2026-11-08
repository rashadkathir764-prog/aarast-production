// The money tab's rules for a plan kept on the phone (D103-D109), the twin
// of the server's (backend `modules/finance/domain`: expected-cost-policy,
// money-timeline-policy, family-contributions-policy; composed by
// money-plan-policy). An account plan never uses this: the server works its
// money out (C2). The answers are in the server's own JSON shape, so one
// model reads both; `money_plan_parity_test.dart` holds the two to the same
// answers on the server's fixtures (`money_plan_fixtures.json`).
//
// Amounts are whole cents (int), so no sum drifts the way doubles do; days
// are Sana'a days as YYYY-MM-DD, compared as text.

part 'finance_local_money_plan.timeline.dart';
part 'finance_local_money_plan.family.dart';

/// One plan's money as the phone keeps it, in the fixtures' shape:
/// `{today, budget, mahrPays, items, costs, schedules, sources}`. Amounts
/// are decimal strings, days YYYY-MM-DD; `sources` is null for a reader who
/// may not see them.
Map<String, dynamic> localMoneyPlan(Map<String, dynamic> input) {
  final plan = _Plan.fromJson(input);
  return plan.answer();
}

int _cents(Object? value) {
  final text = value?.toString().replaceAll(',', '').trim() ?? '';
  final parsed = num.tryParse(text);
  return parsed == null ? 0 : (parsed * 100).round();
}

int? _centsOrNull(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty || num.tryParse(text) == null ? null : _cents(text);
}

String _money(int cents) {
  final negative = cents < 0;
  final abs = cents.abs();
  final whole = abs ~/ 100;
  final part = abs % 100;
  final text = part == 0
      ? '$whole'
      : part % 10 == 0
          ? '$whole.${part ~/ 10}'
          : '$whole.${part.toString().padLeft(2, '0')}';
  return negative ? '-$text' : text;
}

String? _day(Object? value) {
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) return null;
  final day = parsed.isUtc ? parsed.add(const Duration(hours: 3)) : parsed;
  return '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}

String? _text(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

int _min(int a, int b) => a < b ? a : b;

class _Item {
  _Item(this.json)
    : id = json['id'].toString(),
      mahr = json['kind'] == 'MAHR',
      allocated = _centsOrNull(json['allocatedAmount']),
      estimated = _centsOrNull(json['estimatedAmount']),
      notNeeded = json['notNeeded'] == true;

  final Map<String, dynamic> json;
  final String id;
  final bool mahr;
  final int? allocated;
  final int? estimated;
  final bool notNeeded;
}

class _Cost {
  _Cost(Map<String, dynamic> json)
    : id = json['id'].toString(),
      itemId = json['budgetCategoryId'].toString(),
      title = json['title']?.toString() ?? '',
      total = _cents(json['totalAmount']),
      paid = _cents(json['paid']),
      payer = _text(json['payer']),
      payerName = _text(json['payerName']),
      ownerMoney = json['ownerMoney'] != false,
      part = json['estimateCover'] == 'PART',
      estimatePart = _centsOrNull(json['estimatePart']);

  final String id;
  final String itemId;
  final String title;
  final int total;
  final int paid;
  final String? payer;
  final String? payerName;
  final bool ownerMoney;

  /// Missing: WHOLE, as every agreement written before D105.
  final bool part;
  final int? estimatePart;
  bool mahr = false;
}

class _Schedule {
  _Schedule(Map<String, dynamic> json, this.order)
    : id = json['id'].toString(),
      costId = json['weddingCostId'].toString(),
      amount = _cents(json['amount']),
      due = _day(json['dueDate'])!,
      status = json['status']?.toString() ?? 'PENDING',
      note = _text(json['note']),
      remindAt = _day(json['remindAt']),
      rescheduledFrom = _day(json['rescheduledFrom']),
      partlyPaid = _cents(json['partlyPaid']),
      createdAt = json['createdAt']?.toString() ?? '';

  final int order;
  final String id;
  final String costId;
  final int amount;
  final String due;
  final String status;
  final String? note;
  final String? remindAt;
  final String? rescheduledFrom;
  final int partlyPaid;
  final String createdAt;
}

class _Repayment {
  _Repayment(Map<String, dynamic> json)
    : id = json['id'].toString(),
      amount = _cents(json['amount']),
      due = _day(json['dueDate']),
      status = json['status']?.toString() ?? 'PLANNED',
      note = _text(json['note']);

  final String id;
  final int amount;
  final String? due;
  final String status;
  final String? note;
}

class _Source {
  _Source(Map<String, dynamic> json)
    : id = json['id'].toString(),
      kind = json['kind']?.toString() ?? 'OTHER',
      name = json['sourceName']?.toString() ?? '',
      contributor = _text(json['contributorName']),
      amount = _cents(json['amount']),
      received = json['status'] != 'PLEDGED',
      expected = _day(json['expectedAt']),
      repayments = [
        for (final item in json['repayments'] as List? ?? const [])
          if (item is Map) _Repayment(Map<String, dynamic>.from(item)),
      ];

  final String id;
  final String kind;
  final String name;
  final String? contributor;
  final int amount;
  final bool received;
  final String? expected;
  final List<_Repayment> repayments;
}

class _Line {
  _Line({
    required this.kind,
    required this.id,
    required this.title,
    required this.amount,
    this.costId,
    this.itemId,
    this.sourceId,
    this.note,
    int? scheduled,
    this.paidTowards = 0,
    this.due,
    this.today = '',
    this.remindAt,
    this.rescheduledFrom,
    this.payer,
    this.payerName,
    this.ownerMoney = true,
    this.mahr = false,
  }) : scheduled = scheduled ?? amount;

  final String kind;
  final String id;
  final String title;
  final int amount;
  final String? costId;
  final String? itemId;
  final String? sourceId;
  final String? note;
  final int scheduled;
  final int paidTowards;
  final String? due;
  final String today;
  final String? remindAt;
  final String? rescheduledFrom;
  final String? payer;
  final String? payerName;
  final bool ownerMoney;
  final bool mahr;

  bool get overdue => due != null && due!.compareTo(today) < 0;

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'id': id,
    'weddingCostId': costId,
    'budgetCategoryId': itemId,
    'fundingSourceId': sourceId,
    'title': title,
    'note': note,
    'amount': _money(amount),
    'scheduledAmount': _money(scheduled),
    'paidTowards': _money(paidTowards),
    'dueDate': due,
    'isOverdue': overdue,
    'remindAt': remindAt,
    'rescheduledFrom': rescheduledFrom,
    'payer': payer,
    'payerName': payerName,
    'ownerMoney': ownerMoney,
    'mahr': mahr,
  };
}

class _Step {
  _Step({
    required this.kind,
    required this.id,
    required this.date,
    required this.late,
    required this.title,
    required this.note,
    required this.amount,
    required this.inflow,
    required this.order,
  });

  final String kind;
  final String id;
  final String? date;
  final bool late;
  final String title;
  final String? note;
  final int amount;
  final bool inflow;
  final int order;
  int balance = 0;
}

class _Short {
  const _Short(this.date, this.amount, this.title, this.id);
  final String? date;
  final int amount;
  final String title;
  final String id;

  Map<String, dynamic> toJson() => {
    'date': date,
    'amount': _money(amount),
    'title': title,
    'id': id,
  };
}

class _Run {
  _Run(this.steps, this.firstShort, this.deepest, this.end);
  final List<_Step> steps;
  final _Short? firstShort;
  final _Short? deepest;
  final int end;

  Map<String, dynamic> toJson() => {
    'firstShort': firstShort?.toJson(),
    'deepest': deepest?.toJson(),
    'end': _money(end),
  };
}

class _Plan {
  _Plan._({
    required this.today,
    required this.budget,
    required this.mahrPays,
    required this.items,
    required this.costs,
    required this.schedules,
    required this.sources,
    required this.cash,
  });

  factory _Plan.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> maps(Object? value) => [
      for (final item in value as List? ?? const [])
        if (item is Map) Map<String, dynamic>.from(item),
    ];
    final items = maps(json['items']).map(_Item.new).toList();
    final mahrItems = {
      for (final item in items)
        if (item.mahr) item.id,
    };
    final costs = maps(json['costs']).map(_Cost.new).toList();
    for (final cost in costs) {
      cost.mahr = mahrItems.contains(cost.itemId);
    }
    final rawSchedules = maps(json['schedules']);
    return _Plan._(
      today: _day(json['today'])!,
      budget: _centsOrNull(json['budget']),
      mahrPays: json['mahrPays'] == true,
      items: items,
      costs: costs,
      schedules: [
        for (var i = 0; i < rawSchedules.length; i++)
          _Schedule(rawSchedules[i], i),
      ],
      sources: json['sources'] is List
          ? maps(json['sources']).map(_Source.new).toList()
          : null,
      cash: _centsOrNull(json['cash']),
    );
  }

  final String today;
  final int? budget;
  final bool mahrPays;
  final List<_Item> items;
  final List<_Cost> costs;
  final List<_Schedule> schedules;
  final List<_Source>? sources;

  /// «معك» as worked out with the funding (D104); null: worked out here.
  final int? cash;

  // ------------------------------------------------------------ D105, D109

  Map<String, dynamic> _expectedItem(_Item? item, List<_Cost> itemCosts) {
    final estimate = item?.estimated ?? item?.allocated;
    final source = item?.estimated != null
        ? 'ESTIMATE'
        : item?.allocated != null
            ? 'ALLOCATION'
            : null;
    final agreed = itemCosts.fold<int>(0, (sum, cost) => sum + cost.total);
    final whole = itemCosts.any((cost) => !cost.part);
    final parts = itemCosts.fold<int>(
      0,
      (sum, cost) => cost.part ? sum + (cost.estimatePart ?? cost.total) : sum,
    );
    final int estimateLeft;
    if (whole || estimate == null) {
      estimateLeft = 0;
    } else {
      estimateLeft = estimate - _min(parts, estimate);
    }
    final known =
        whole ||
        estimate != null ||
        ((item?.notNeeded ?? false) && itemCosts.isEmpty);
    return {
      'estimate': estimate,
      'estimateSource': source,
      'agreed': agreed,
      'estimateLeft': estimateLeft,
      'expected': agreed + estimateLeft,
      'costKnown': known,
    };
  }

  Map<String, dynamic> _sum(Iterable<Map<String, dynamic>> rows) {
    var agreed = 0, left = 0, expected = 0, unknown = 0;
    for (final row in rows) {
      agreed += row['agreed'] as int;
      left += row['estimateLeft'] as int;
      expected += row['expected'] as int;
      if (row['costKnown'] != true) unknown += 1;
    }
    return {
      'agreed': agreed,
      'estimateLeft': left,
      'expected': expected,
      'unknownCount': unknown,
    };
  }

  Map<String, dynamic> _totalsJson(Map<String, dynamic> totals) => {
    'agreed': _money(totals['agreed'] as int),
    'estimateLeft': _money(totals['estimateLeft'] as int),
    'expected': _money(totals['expected'] as int),
    'unknownCount': totals['unknownCount'],
  };

  // -------------------------------------------------------------- the whole

  Map<String, dynamic> answer() {
    final shown = {for (final item in items) item.id};
    final byItem = <String, List<_Cost>>{};
    for (final cost in costs) {
      byItem.putIfAbsent(cost.itemId, () => []).add(cost);
    }
    final itemRows = <String, Map<String, dynamic>>{
      for (final item in items) item.id: _expectedItem(item, byItem[item.id] ?? const []),
    };
    final outside = [
      for (final cost in costs)
        if (!shown.contains(cost.itemId)) _expectedItem(null, [cost]),
    ];
    final wedding = _sum([
      for (final item in items)
        if (!item.mahr) itemRows[item.id]!,
      ...outside,
    ]);
    final mahr = _sum([
      for (final item in items)
        if (item.mahr) itemRows[item.id]!,
    ]);
    final lines = _obligations();
    int owed(Iterable<_Cost> rows) => rows.fold<int>(0, (sum, cost) {
      final left = cost.total - cost.paid;
      return sum + (left > 0 ? left : 0);
    });
    final estimateLeft =
        (wedding['estimateLeft'] as int) +
        (mahrPays ? mahr['estimateLeft'] as int : 0);
    return {
      'items': [
        for (final item in items)
          {
            'id': item.id,
            'estimate': itemRows[item.id]!['estimate'] == null
                ? null
                : _money(itemRows[item.id]!['estimate'] as int),
            'estimateSource': itemRows[item.id]!['estimateSource'],
            'expectedCost': _money(itemRows[item.id]!['expected'] as int),
            'estimateLeft': _money(itemRows[item.id]!['estimateLeft'] as int),
            'costKnown': itemRows[item.id]!['costKnown'],
            'overBudget': item.allocated == null
                ? null
                : (itemRows[item.id]!['expected'] as int) > item.allocated!,
          },
      ],
      'expected': {
        'wedding': _totalsJson(wedding),
        'mahr': _totalsJson(mahr),
        'total': _money((wedding['expected'] as int) + (mahr['expected'] as int)),
        'budgetLeft': budget == null
            ? null
            : _money(budget! - (wedding['expected'] as int)),
      },
      'outstanding': {
        'total': _money(owed(costs)),
        'owner': _money(owed(costs.where((cost) => cost.ownerMoney))),
        'ownerMahr': _money(
          owed(costs.where((cost) => cost.ownerMoney && cost.mahr)),
        ),
        'others': _money(owed(costs.where((cost) => !cost.ownerMoney))),
      },
      'obligations': [for (final line in lines) line.toJson()],
      'duesByMonth': _duesByMonth(lines),
      'coverage': _coverage(lines, estimateLeft),
      'family': _family(),
    };
  }
}

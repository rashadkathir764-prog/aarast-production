part of 'finance_local_money_plan.dart';

/// D102, D106: what is still to pay and when; D103, D104: whether the
/// owner's money covers what is on him, in time (backend
/// money-timeline-policy).
extension _Timeline on _Plan {
  // ------------------------------------------------------------ D102, D106

  Map<String, int> _openSchedules(_Cost cost, List<_Schedule> list) {
    final pending = list.where((s) => s.status == 'PENDING').toList()
      ..sort((a, b) {
        final byDue = a.due.compareTo(b.due);
        if (byDue != 0) return byDue;
        final byCreated = a.createdAt.compareTo(b.createdAt);
        if (byCreated != 0) return byCreated;
        return a.id.compareTo(b.id);
      });
    var room = cost.total - cost.paid;
    if (room < 0) room = 0;
    final open = <String, int>{};
    for (final schedule in pending) {
      final amount = _min(schedule.amount, room);
      open[schedule.id] = amount;
      room -= amount;
    }
    return open;
  }

  List<_Line> _obligations() {
    final out = <_Line>[];
    final byCost = <String, List<_Schedule>>{};
    for (final schedule in schedules) {
      byCost.putIfAbsent(schedule.costId, () => []).add(schedule);
    }
    for (final cost in costs) {
      final list = byCost[cost.id] ?? const <_Schedule>[];
      final open = _openSchedules(cost, list);
      var dated = 0;
      for (final schedule in list) {
        final amount = open[schedule.id];
        if (amount == null || amount <= 0) continue;
        dated += amount;
        out.add(
          _Line(
            kind: 'DUE',
            id: schedule.id,
            costId: cost.id,
            itemId: cost.itemId,
            title: cost.title,
            note: schedule.note,
            amount: amount,
            scheduled: schedule.amount + schedule.partlyPaid,
            paidTowards: schedule.partlyPaid,
            due: schedule.due,
            today: today,
            remindAt: schedule.remindAt,
            rescheduledFrom: schedule.rescheduledFrom,
            payer: cost.payer,
            payerName: cost.payerName,
            ownerMoney: cost.ownerMoney,
            mahr: cost.mahr,
          ),
        );
      }
      final rest = cost.total - cost.paid - dated;
      if (rest > 0) {
        out.add(
          _Line(
            kind: 'UNDATED',
            id: cost.id,
            costId: cost.id,
            itemId: cost.itemId,
            title: cost.title,
            amount: rest,
            today: today,
            payer: cost.payer,
            payerName: cost.payerName,
            ownerMoney: cost.ownerMoney,
            mahr: cost.mahr,
          ),
        );
      }
    }
    for (final source in sources ?? const <_Source>[]) {
      if (source.kind != 'LOAN' || !source.received) continue;
      out.addAll(_loanLines(source));
    }
    return _byDay(out, (line) => line.due);
  }

  List<_Line> _loanLines(_Source source) {
    final out = <_Line>[];
    var repaid = 0, planned = 0;
    for (final repayment in source.repayments) {
      if (repayment.status == 'PAID') {
        repaid += repayment.amount;
        continue;
      }
      if (repayment.status != 'PLANNED') continue;
      planned += repayment.amount;
      out.add(
        _Line(
          kind: 'LOAN_REPAYMENT',
          id: repayment.id,
          sourceId: source.id,
          title: source.name,
          note: repayment.note,
          amount: repayment.amount,
          due: repayment.due,
          today: today,
        ),
      );
    }
    final unplanned = source.amount - repaid - planned;
    if (unplanned > 0) {
      out.add(
        _Line(
          kind: 'LOAN_UNPLANNED',
          id: source.id,
          sourceId: source.id,
          title: source.name,
          amount: unplanned,
          today: today,
        ),
      );
    }
    return out;
  }

  /// Stable: by day, undated last; the input order breaks ties.
  List<T> _byDay<T>(List<T> rows, String? Function(T) dayOf) {
    final indexed = [
      for (var i = 0; i < rows.length; i++) (row: rows[i], index: i),
    ];
    indexed.sort((a, b) {
      final ad = dayOf(a.row);
      final bd = dayOf(b.row);
      if (ad == null || bd == null) {
        final byNull = (ad == null ? 1 : 0) - (bd == null ? 1 : 0);
        return byNull != 0 ? byNull : a.index - b.index;
      }
      final byDay = ad.compareTo(bd);
      return byDay != 0 ? byDay : a.index - b.index;
    });
    return [for (final entry in indexed) entry.row];
  }

  Map<String, dynamic> _duesByMonth(List<_Line> lines) {
    final months = <String, List<int>>{};
    final overdue = [0, 0, 0];
    final undated = [0, 0, 0];
    void add(List<int> bucket, _Line line) {
      bucket[0] += line.amount;
      if (line.ownerMoney) bucket[1] += line.amount;
      bucket[2] += 1;
    }

    for (final line in lines) {
      if (line.kind != 'DUE' && line.kind != 'UNDATED') continue;
      if (line.due == null) {
        add(undated, line);
      } else if (line.overdue) {
        add(overdue, line);
      } else {
        add(months.putIfAbsent(line.due!.substring(0, 7), () => [0, 0, 0]), line);
      }
    }
    Map<String, dynamic> bucket(List<int> value) => {
      'amount': _money(value[0]),
      'ownerAmount': _money(value[1]),
      'count': value[2],
    };
    final keys = months.keys.toList()..sort();
    return {
      'months': [
        for (final key in keys) {'month': key, ...bucket(months[key]!)},
      ],
      'overdue': bucket(overdue),
      'undated': bucket(undated),
    };
  }

  // ------------------------------------------------------------ D103, D104

  _Step _outflow(_Line line, int order) {
    final late = line.due != null && line.due!.compareTo(today) < 0;
    return _Step(
      kind: line.kind == 'DUE' ? (line.mahr ? 'MAHR' : 'DUE') : line.kind,
      id: line.id,
      date: line.due == null ? null : (late ? today : line.due),
      late: late,
      title: line.title,
      note: line.note,
      amount: line.amount,
      inflow: false,
      order: order,
    );
  }

  _Run _run(int start, List<_Step> lines) {
    final ordered = [...lines]
      ..sort((a, b) {
        if (a.date == null || b.date == null) {
          final byNull = (a.date == null ? 1 : 0) - (b.date == null ? 1 : 0);
          return byNull != 0 ? byNull : a.order - b.order;
        }
        final byDay = a.date!.compareTo(b.date!);
        if (byDay != 0) return byDay;
        final byFlow = (a.inflow ? 1 : 0) - (b.inflow ? 1 : 0);
        return byFlow != 0 ? byFlow : a.order - b.order;
      });
    var balance = start;
    _Short? first;
    _Short? deepest;
    final steps = <_Step>[];
    for (final line in ordered) {
      balance += line.inflow ? line.amount : -line.amount;
      final step = _Step(
        kind: line.kind,
        id: line.id,
        date: line.date,
        late: line.late,
        title: line.title,
        note: line.note,
        amount: line.amount,
        inflow: line.inflow,
        order: line.order,
      )..balance = balance;
      steps.add(step);
      if (balance < 0) {
        final short = _Short(line.date, -balance, line.title, line.id);
        first ??= short;
        if (deepest == null || short.amount > deepest.amount) deepest = short;
      }
    }
    return _Run(steps, first, deepest, balance);
  }

  Map<String, dynamic>? _coverage(List<_Line> lines, int estimateLeft) {
    final sources = this.sources;
    if (sources == null || sources.isEmpty) return null;
    var order = 0;
    final outflows = [
      for (final line in lines)
        if (line.ownerMoney) _outflow(line, order++),
    ];
    final counted = <_Source>[];
    final ignored = <Map<String, dynamic>>[];
    for (final source in sources) {
      if (source.received) continue;
      final pledge = {
        'id': source.id,
        'sourceName': source.name,
        'amount': _money(source.amount),
        'expectedAt': source.expected,
      };
      if (source.expected == null) {
        ignored.add({...pledge, 'reason': 'NO_DATE'});
      } else if (source.expected!.compareTo(today) < 0) {
        ignored.add({...pledge, 'reason': 'LATE'});
      } else {
        counted.add(source);
      }
    }
    final pledgeLines = <_Step>[];
    for (final source in counted) {
      pledgeLines.add(
        _Step(
          kind: 'PLEDGE',
          id: source.id,
          date: source.expected,
          late: false,
          title: source.name,
          note: null,
          amount: source.amount,
          inflow: true,
          order: order++,
        ),
      );
      if (source.kind == 'LOAN') {
        for (final line in _loanLines(source)) {
          pledgeLines.add(_outflow(line, order++));
        }
      }
    }
    final cash = this.cash ?? _cashHere();
    final without = _run(cash, outflows);
    final withPledges = _run(cash, [...outflows, ...pledgeLines]);
    final total = outflows.fold<int>(0, (sum, line) => sum + line.amount);
    final dated = [
      for (final line in outflows)
        if (line.date != null) line.date!,
    ]..sort();
    final verdict = total <= 0
        ? 'NOTHING_DUE'
        : without.deepest == null
            ? 'COVERED'
            : withPledges.deepest == null
                ? 'COVERED_IF_PLEDGES'
                : 'SHORT';
    return {
      'verdict': verdict,
      'cash': _money(cash),
      'total': _money(total),
      'undated': _money(
        outflows
            .where((line) => line.date == null)
            .fold<int>(0, (sum, line) => sum + line.amount),
      ),
      'lastDate': dated.isEmpty ? null : dated.last,
      'hasLoan': outflows.any(
        (line) => line.kind == 'LOAN_REPAYMENT' || line.kind == 'LOAN_UNPLANNED',
      ),
      'withoutPledges': without.toJson(),
      'withPledges': withPledges.toJson(),
      'steps': [
        for (final step in withPledges.steps)
          {
            'kind': step.kind,
            'id': step.id,
            'date': step.date,
            'late': step.late,
            'title': step.title,
            'note': step.note,
            'amount': _money(step.amount),
            'inflow': step.inflow,
            'balance': _money(step.balance),
          },
      ],
      'pledgesCounted': [
        for (final source in counted)
          {
            'id': source.id,
            'sourceName': source.name,
            'amount': _money(source.amount),
            'expectedAt': source.expected,
          },
      ],
      'pledgesIgnored': ignored,
      'estimates': {
        'left': _money(estimateLeft),
        'endAfter': _money(withPledges.end - estimateLeft),
      },
    };
  }

  /// D104: received − what his money paid − what he repaid; never below zero.
  int _cashHere() {
    var received = 0, repaid = 0;
    for (final source in sources ?? const <_Source>[]) {
      if (source.received) received += source.amount;
      if (source.kind == 'LOAN' && source.received) {
        for (final repayment in source.repayments) {
          if (repayment.status == 'PAID') repaid += repayment.amount;
        }
      }
    }
    final paidByOwner = costs
        .where((cost) => cost.ownerMoney)
        .fold<int>(0, (sum, cost) => sum + cost.paid);
    final left = received - paidByOwner - repaid;
    return left > 0 ? left : 0;
  }
}

part of 'finance_local_money_plan.dart';

/// D108: a person's name as it is matched: trimmed, spaces folded, case
/// folded (backend `contributorKey`).
String? _contributorKey(String? name) {
  final folded = (name ?? '')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ')
      .toLowerCase();
  return folded.isEmpty ? null : folded;
}

/// D108: the family, person by person (backend family-contributions-policy).
extension _Family on _Plan {
  // ----------------------------------------------------------------- D108

  List<Map<String, dynamic>>? _family() {
    final sources = this.sources;
    if (sources == null) return null;
    final people = <String, Map<String, dynamic>>{};
    Map<String, dynamic> personOf(String? name, String? payer) {
      final key = name == null ? '#${payer ?? ''}' : _contributorKey(name)!;
      return people.putIfAbsent(
        key,
        () => {
          'name': name?.trim().replaceAll(RegExp(r'\s+'), ' '),
          'payer': null,
          'gave': 0,
          'promised': 0,
          'paid': 0,
          'left': 0,
          'costsCount': 0,
        },
      );
    }

    for (final source in sources) {
      if (source.kind == 'LOAN' ||
          _contributorKey(source.contributor) == null) {
        continue;
      }
      final person = personOf(source.contributor, null);
      final field = source.received ? 'gave' : 'promised';
      person[field] = (person[field] as int) + source.amount;
    }
    for (final cost in costs) {
      if (cost.ownerMoney) continue;
      final named = _contributorKey(cost.payerName) != null;
      final person = personOf(named ? cost.payerName : null, cost.payer);
      person['payer'] ??= cost.payer;
      person['paid'] = (person['paid'] as int) + cost.paid;
      final left = cost.total - cost.paid;
      if (left > 0) person['left'] = (person['left'] as int) + left;
      person['costsCount'] = (person['costsCount'] as int) + 1;
    }
    final list = people.values.toList()
      ..sort((a, b) {
        final byDone =
            ((b['gave'] as int) + (b['paid'] as int)) -
            ((a['gave'] as int) + (a['paid'] as int));
        if (byDone != 0) return byDone;
        return (a['name'] as String? ?? '').compareTo(
          b['name'] as String? ?? '',
        );
      });
    return [
      for (final person in list)
        {
          'name': person['name'],
          'payer': person['payer'],
          'gave': _money(person['gave'] as int),
          'promised': _money(person['promised'] as int),
          'paid': _money(person['paid'] as int),
          'left': _money(person['left'] as int),
          'costsCount': person['costsCount'],
        },
    ];
  }
}

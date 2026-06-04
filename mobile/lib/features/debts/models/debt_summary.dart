class DebtSummary {
  const DebtSummary({
    required this.totalDebt,
    required this.totalPaid,
    required this.remainingDebt,
    required this.countOpen,
    required this.countPartiallyPaid,
    required this.countPaid,
    required this.countCancelled,
  });

  factory DebtSummary.empty() {
    return const DebtSummary(
      totalDebt: '0',
      totalPaid: '0',
      remainingDebt: '0',
      countOpen: 0,
      countPartiallyPaid: 0,
      countPaid: 0,
      countCancelled: 0,
    );
  }

  factory DebtSummary.fromJson(Map<String, dynamic> json) {
    return DebtSummary(
      totalDebt: json['totalDebt']?.toString() ?? '0',
      totalPaid: json['totalPaid']?.toString() ?? '0',
      remainingDebt: json['remainingDebt']?.toString() ?? '0',
      countOpen: _intOrZero(json['countOpen']),
      countPartiallyPaid: _intOrZero(json['countPartiallyPaid']),
      countPaid: _intOrZero(json['countPaid']),
      countCancelled: _intOrZero(json['countCancelled']),
    );
  }

  final String totalDebt;
  final String totalPaid;
  final String remainingDebt;
  final int countOpen;
  final int countPartiallyPaid;
  final int countPaid;
  final int countCancelled;
}

int _intOrZero(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

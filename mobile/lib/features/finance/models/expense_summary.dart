class ExpenseSummary {
  const ExpenseSummary({
    required this.totalPaid,
    required this.totalPlanned,
    required this.totalCancelled,
    required this.countPaid,
    required this.countPlanned,
    required this.countCancelled,
  });

  factory ExpenseSummary.empty() {
    return const ExpenseSummary(
      totalPaid: '0',
      totalPlanned: '0',
      totalCancelled: '0',
      countPaid: 0,
      countPlanned: 0,
      countCancelled: 0,
    );
  }

  factory ExpenseSummary.fromJson(Map<String, dynamic> json) {
    return ExpenseSummary(
      totalPaid: json['totalPaid']?.toString() ?? '0',
      totalPlanned: json['totalPlanned']?.toString() ?? '0',
      totalCancelled: json['totalCancelled']?.toString() ?? '0',
      countPaid: _intOrZero(json['countPaid']),
      countPlanned: _intOrZero(json['countPlanned']),
      countCancelled: _intOrZero(json['countCancelled']),
    );
  }

  final String totalPaid;
  final String totalPlanned;
  final String totalCancelled;
  final int countPaid;
  final int countPlanned;
  final int countCancelled;
}

int _intOrZero(Object? value) {
  if (value is int) {
    return value;
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

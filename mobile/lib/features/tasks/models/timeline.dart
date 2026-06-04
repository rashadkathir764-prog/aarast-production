class Timeline {
  const Timeline({
    required this.upcomingTasks,
    required this.dueDebts,
    required this.dueInstallments,
    this.weddingDate,
  });

  factory Timeline.empty() {
    return const Timeline(upcomingTasks: [], dueDebts: [], dueInstallments: []);
  }

  factory Timeline.fromJson(Map<String, dynamic> json) {
    return Timeline(
      weddingDate: _dateTimeOrNull(json['weddingDate']),
      upcomingTasks: _listFromJson(
        json['upcomingTasks'],
        (item) => TimelineTask.fromJson(item),
      ),
      dueDebts: _listFromJson(
        json['dueDebts'],
        (item) => TimelineDebt.fromJson(item),
      ),
      dueInstallments: _listFromJson(
        json['dueInstallments'],
        (item) => TimelineInstallment.fromJson(item),
      ),
    );
  }

  final DateTime? weddingDate;
  final List<TimelineTask> upcomingTasks;
  final List<TimelineDebt> dueDebts;
  final List<TimelineInstallment> dueInstallments;
}

class TimelineTask {
  const TimelineTask({
    required this.id,
    required this.weddingPlanId,
    required this.title,
    required this.status,
    required this.priority,
    this.description,
    this.dueDate,
  });

  factory TimelineTask.fromJson(Map<String, dynamic> json) {
    return TimelineTask(
      id: json['id'].toString(),
      weddingPlanId: json['weddingPlanId'].toString(),
      title: json['title'].toString(),
      description: json['description']?.toString(),
      dueDate: _dateTimeOrNull(json['dueDate']),
      status: json['status']?.toString() ?? 'TODO',
      priority: json['priority']?.toString() ?? 'MEDIUM',
    );
  }

  final String id;
  final String weddingPlanId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String status;
  final String priority;
}

class TimelineDebt {
  const TimelineDebt({
    required this.id,
    required this.weddingPlanId,
    required this.creditorName,
    required this.title,
    required this.totalAmount,
    required this.paidAmount,
    required this.status,
    this.dueDate,
  });

  factory TimelineDebt.fromJson(Map<String, dynamic> json) {
    return TimelineDebt(
      id: json['id'].toString(),
      weddingPlanId: json['weddingPlanId'].toString(),
      creditorName: json['creditorName'].toString(),
      title: json['title'].toString(),
      totalAmount: json['totalAmount'].toString(),
      paidAmount: json['paidAmount'].toString(),
      dueDate: _dateTimeOrNull(json['dueDate']),
      status: json['status']?.toString() ?? 'OPEN',
    );
  }

  final String id;
  final String weddingPlanId;
  final String creditorName;
  final String title;
  final String totalAmount;
  final String paidAmount;
  final DateTime? dueDate;
  final String status;

  String get remainingAmount {
    final total = num.tryParse(totalAmount) ?? 0;
    final paid = num.tryParse(paidAmount) ?? 0;
    final remaining = total - paid;
    return remaining < 0 ? '0' : remaining.toStringAsFixed(2);
  }
}

class TimelineInstallment {
  const TimelineInstallment({
    required this.id,
    required this.debtId,
    required this.amount,
    required this.status,
    this.dueDate,
  });

  factory TimelineInstallment.fromJson(Map<String, dynamic> json) {
    return TimelineInstallment(
      id: json['id'].toString(),
      debtId: json['debtId'].toString(),
      amount: json['amount'].toString(),
      dueDate: _dateTimeOrNull(json['dueDate']),
      status: json['status']?.toString() ?? 'PENDING',
    );
  }

  final String id;
  final String debtId;
  final String amount;
  final DateTime? dueDate;
  final String status;
}

List<T> _listFromJson<T>(
  Object? value,
  T Function(Map<String, dynamic> item) mapper,
) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map>()
      .map((item) => mapper(Map<String, dynamic>.from(item)))
      .toList();
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

class Timeline {
  const Timeline({
    required this.upcomingTasks,
    required this.dueCommitments,
    required this.dueInstallments,
    this.weddingDate,
  });

  factory Timeline.empty() {
    return const Timeline(
      upcomingTasks: [],
      dueCommitments: [],
      dueInstallments: [],
    );
  }

  factory Timeline.fromJson(Map<String, dynamic> json) {
    return Timeline(
      weddingDate: _dateTimeOrNull(json['weddingDate']),
      upcomingTasks: _listFromJson(
        json['upcomingTasks'],
        (item) => TimelineTask.fromJson(item),
      ),
      dueCommitments: _listFromJson(
        json['dueCommitments'],
        (item) => TimelineCommitment.fromJson(item),
      ),
      dueInstallments: _listFromJson(
        json['dueInstallments'],
        (item) => TimelineInstallment.fromJson(item),
      ),
    );
  }

  final DateTime? weddingDate;
  final List<TimelineTask> upcomingTasks;
  final List<TimelineCommitment> dueCommitments;
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

class TimelineCommitment {
  const TimelineCommitment({
    required this.id,
    required this.weddingPlanId,
    this.partyName,
    required this.title,
    required this.totalAmount,
    required this.paidAmount,
    required this.status,
    this.dueDate,
  });

  factory TimelineCommitment.fromJson(Map<String, dynamic> json) {
    return TimelineCommitment(
      id: json['id'].toString(),
      weddingPlanId: json['weddingPlanId'].toString(),
      partyName: json['partyName']?.toString(),
      title: json['title'].toString(),
      totalAmount: json['totalAmount'].toString(),
      paidAmount: json['paidAmount'].toString(),
      dueDate: _dateTimeOrNull(json['dueDate']),
      status: json['status']?.toString() ?? 'OPEN',
    );
  }

  final String id;
  final String weddingPlanId;
  final String? partyName;
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
    required this.financialCommitmentId,
    required this.amount,
    required this.status,
    this.dueDate,
  });

  factory TimelineInstallment.fromJson(Map<String, dynamic> json) {
    return TimelineInstallment(
      id: json['id'].toString(),
      financialCommitmentId: json['financialCommitmentId'].toString(),
      amount: json['amount'].toString(),
      dueDate: _dateTimeOrNull(json['dueDate']),
      status: json['status']?.toString() ?? 'PENDING',
    );
  }

  final String id;
  final String financialCommitmentId;
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

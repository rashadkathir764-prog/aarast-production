import '../../../core/utils/plan_day.dart';

class Timeline {
  const Timeline({
    required this.upcomingTasks,
    required this.paymentSchedules,
    this.weddingDate,
  });

  factory Timeline.empty() {
    return const Timeline(upcomingTasks: [], paymentSchedules: []);
  }

  factory Timeline.fromJson(Map<String, dynamic> json) {
    return Timeline(
      weddingDate: planDayFromJson(json['weddingDate']),
      upcomingTasks: _listFromJson(
        json['upcomingTasks'],
        (item) => TimelineTask.fromJson(item),
      ),
      paymentSchedules: _listFromJson(
        json['paymentSchedules'],
        (item) => TimelinePaymentSchedule.fromJson(item),
      ),
    );
  }

  final DateTime? weddingDate;
  final List<TimelineTask> upcomingTasks;
  final List<TimelinePaymentSchedule> paymentSchedules;
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

class TimelinePaymentSchedule {
  const TimelinePaymentSchedule({
    required this.id,
    required this.weddingCostId,
    required this.costTitle,
    required this.amount,
    required this.dueDate,
    required this.status,
  });

  factory TimelinePaymentSchedule.fromJson(Map<String, dynamic> json) {
    return TimelinePaymentSchedule(
      id: json['id'].toString(),
      weddingCostId:
          json['weddingCostId']?.toString() ?? json['costId']?.toString() ?? '',
      costTitle: json['costTitle']?.toString() ?? '',
      amount: json['amount'].toString(),
      dueDate: DateTime.parse(json['dueDate'].toString()),
      status: json['status']?.toString() ?? 'PENDING',
    );
  }

  final String id;
  final String weddingCostId;
  final String costTitle;
  final String amount;
  final DateTime dueDate;
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

class WeddingTask {
  const WeddingTask({
    required this.id,
    required this.weddingPlanId,
    required this.title,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.dueDate,
    this.taskCategory,
  });

  factory WeddingTask.fromJson(Map<String, dynamic> json) {
    return WeddingTask(
      id: json['id'].toString(),
      weddingPlanId: json['weddingPlanId'].toString(),
      title: json['title'].toString(),
      description: json['description']?.toString(),
      dueDate: _dateTimeOrNull(json['dueDate']),
      taskCategory: json['taskCategory']?.toString(),
      status: json['status']?.toString() ?? 'TODO',
      priority: json['priority']?.toString() ?? 'MEDIUM',
      createdAt: _dateTimeOrNow(json['createdAt']),
      updatedAt: _dateTimeOrNow(json['updatedAt']),
    );
  }

  final String id;
  final String weddingPlanId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String? taskCategory;
  final String status;
  final String priority;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasDescription =>
      description != null && description!.trim().isNotEmpty;

  bool get isDone => status == 'DONE';

  WeddingTask copyWith({
    String? title,
    Object? description = _unchanged,
    Object? dueDate = _unchanged,
    Object? taskCategory = _unchanged,
    String? status,
    String? priority,
    DateTime? updatedAt,
  }) {
    return WeddingTask(
      id: id,
      weddingPlanId: weddingPlanId,
      title: title ?? this.title,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      description: identical(description, _unchanged)
          ? this.description
          : description as String?,
      dueDate: identical(dueDate, _unchanged)
          ? this.dueDate
          : dueDate as DateTime?,
      taskCategory: identical(taskCategory, _unchanged)
          ? this.taskCategory
          : taskCategory as String?,
    );
  }
}

const _unchanged = Object();

DateTime? _dateTimeOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

DateTime _dateTimeOrNow(Object? value) {
  return _dateTimeOrNull(value) ?? DateTime.now();
}

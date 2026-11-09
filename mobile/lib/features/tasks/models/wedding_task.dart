import '../../../core/phone/phone_number_utils.dart';
import 'task_checklist_item.dart';

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
    this.assigneeUserId,
    this.assigneeName,
    this.assigneePhone,
    this.assigneeRole,
    this.responsibleName,
    this.responsiblePhone,
    this.responsibleSource,
    this.checklist = const [],
    this.isPrivate = false,
    this.reminderAt,
    this.linkedBudgetCategoryId,
    this.linkedCostId,
    this.linkedScheduleId,
    this.autoClosedAt,
  });

  factory WeddingTask.fromJson(Map<String, dynamic> json) {
    final assignee = json['assignee'];
    final assigneeUser = assignee is Map ? assignee['user'] : null;
    return WeddingTask(
      id: json['id'].toString(),
      weddingPlanId: json['weddingPlanId'].toString(),
      title: json['title'].toString(),
      description: json['description']?.toString(),
      dueDate: _dateTimeOrNull(json['dueDate']),
      taskCategory: json['taskCategory']?.toString(),
      assigneeUserId: json['assigneeUserId']?.toString(),
      assigneeName:
          json['assigneeName']?.toString() ??
          json['assigneeDisplayName']?.toString() ??
          json['assigneeUserName']?.toString() ??
          (assignee is Map ? assignee['name']?.toString() : null),
      assigneePhone:
          json['assigneePhone']?.toString() ??
          json['assigneeUserPhone']?.toString() ??
          (assignee is Map ? assignee['phone']?.toString() : null) ??
          (assigneeUser is Map ? assigneeUser['phone']?.toString() : null),
      assigneeRole:
          json['assigneeRole']?.toString() ??
          (assignee is Map ? assignee['role']?.toString() : null),
      responsibleName:
          json['responsibleName']?.toString() ??
          json['responsibleDisplayName']?.toString(),
      responsiblePhone:
          json['responsiblePhone']?.toString() ??
          json['responsibleNormalizedPhone']?.toString(),
      responsibleSource: json['responsibleSource']?.toString(),
      status: json['status']?.toString() ?? 'TODO',
      priority: json['priority']?.toString() ?? 'MEDIUM',
      createdAt: _dateTimeOrNow(json['createdAt']),
      updatedAt: _dateTimeOrNow(json['updatedAt']),
      checklist: [
        for (final item in json['checklist'] as List? ?? const [])
          if (item is Map)
            TaskChecklistItem.fromJson(Map<String, dynamic>.from(item)),
      ],
      isPrivate: json['isPrivate'] == true,
      reminderAt: _dateTimeOrNull(json['reminderAt']),
      linkedBudgetCategoryId: json['linkedBudgetCategoryId']?.toString(),
      linkedCostId: json['linkedCostId']?.toString(),
      linkedScheduleId: json['linkedScheduleId']?.toString(),
      autoClosedAt: _dateTimeOrNull(json['autoClosedAt']),
    );
  }

  final String id;
  final String weddingPlanId;
  final String title;
  final String? description;
  final DateTime? dueDate;
  final String? taskCategory;
  final String? assigneeUserId;
  final String? assigneeName;
  final String? assigneePhone;
  final String? assigneeRole;
  final String? responsibleName;
  final String? responsiblePhone;
  final String? responsibleSource;
  final String status;
  final String priority;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The task's checklist steps, in the server's order.
  final List<TaskChecklistItem> checklist;

  /// V1 checklist 4.10: kept to its account; no one else in the plan sees it.
  final bool isPrivate;

  /// G36 «ذكّرني»: when the server reminds of this task, beside its due date.
  final DateTime? reminderAt;

  /// R4: the money item this task waits on: it ends when the item is booked.
  final String? linkedBudgetCategoryId;

  /// R4: the payment this task waits on, and the agreement that holds it.
  final String? linkedScheduleId;
  final String? linkedCostId;

  /// R4: when the booking or the payment finished it.
  final DateTime? autoClosedAt;

  bool get closedByLink => autoClosedAt != null;

  int get checklistDoneCount => checklist.where((item) => item.isDone).length;

  bool get hasDescription =>
      description != null && description!.trim().isNotEmpty;

  bool get isDone => status == 'DONE';

  /// Still to do: neither done nor cancelled (the server moves these with
  /// the wedding's date, and only these can be late).
  bool get isOpen => !isDone && status != 'CANCELLED';

  bool get hasResponsibleParticipant {
    final assigneeId = assigneeUserId?.trim();
    return assigneeId != null && assigneeId.isNotEmpty;
  }

  /// The task is the reader's own: assigned to their account, or with no one
  /// named. Choosing «أنا» saves the reader's name, so the label alone cannot
  /// tell.
  bool isMineFor(String? userId) {
    final assigneeId = assigneeUserId?.trim();
    if (assigneeId != null && assigneeId.isNotEmpty && assigneeId == userId) {
      return true;
    }
    return responsibleLabel == 'أنا';
  }

  String get responsibleLabel {
    final manualName = responsibleName?.trim();
    if (manualName != null && manualName.isNotEmpty) return manualName;
    final name = assigneeName?.trim();
    if (name != null && name.isNotEmpty) return name;
    if (hasResponsibleParticipant) return 'عضو مشارك';
    return 'أنا';
  }

  String get directionalResponsibleLabel {
    final label = responsibleLabel;
    final phone = responsiblePhone ?? assigneePhone;
    if (phone == null || !PhoneNumberUtils.areEquivalent(label, phone)) {
      return label;
    }
    return PhoneNumberUtils.directionalDisplay(phone) ?? label;
  }

  String? get responsiblePhoneDisplay {
    final phone = (responsiblePhone ?? assigneePhone)?.trim();
    if (phone == null || phone.isEmpty) return null;
    return PhoneNumberUtils.display(phone) ?? phone;
  }

  WeddingTask copyWith({
    String? title,
    Object? description = _unchanged,
    Object? dueDate = _unchanged,
    Object? taskCategory = _unchanged,
    Object? assigneeUserId = _unchanged,
    Object? assigneeName = _unchanged,
    Object? assigneePhone = _unchanged,
    Object? assigneeRole = _unchanged,
    Object? responsibleName = _unchanged,
    Object? responsiblePhone = _unchanged,
    Object? responsibleSource = _unchanged,
    String? status,
    String? priority,
    DateTime? updatedAt,
    List<TaskChecklistItem>? checklist,
    bool? isPrivate,
    Object? reminderAt = _unchanged,
  }) {
    return WeddingTask(
      reminderAt: identical(reminderAt, _unchanged)
          ? this.reminderAt
          : reminderAt as DateTime?,
      linkedBudgetCategoryId: linkedBudgetCategoryId,
      linkedCostId: linkedCostId,
      linkedScheduleId: linkedScheduleId,
      autoClosedAt: autoClosedAt,
      id: id,
      weddingPlanId: weddingPlanId,
      title: title ?? this.title,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      checklist: checklist ?? this.checklist,
      isPrivate: isPrivate ?? this.isPrivate,
      description: identical(description, _unchanged)
          ? this.description
          : description as String?,
      dueDate: identical(dueDate, _unchanged)
          ? this.dueDate
          : dueDate as DateTime?,
      taskCategory: identical(taskCategory, _unchanged)
          ? this.taskCategory
          : taskCategory as String?,
      assigneeUserId: identical(assigneeUserId, _unchanged)
          ? this.assigneeUserId
          : assigneeUserId as String?,
      assigneeName: identical(assigneeName, _unchanged)
          ? this.assigneeName
          : assigneeName as String?,
      assigneePhone: identical(assigneePhone, _unchanged)
          ? this.assigneePhone
          : assigneePhone as String?,
      assigneeRole: identical(assigneeRole, _unchanged)
          ? this.assigneeRole
          : assigneeRole as String?,
      responsibleName: identical(responsibleName, _unchanged)
          ? this.responsibleName
          : responsibleName as String?,
      responsiblePhone: identical(responsiblePhone, _unchanged)
          ? this.responsiblePhone
          : responsiblePhone as String?,
      responsibleSource: identical(responsibleSource, _unchanged)
          ? this.responsibleSource
          : responsibleSource as String?,
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

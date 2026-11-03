import 'package:flutter/widgets.dart' show StringCharacters;

import '../../../core/utils/plan_day.dart';
import '../../tasks/tasks_api.dart' show WeddingTask;

/// D52: the plan as every member reads it, whatever their role: the tasks,
/// the guests by name and reply, and the bookings. The server sends no
/// amount, phone, note or description here, so nothing of the kind can be
/// shown from it.
class PlanReadView {
  const PlanReadView({
    required this.weddingPlanId,
    required this.tasks,
    required this.tasksTotal,
    required this.tasksDone,
    required this.guests,
    required this.guestsTotal,
    required this.guestsConfirmed,
    required this.guestsPending,
    required this.guestsDeclined,
    required this.bookings,
  });

  factory PlanReadView.fromJson(Map<String, dynamic> json) {
    final weddingPlanId = json['weddingPlanId'].toString();
    final tasks = _map(json['tasks']);
    final guests = _map(json['guests']);
    final bookings = _map(json['bookings']);
    return PlanReadView(
      weddingPlanId: weddingPlanId,
      tasks: [
        for (final item in _list(tasks['items']))
          PlanReadTask.fromJson(item, weddingPlanId),
      ],
      tasksTotal: _int(tasks['total']),
      tasksDone: _int(tasks['done']),
      guests: [
        for (final item in _list(guests['items'])) PlanReadGuest.fromJson(item),
      ],
      guestsTotal: _int(guests['total']),
      guestsConfirmed: _int(guests['confirmed']),
      guestsPending: _int(guests['pending']),
      guestsDeclined: _int(guests['declined']),
      bookings: [
        for (final item in _list(bookings['items']))
          PlanReadBooking.fromJson(item),
      ],
    );
  }

  final String weddingPlanId;
  final List<PlanReadTask> tasks;
  final int tasksTotal;
  final int tasksDone;
  final List<PlanReadGuest> guests;
  final int guestsTotal;
  final int guestsConfirmed;
  final int guestsPending;
  final int guestsDeclined;
  final List<PlanReadBooking> bookings;
}

/// Who does a task, as a member reads it.
enum PlanReadAssignee { you, owner, member, person }

/// One task of the plan: what, where it stands, when, and who does it.
class PlanReadTask {
  const PlanReadTask({
    required this.id,
    required this.weddingPlanId,
    required this.title,
    required this.status,
    this.dueDate,
    this.assignee,
    this.assigneeFirstName,
  });

  factory PlanReadTask.fromJson(Map<String, dynamic> json, String planId) {
    final assignee = json['assignee'];
    final kind = assignee is Map ? assignee['kind']?.toString() : null;
    return PlanReadTask(
      id: json['id'].toString(),
      weddingPlanId: planId,
      title: json['title'].toString(),
      status: json['status']?.toString() ?? 'TODO',
      dueDate: DateTime.tryParse(json['dueDate']?.toString() ?? ''),
      assignee: switch (kind) {
        'YOU' => PlanReadAssignee.you,
        'OWNER' => PlanReadAssignee.owner,
        'MEMBER' => PlanReadAssignee.member,
        'PERSON' => PlanReadAssignee.person,
        _ => null,
      },
      assigneeFirstName: assignee is Map
          ? assignee['firstName']?.toString().trim().nonEmpty
          : null,
    );
  }

  final String id;
  final String weddingPlanId;
  final String title;
  final String status;
  final DateTime? dueDate;
  final PlanReadAssignee? assignee;
  final String? assigneeFirstName;

  bool get isDone => status == 'DONE';

  /// The same task as the task widgets read it; only what the read carries
  /// is filled. It has no timestamps, so it keeps the server's due order.
  WeddingTask toTask() => WeddingTask(
    id: id,
    weddingPlanId: weddingPlanId,
    title: title,
    status: status,
    priority: 'MEDIUM',
    createdAt: _noTimestamp,
    updatedAt: _noTimestamp,
    dueDate: dueDate,
    assigneeName: assignee == PlanReadAssignee.person
        ? null
        : assigneeFirstName,
    responsibleName: assignee == PlanReadAssignee.person
        ? assigneeFirstName
        : null,
  );

  /// «هذي المهمة عليك», «على صالح», «على العريس»: who does it, said to the
  /// reader. A task nobody was named for is the owner's (D52), so it reads
  /// «على محمد»; only a named kind without a name says nothing.
  String? whoLine({required String ownerWord}) => switch (assignee) {
    PlanReadAssignee.you => 'هذي المهمة عليك',
    PlanReadAssignee.owner => 'على ${assigneeFirstName ?? ownerWord}',
    PlanReadAssignee.member || PlanReadAssignee.person =>
      assigneeFirstName == null ? null : 'على $assigneeFirstName',
    null => 'على $ownerWord',
  };

  /// The letter of whoever does it (d01's small avatar), or null.
  String? letter({required String ownerWord}) {
    final name = switch (assignee) {
      PlanReadAssignee.you => 'أنا',
      PlanReadAssignee.owner => assigneeFirstName ?? ownerWord,
      _ => assigneeFirstName,
    };
    if (name == null || name.isEmpty) return null;
    final word = name.startsWith('ال') && name.length > 2
        ? name.substring(2)
        : name;
    return word.characters.first;
  }
}

/// One guest: the name and the reply. Never the phone.
class PlanReadGuest {
  const PlanReadGuest({
    required this.id,
    required this.name,
    required this.attendance,
  });

  factory PlanReadGuest.fromJson(Map<String, dynamic> json) => PlanReadGuest(
    id: json['id'].toString(),
    name: json['name']?.toString().trim() ?? '',
    attendance: json['attendanceStatus']?.toString() ?? 'PENDING',
  );

  final String id;
  final String name;

  /// `CONFIRMED`, `PENDING` or `DECLINED`.
  final String attendance;
}

/// One booking of the plan (q16): who, which service, which day, and
/// whether the provider confirmed. Never an amount.
class PlanReadBooking {
  const PlanReadBooking({
    required this.id,
    required this.businessName,
    required this.eventDate,
    required this.confirmed,
    this.categoryName,
    this.serviceTitle,
  });

  factory PlanReadBooking.fromJson(Map<String, dynamic> json) =>
      PlanReadBooking(
        id: json['id'].toString(),
        businessName: json['businessName']?.toString().trim() ?? '',
        categoryName: json['categoryName']?.toString().trim().nonEmpty,
        serviceTitle: json['serviceTitle']?.toString().trim().nonEmpty,
        // The day in Sana'a, as the plan's wedding date is read (D11).
        eventDate: planDayFromJson(json['eventDate']),
        confirmed: json['status'] == 'CONFIRMED',
      );

  final String id;
  final String businessName;
  final String? categoryName;
  final String? serviceTitle;
  final DateTime? eventDate;
  final bool confirmed;
}

final _noTimestamp = DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);

extension on String {
  String? get nonEmpty => isEmpty ? null : this;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : const {};

List<Map<String, dynamic>> _list(Object? value) => [
  if (value is List)
    for (final item in value)
      if (item is Map) Map<String, dynamic>.from(item),
];

int _int(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;

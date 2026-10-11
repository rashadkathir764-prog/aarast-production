/// One step of a task's checklist, as `GET /api/v1/tasks/:id` returns it.
class TaskChecklistItem {
  const TaskChecklistItem({
    required this.id,
    required this.taskId,
    required this.title,
    required this.isDone,
    required this.sortOrder,
  });

  factory TaskChecklistItem.fromJson(Map<String, dynamic> json) {
    return TaskChecklistItem(
      id: json['id'].toString(),
      taskId: json['taskId'].toString(),
      title: json['title'].toString(),
      isDone: json['isDone'] == true,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String taskId;
  final String title;
  final bool isDone;
  final int sortOrder;

  Map<String, dynamic> toJson() => {
    'id': id,
    'taskId': taskId,
    'title': title,
    'isDone': isDone,
    'sortOrder': sortOrder,
  };
}

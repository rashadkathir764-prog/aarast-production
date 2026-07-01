class AarastNotification {
  const AarastNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
    this.weddingPlanId,
    this.data,
    this.readAt,
    this.priority = 'NORMAL',
    this.entityType,
    this.entityId,
    this.routeTarget,
    this.archivedAt,
  });

  factory AarastNotification.fromJson(Map<String, dynamic> json) {
    return AarastNotification(
      id: json['id'].toString(),
      userId: json['userId'].toString(),
      weddingPlanId: json['weddingPlanId']?.toString(),
      type: json['type'].toString(),
      title: json['title'].toString(),
      body: json['body'].toString(),
      priority: json['priority']?.toString() ?? 'NORMAL',
      entityType: json['entityType']?.toString(),
      entityId: json['entityId']?.toString(),
      routeTarget: json['routeTarget']?.toString(),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
      readAt: _dateTimeOrNull(json['readAt']),
      archivedAt: _dateTimeOrNull(json['archivedAt']),
      createdAt: _dateTimeOrNull(json['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeOrNull(json['updatedAt']) ?? DateTime.now(),
    );
  }

  final String id;
  final String userId;
  final String? weddingPlanId;
  final String type;
  final String title;
  final String body;
  final String priority;
  final String? entityType;
  final String? entityId;
  final String? routeTarget;
  final Map<String, dynamic>? data;
  final DateTime? readAt;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isUnread => readAt == null;

  AarastNotification copyWith({
    DateTime? readAt,
    bool clearReadAt = false,
    DateTime? archivedAt,
  }) {
    return AarastNotification(
      id: id,
      userId: userId,
      weddingPlanId: weddingPlanId,
      type: type,
      title: title,
      body: body,
      priority: priority,
      entityType: entityType,
      entityId: entityId,
      routeTarget: routeTarget,
      data: data,
      readAt: clearReadAt ? null : readAt ?? this.readAt,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _dateTimeOrNull(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

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
  });

  factory AarastNotification.fromJson(Map<String, dynamic> json) {
    return AarastNotification(
      id: json['id'].toString(),
      userId: json['userId'].toString(),
      weddingPlanId: json['weddingPlanId']?.toString(),
      type: json['type'].toString(),
      title: json['title'].toString(),
      body: json['body'].toString(),
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
      readAt: _dateTimeOrNull(json['readAt']),
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
  final Map<String, dynamic>? data;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isUnread => readAt == null;

  AarastNotification copyWith({DateTime? readAt, bool clearReadAt = false}) {
    return AarastNotification(
      id: id,
      userId: userId,
      weddingPlanId: weddingPlanId,
      type: type,
      title: title,
      body: body,
      data: data,
      readAt: clearReadAt ? null : readAt ?? this.readAt,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  static DateTime? _dateTimeOrNull(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

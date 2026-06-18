class Guest {
  const Guest({
    required this.id,
    required this.weddingPlanId,
    required this.name,
    required this.side,
    required this.status,
    required this.seatsCount,
    required this.createdAt,
    required this.updatedAt,
    this.phone,
    this.notes,
  });

  factory Guest.fromJson(Map<String, dynamic> json) {
    return Guest(
      id: json['id'].toString(),
      weddingPlanId: json['weddingPlanId'].toString(),
      name: json['name'].toString(),
      phone: json['phone']?.toString(),
      side: json['side']?.toString() ?? 'OTHER',
      status: json['status']?.toString() ?? 'INVITED',
      seatsCount: int.tryParse(json['seatsCount']?.toString() ?? '') ?? 1,
      notes: json['notes']?.toString(),
      createdAt: _dateTimeOrNull(json['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeOrNull(json['updatedAt']) ?? DateTime.now(),
    );
  }

  final String id;
  final String weddingPlanId;
  final String name;
  final String? phone;
  final String side;
  final String status;
  final int seatsCount;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  static DateTime? _dateTimeOrNull(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

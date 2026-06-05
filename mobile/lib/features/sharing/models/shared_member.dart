class SharedMember {
  const SharedMember({
    required this.id,
    required this.weddingPlanId,
    required this.userId,
    this.user,
    required this.role,
    required this.canViewBudget,
    required this.canViewExpenses,
    required this.canViewDebts,
    required this.canManageTasks,
    required this.canManageFinancialRecords,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SharedMember.fromJson(Map<String, dynamic> json) {
    return SharedMember(
      id: json['id'].toString(),
      weddingPlanId: json['weddingPlanId'].toString(),
      userId: json['userId'].toString(),
      user: _sharedMemberUserOrNull(json),
      role: json['role']?.toString() ?? 'VIEWER',
      canViewBudget: json['canViewBudget'] == true,
      canViewExpenses: json['canViewExpenses'] == true,
      canViewDebts: json['canViewDebts'] == true,
      canManageTasks: json['canManageTasks'] == true,
      canManageFinancialRecords: json['canManageFinancialRecords'] == true,
      createdAt: _dateTimeOrNow(json['createdAt']),
      updatedAt: _dateTimeOrNow(json['updatedAt']),
    );
  }

  final String id;
  final String weddingPlanId;
  final String userId;
  final SharedMemberUser? user;
  final String role;
  final bool canViewBudget;
  final bool canViewExpenses;
  final bool canViewDebts;
  final bool canManageTasks;
  final bool canManageFinancialRecords;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasFinancialAccess =>
      canViewBudget ||
      canViewExpenses ||
      canViewDebts ||
      canManageFinancialRecords;

  String get displayName {
    final name = user?.name.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    final phone = user?.phone?.trim();
    if (phone != null && phone.isNotEmpty) {
      return phone;
    }

    return userId;
  }

  String? get displaySubtitle {
    final phone = user?.phone?.trim();
    if (phone != null && phone.isNotEmpty && phone != displayName) {
      return phone;
    }
    return user == null ? 'معرف داخلي: $userId' : null;
  }

  List<String> get permissionLabels {
    final labels = <String>[];
    if (canViewBudget) labels.add('يمكنه رؤية الميزانية');
    if (canViewExpenses) labels.add('يمكنه رؤية المصاريف');
    if (canViewDebts) labels.add('يمكنه رؤية الديون والأقساط');
    if (canManageTasks) labels.add('يمكنه إدارة المهام');
    if (canManageFinancialRecords) labels.add('يمكنه إدارة السجلات المالية');
    return labels;
  }
}

class SharedMemberUser {
  const SharedMemberUser({
    required this.id,
    required this.name,
    required this.phone,
  });

  factory SharedMemberUser.fromJson(Map<String, dynamic> json) {
    return SharedMemberUser(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
    );
  }

  final String id;
  final String name;
  final String? phone;
}

SharedMemberUser? _sharedMemberUserOrNull(Map<String, dynamic> json) {
  final userValue = json['user'];
  if (userValue is Map) {
    return SharedMemberUser.fromJson(Map<String, dynamic>.from(userValue));
  }

  final name = json['userName'] ?? json['memberName'];
  final phone = json['userPhone'] ?? json['memberPhone'];
  if (name != null || phone != null) {
    return SharedMemberUser(
      id: json['userId']?.toString() ?? '',
      name: name?.toString() ?? '',
      phone: phone?.toString(),
    );
  }

  return null;
}

DateTime? _dateTimeOrNull(Object? value) {
  if (value == null) {
    return null;
  }
  return DateTime.tryParse(value.toString());
}

DateTime _dateTimeOrNow(Object? value) {
  return _dateTimeOrNull(value) ?? DateTime.now();
}

String sharedMemberRoleLabel(String role) {
  return switch (role) {
    'MANAGER' => 'مدير',
    'CONTRIBUTOR' => 'مساهم',
    'VIEWER' => 'مشاهد',
    _ => role,
  };
}

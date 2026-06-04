class SharedMember {
  const SharedMember({
    required this.id,
    required this.weddingPlanId,
    required this.userId,
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

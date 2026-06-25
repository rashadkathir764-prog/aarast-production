import '../../../core/phone/phone_number_utils.dart';

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
    this.canEditPlan = false,
    required this.canManageTasks,
    this.canManageGuests = false,
    this.canManageProviders = false,
    this.canInviteMembers = false,
    required this.canManageFinancialRecords,
    this.receiveNotifications = true,
    this.isOwner = false,
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
      canEditPlan: json['canEditPlan'] == true,
      canManageTasks: json['canManageTasks'] == true,
      canManageGuests: json['canManageGuests'] == true,
      canManageProviders: json['canManageProviders'] == true,
      canInviteMembers: json['canInviteMembers'] == true,
      canManageFinancialRecords: json['canManageFinancialRecords'] == true,
      receiveNotifications: json['receiveNotifications'] != false,
      isOwner: json['isOwner'] == true || json['role'] == 'OWNER',
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
  final bool canEditPlan;
  final bool canManageTasks;
  final bool canManageGuests;
  final bool canManageProviders;
  final bool canInviteMembers;
  final bool canManageFinancialRecords;
  final bool receiveNotifications;
  final bool isOwner;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasFinancialAccess =>
      canViewBudget ||
      canViewExpenses ||
      canViewDebts ||
      canManageFinancialRecords;

  bool get canReadBudget => canViewBudget || canManageFinancialRecords;

  bool get canReadExpenses => canViewExpenses || canManageFinancialRecords;

  bool get canReadDebts => canViewDebts || canManageFinancialRecords;

  String get displayName {
    final name = user?.name.trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    final phone = user?.phone?.trim();
    if (phone != null && phone.isNotEmpty) {
      return PhoneNumberUtils.display(phone) ?? phone;
    }

    return userId;
  }

  String? get displaySubtitle {
    final phone = user?.phone?.trim();
    if (phone != null && phone.isNotEmpty && phone != displayName) {
      return PhoneNumberUtils.display(phone) ?? phone;
    }
    return user == null ? 'معرف داخلي: $userId' : null;
  }

  List<String> get permissionLabels {
    final labels = <String>[];
    if (canViewBudget) labels.add('يمكنه رؤية الميزانية');
    if (canViewExpenses) labels.add('يمكنه رؤية المصاريف');
    if (canViewDebts) labels.add('يمكنه رؤية الديون والأقساط');
    if (canManageTasks) labels.add('يمكنه إدارة المهام');
    if (canManageGuests) labels.add('يمكنه إدارة الضيوف');
    if (canManageProviders) labels.add('يمكنه إدارة الموردين والعروض');
    if (canEditPlan) labels.add('يمكنه تعديل الخطة');
    if (canInviteMembers) labels.add('يمكنه دعوة المشاركين');
    if (canManageFinancialRecords) labels.add('يمكنه إدارة السجلات المالية');
    return labels;
  }
}

class SharedMemberUser {
  const SharedMemberUser({
    required this.id,
    required this.name,
    required this.phone,
    this.avatarUrl,
  });

  factory SharedMemberUser.fromJson(Map<String, dynamic> json) {
    return SharedMemberUser(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }

  final String id;
  final String name;
  final String? phone;
  final String? avatarUrl;
}

class SharedUserLookup {
  const SharedUserLookup({
    required this.id,
    required this.name,
    this.phone,
    this.avatarUrl,
  });

  factory SharedUserLookup.fromJson(Map<String, dynamic> json) {
    return SharedUserLookup(
      id: json['id'].toString(),
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
    );
  }

  final String id;
  final String name;
  final String? phone;
  final String? avatarUrl;
}

class PlanInvite {
  const PlanInvite({
    required this.id,
    required this.weddingPlanId,
    required this.token,
    required this.role,
    required this.status,
    required this.expiresAt,
    this.name,
    this.phone,
    this.email,
    this.weddingPlanTitle,
  });

  factory PlanInvite.fromJson(Map<String, dynamic> json) {
    final plan = json['weddingPlan'];
    return PlanInvite(
      id: json['id'].toString(),
      weddingPlanId: json['weddingPlanId'].toString(),
      token: json['token']?.toString() ?? '',
      role: json['role']?.toString() ?? 'VIEWER',
      status: json['status']?.toString() ?? 'PENDING',
      expiresAt:
          _dateTimeOrNull(json['expiresAt']) ??
          DateTime.now().add(const Duration(days: 14)),
      name: json['name']?.toString(),
      phone:
          json['normalizedPhone']?.toString() ?? json['phone']?.toString(),
      email: json['email']?.toString(),
      weddingPlanTitle: plan is Map ? plan['title']?.toString() : null,
    );
  }

  final String id;
  final String weddingPlanId;
  final String token;
  final String role;
  final String status;
  final DateTime expiresAt;
  final String? name;
  final String? phone;
  final String? email;
  final String? weddingPlanTitle;

  bool get isPending => status == 'PENDING';

  String get displayName {
    final value = name?.trim();
    if (value != null && value.isNotEmpty) return value;
    final normalizedPhone = phone?.trim();
    if (normalizedPhone != null && normalizedPhone.isNotEmpty) {
      return PhoneNumberUtils.display(normalizedPhone) ?? normalizedPhone;
    }
    return email?.trim().isNotEmpty == true ? email!.trim() : 'دعوة مشاركة';
  }
}

SharedMemberUser? _sharedMemberUserOrNull(Map<String, dynamic> json) {
  final userValue = json['user'];
  if (userValue is Map) {
    return SharedMemberUser.fromJson(Map<String, dynamic>.from(userValue));
  }

  final name = json['userName'] ?? json['memberName'];
  final phone = json['userPhone'] ?? json['memberPhone'];
  final avatarUrl = json['userAvatarUrl'] ?? json['memberAvatarUrl'];
  if (name != null || phone != null) {
    return SharedMemberUser(
      id: json['userId']?.toString() ?? '',
      name: name?.toString() ?? '',
      phone: phone?.toString(),
      avatarUrl: avatarUrl?.toString(),
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
    'OWNER' => 'صاحب الخطة',
    'GROOM' => 'العريس',
    'BRIDE' => 'العروس',
    'FAMILY' => 'العائلة',
    'HELPER' => 'مساعد',
    'MANAGER' => 'مدير',
    'CONTRIBUTOR' => 'مساهم',
    'VIEWER' => 'مشاهد',
    _ => role,
  };
}

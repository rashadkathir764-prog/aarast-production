import '../../../core/phone/phone_number_utils.dart';
import 'plan_role_permissions.dart';

class SharedMember {
  const SharedMember({
    required this.id,
    required this.weddingPlanId,
    required this.userId,
    this.user,
    required this.role,
    required this.canViewMoney,
    this.canEditPlan = false,
    required this.canManageTasks,
    this.canManageGuests = false,
    this.canManageProviders = false,
    this.canInviteMembers = false,
    required this.canManageMoney,
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
      canViewMoney:
          json['canViewMoney'] == true || json['canManageMoney'] == true,
      canEditPlan: json['canEditPlan'] == true,
      canManageTasks: json['canManageTasks'] == true,
      canManageGuests: json['canManageGuests'] == true,
      canManageProviders: json['canManageProviders'] == true,
      canInviteMembers: json['canInviteMembers'] == true,
      canManageMoney: json['canManageMoney'] == true,
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
  final bool canViewMoney;
  final bool canEditPlan;
  final bool canManageTasks;
  final bool canManageGuests;
  final bool canManageProviders;
  final bool canInviteMembers;
  final bool canManageMoney;
  final bool receiveNotifications;
  final bool isOwner;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get hasFinancialAccess => canViewMoney;

  String? get displayNamePhone {
    final name = user?.name.trim();
    if (name != null && name.isNotEmpty) return null;

    final phone = user?.phone?.trim();
    return phone == null || phone.isEmpty ? null : phone;
  }

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

  String get directionalDisplayName {
    final phone = displayNamePhone;
    return phone == null
        ? displayName
        : PhoneNumberUtils.directionalDisplay(phone) ?? displayName;
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
    if (canViewMoney) labels.add('يمكنه مشاهدة المال');
    if (canManageTasks) labels.add('يمكنه إدارة المهام');
    if (canManageGuests) labels.add('يمكنه إدارة الضيوف');
    if (canManageProviders) labels.add('يمكنه إدارة الموردين والعروض');
    if (canEditPlan) labels.add('يمكنه تعديل الخطة');
    if (canInviteMembers) labels.add('يمكنه دعوة المشاركين');
    if (canManageMoney) labels.add('يمكنه إدارة المال');
    return labels;
  }

  /// لقطة الصلاحيات الحالية كقيمة قابلة للتعديل في محرر الصلاحيات.
  PlanRolePermissions toPermissions() {
    return PlanRolePermissions(
      canViewMoney: canViewMoney,
      canEditPlan: canEditPlan,
      canManageTasks: canManageTasks,
      canManageGuests: canManageGuests,
      canManageProviders: canManageProviders,
      canInviteMembers: canInviteMembers,
      canManageMoney: canManageMoney,
      receiveNotifications: receiveNotifications,
    );
  }

  /// سطر واحد يلخص ما يستطيعه العضو — لصف العضو المدمج.
  String get permissionSummary =>
      isOwner ? 'كل الصلاحيات' : toPermissions().summaryLabel;
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
    this.contextKey,
    required this.role,
    required this.status,
    required this.expiresAt,
    required this.canViewMoney,
    required this.canEditPlan,
    required this.canManageTasks,
    required this.canManageGuests,
    required this.canManageProviders,
    required this.canInviteMembers,
    required this.canManageMoney,
    this.deliveryStatus = 'UNKNOWN',
    this.deliveryAttemptedAt,
    this.deliveryRetryAvailableAt,
    this.name,
    this.phone,
    this.email,
    this.weddingPlanTitle,
    this.inviterName,
  });

  factory PlanInvite.fromJson(Map<String, dynamic> json) {
    final plan = json['weddingPlan'];
    final inviter = json['inviter'];
    final delivery = json['delivery'];
    final retryAfterSeconds = delivery is Map
        ? int.tryParse(delivery['retryAfterSeconds']?.toString() ?? '') ?? 0
        : 0;
    return PlanInvite(
      id: json['id'].toString(),
      weddingPlanId: json['weddingPlanId'].toString(),
      token: json['token']?.toString() ?? '',
      contextKey: _canonicalContributorContextKeyOrNull(
        json['contextKey'],
        json['weddingPlanId'].toString(),
      ),
      role: json['role']?.toString() ?? 'VIEWER',
      status: json['status']?.toString() ?? 'PENDING',
      canViewMoney:
          json['canViewMoney'] == true || json['canManageMoney'] == true,
      canEditPlan: json['canEditPlan'] == true,
      canManageTasks: json['canManageTasks'] == true,
      canManageGuests: json['canManageGuests'] == true,
      canManageProviders: json['canManageProviders'] == true,
      canInviteMembers: json['canInviteMembers'] == true,
      canManageMoney: json['canManageMoney'] == true,
      expiresAt:
          _dateTimeOrNull(json['expiresAt']) ??
          DateTime.now().add(const Duration(days: 14)),
      name: json['name']?.toString(),
      phone: json['normalizedPhone']?.toString() ?? json['phone']?.toString(),
      email: json['email']?.toString(),
      weddingPlanTitle: plan is Map ? plan['title']?.toString() : null,
      inviterName: inviter is Map ? inviter['name']?.toString() : null,
      deliveryStatus: delivery is Map
          ? delivery['status']?.toString() ?? 'UNKNOWN'
          : 'UNKNOWN',
      deliveryAttemptedAt: delivery is Map
          ? _dateTimeOrNull(delivery['attemptedAt'])
          : null,
      deliveryRetryAvailableAt: retryAfterSeconds > 0
          ? DateTime.now().add(Duration(seconds: retryAfterSeconds))
          : null,
    );
  }

  final String id;
  final String weddingPlanId;
  final String token;
  final String? contextKey;
  final String role;
  final String status;
  final DateTime expiresAt;
  final bool canViewMoney;
  final bool canEditPlan;
  final bool canManageTasks;
  final bool canManageGuests;
  final bool canManageProviders;
  final bool canInviteMembers;
  final bool canManageMoney;
  final String deliveryStatus;
  final DateTime? deliveryAttemptedAt;
  final DateTime? deliveryRetryAvailableAt;
  final String? name;
  final String? phone;
  final String? email;
  final String? weddingPlanTitle;
  final String? inviterName;

  bool get isPending => status == 'PENDING';
  bool get isAccepted => status == 'ACCEPTED';
  bool get isDeclined => status == 'DECLINED';
  bool get hasActiveMembership => isAccepted && contextKey != null;
  bool get hasEndedMembership => isAccepted && contextKey == null;
  bool get wasDeliveredByAarast => deliveryStatus == 'DELIVERED';
  bool get hasUncertainDelivery => deliveryStatus == 'UNCERTAIN';
  bool get hasPendingDelivery => deliveryStatus == 'PENDING';
  bool get hasUnknownDelivery => deliveryStatus == 'UNKNOWN';

  String? get deliverySummaryLabel => switch (deliveryStatus) {
    'DELIVERED' => 'تم تسليم الرابط',
    'UNCERTAIN' => 'الوصول غير مؤكد',
    'UNAVAILABLE' => 'تعذر الإرسال',
    'PENDING' => 'جارٍ تثبيت التسليم',
    'UNKNOWN' => 'حالة الإرسال غير معروفة',
    _ => null,
  };

  Duration get deliveryRetryRemaining {
    final availableAt = deliveryRetryAvailableAt;
    if (availableAt == null) return Duration.zero;
    final remaining = availableAt.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  int get deliveryRetryRemainingSeconds {
    final milliseconds = deliveryRetryRemaining.inMilliseconds;
    return milliseconds == 0 ? 0 : (milliseconds / 1000).ceil();
  }

  bool get canRetryDelivery => deliveryRetryRemainingSeconds == 0;

  /// Returns a copy suitable for provider/list state after a one-time raw
  /// bearer token has been handed to the share screen.
  PlanInvite withIdentityToken() {
    return PlanInvite(
      id: id,
      weddingPlanId: weddingPlanId,
      token: id,
      contextKey: contextKey,
      role: role,
      status: status,
      expiresAt: expiresAt,
      canViewMoney: canViewMoney,
      canEditPlan: canEditPlan,
      canManageTasks: canManageTasks,
      canManageGuests: canManageGuests,
      canManageProviders: canManageProviders,
      canInviteMembers: canInviteMembers,
      canManageMoney: canManageMoney,
      deliveryStatus: deliveryStatus,
      deliveryAttemptedAt: deliveryAttemptedAt,
      deliveryRetryAvailableAt: deliveryRetryAvailableAt,
      name: name,
      phone: phone,
      email: email,
      weddingPlanTitle: weddingPlanTitle,
      inviterName: inviterName,
    );
  }

  PlanInvite withContextKey(String value) {
    final canonicalContextKey = _canonicalContributorContextKeyOrNull(
      value,
      weddingPlanId,
    );
    return PlanInvite(
      id: id,
      weddingPlanId: weddingPlanId,
      token: token,
      contextKey: canonicalContextKey,
      role: role,
      status: status,
      expiresAt: expiresAt,
      canViewMoney: canViewMoney,
      canEditPlan: canEditPlan,
      canManageTasks: canManageTasks,
      canManageGuests: canManageGuests,
      canManageProviders: canManageProviders,
      canInviteMembers: canInviteMembers,
      canManageMoney: canManageMoney,
      deliveryStatus: deliveryStatus,
      deliveryAttemptedAt: deliveryAttemptedAt,
      deliveryRetryAvailableAt: deliveryRetryAvailableAt,
      name: name,
      phone: phone,
      email: email,
      weddingPlanTitle: weddingPlanTitle,
      inviterName: inviterName,
    );
  }

  PlanInvite withDeliveryRetryAvailableAt(DateTime availableAt) {
    return PlanInvite(
      id: id,
      weddingPlanId: weddingPlanId,
      token: token,
      contextKey: contextKey,
      role: role,
      status: status,
      expiresAt: expiresAt,
      canViewMoney: canViewMoney,
      canEditPlan: canEditPlan,
      canManageTasks: canManageTasks,
      canManageGuests: canManageGuests,
      canManageProviders: canManageProviders,
      canInviteMembers: canInviteMembers,
      canManageMoney: canManageMoney,
      deliveryStatus: deliveryStatus,
      deliveryAttemptedAt: deliveryAttemptedAt,
      deliveryRetryAvailableAt: availableAt,
      name: name,
      phone: phone,
      email: email,
      weddingPlanTitle: weddingPlanTitle,
      inviterName: inviterName,
    );
  }

  String? get displayNamePhone {
    final value = name?.trim();
    if (value != null && value.isNotEmpty) return null;

    final normalizedPhone = phone?.trim();
    return normalizedPhone == null || normalizedPhone.isEmpty
        ? null
        : normalizedPhone;
  }

  List<String> get permissionLabels {
    final labels = <String>['عرض الخطة'];
    if (canManageTasks) labels.add('المهام');
    if (canManageGuests) labels.add('الضيوف');
    if (canManageProviders) labels.add('الخدمات والموردون');
    if (canInviteMembers) labels.add('دعوة أعضاء');
    if (canManageMoney) {
      labels.add('إدارة المال');
    } else if (canViewMoney) {
      labels.add('مشاهدة المال');
    }
    return labels;
  }

  String get displayName {
    final value = name?.trim();
    if (value != null && value.isNotEmpty) return value;
    final normalizedPhone = phone?.trim();
    if (normalizedPhone != null && normalizedPhone.isNotEmpty) {
      return PhoneNumberUtils.display(normalizedPhone) ?? normalizedPhone;
    }
    return email?.trim().isNotEmpty == true ? email!.trim() : 'دعوة مشاركة';
  }

  String get directionalDisplayName {
    final normalizedPhone = displayNamePhone;
    return normalizedPhone == null
        ? displayName
        : PhoneNumberUtils.directionalDisplay(normalizedPhone) ?? displayName;
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

String? _canonicalContributorContextKeyOrNull(
  Object? rawValue,
  String weddingPlanId,
) {
  if (rawValue == null) return null;
  if (rawValue is! String ||
      rawValue.isEmpty ||
      rawValue.trim() != rawValue ||
      rawValue != 'plan:$weddingPlanId:contributor') {
    throw const FormatException(
      'Invite contextKey must be the canonical contributor context',
    );
  }
  return rawValue;
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

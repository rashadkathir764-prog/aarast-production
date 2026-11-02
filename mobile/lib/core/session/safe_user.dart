class SafeUser {
  const SafeUser({
    required this.id,
    required this.name,
    required this.role,
    required this.status,
    this.appRole = 'WEDDING_USER',
    this.phone,
    this.email,
    this.avatarUrl,
    this.locale = 'ar',
    this.activeWeddingPlanId,
    this.onboardingPath,
    this.persona,
    this.hasPassword = false,
    this.phoneVerifiedAt,
    this.lastLoginAt,
    this.onboardingCompletedAt,
    this.deletionRequestedAt,
    this.deletionScheduledFor,
  });

  factory SafeUser.fromJson(Map<String, dynamic> json) {
    final deletion = json['deletion'];
    return SafeUser(
      deletionRequestedAt: deletion is Map
          ? _dateTimeOrNull(deletion['requestedAt'])
          : null,
      deletionScheduledFor: deletion is Map
          ? _dateTimeOrNull(deletion['scheduledFor'])
          : null,
      id: json['id'].toString(),
      name: json['name'].toString(),
      phone: json['phone']?.toString(),
      email: json['email']?.toString(),
      avatarUrl: json['avatarUrl']?.toString(),
      role: json['role'].toString(),
      appRole: json['appRole']?.toString() ?? 'WEDDING_USER',
      status: json['status'].toString(),
      locale: json['locale']?.toString() ?? 'ar',
      activeWeddingPlanId: json['activeWeddingPlanId']?.toString(),
      onboardingPath: json['onboardingPath']?.toString(),
      persona: json['persona']?.toString(),
      hasPassword: json['hasPassword'] == true,
      phoneVerifiedAt: _dateTimeOrNull(json['phoneVerifiedAt']),
      lastLoginAt: _dateTimeOrNull(json['lastLoginAt']),
      onboardingCompletedAt: _dateTimeOrNull(json['onboardingCompletedAt']),
    );
  }

  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? avatarUrl;
  final String role;
  final String appRole;
  final String status;
  final String locale;
  final String? activeWeddingPlanId;
  final String? onboardingPath;
  final String? persona;

  /// D75: the account signs in by number and code; a password is an extra
  /// way in, added from «حسابي».
  final bool hasPassword;
  final DateTime? phoneVerifiedAt;
  final DateTime? lastLoginAt;
  final DateTime? onboardingCompletedAt;

  /// D63 (w06): the account asked to be deleted and waits out its 30 days.
  final DateTime? deletionRequestedAt;
  final DateTime? deletionScheduledFor;

  bool get deletionPending =>
      deletionRequestedAt != null && deletionScheduledFor != null;

  /// The same account with its deletion request set, or taken back (null).
  SafeUser withDeletion({DateTime? requestedAt, DateTime? scheduledFor}) {
    return SafeUser(
      id: id,
      name: name,
      role: role,
      status: status,
      appRole: appRole,
      phone: phone,
      email: email,
      avatarUrl: avatarUrl,
      locale: locale,
      activeWeddingPlanId: activeWeddingPlanId,
      onboardingPath: onboardingPath,
      persona: persona,
      phoneVerifiedAt: phoneVerifiedAt,
      lastLoginAt: lastLoginAt,
      onboardingCompletedAt: onboardingCompletedAt,
      deletionRequestedAt: requestedAt,
      deletionScheduledFor: scheduledFor,
    );
  }

  bool get isProviderAccount {
    return _upper(role) == 'PROVIDER' ||
        _upper(appRole) == 'PROVIDER' ||
        _upper(onboardingPath) == 'PROVIDER';
  }

  bool get isWeddingUserAccount => !isProviderAccount;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'email': email,
      'avatarUrl': avatarUrl,
      'role': role,
      'appRole': appRole,
      'status': status,
      'locale': locale,
      'activeWeddingPlanId': activeWeddingPlanId,
      'onboardingPath': onboardingPath,
      'persona': persona,
      'hasPassword': hasPassword,
      'phoneVerifiedAt': phoneVerifiedAt?.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'onboardingCompletedAt': onboardingCompletedAt?.toIso8601String(),
      'deletion': deletionPending
          ? {
              'requestedAt': deletionRequestedAt!.toIso8601String(),
              'scheduledFor': deletionScheduledFor!.toIso8601String(),
            }
          : null,
    };
  }

  static String _upper(String? value) => value?.trim().toUpperCase() ?? '';

  static DateTime? _dateTimeOrNull(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

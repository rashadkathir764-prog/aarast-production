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
    this.phoneVerifiedAt,
    this.lastLoginAt,
    this.onboardingCompletedAt,
  });

  factory SafeUser.fromJson(Map<String, dynamic> json) {
    return SafeUser(
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
  final DateTime? phoneVerifiedAt;
  final DateTime? lastLoginAt;
  final DateTime? onboardingCompletedAt;

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
      'phoneVerifiedAt': phoneVerifiedAt?.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'onboardingCompletedAt': onboardingCompletedAt?.toIso8601String(),
    };
  }

  static String _upper(String? value) => value?.trim().toUpperCase() ?? '';

  static DateTime? _dateTimeOrNull(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

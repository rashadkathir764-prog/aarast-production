class UserSettings {
  const UserSettings({
    required this.id,
    required this.userId,
    required this.pushEnabled,
    required this.smsEnabled,
    required this.whatsappEnabled,
    required this.emailEnabled,
    required this.taskRemindersEnabled,
    required this.paymentRemindersEnabled,
    required this.providerMessagesEnabled,
    required this.createdAt,
    required this.updatedAt,
  });

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      id: json['id'].toString(),
      userId: json['userId'].toString(),
      pushEnabled: json['pushEnabled'] == true,
      smsEnabled: json['smsEnabled'] == true,
      whatsappEnabled: json['whatsappEnabled'] == true,
      emailEnabled: json['emailEnabled'] == true,
      taskRemindersEnabled: json['taskRemindersEnabled'] == true,
      paymentRemindersEnabled: json['paymentRemindersEnabled'] == true,
      providerMessagesEnabled: json['providerMessagesEnabled'] == true,
      createdAt: _dateTimeOrNull(json['createdAt']) ?? DateTime.now(),
      updatedAt: _dateTimeOrNull(json['updatedAt']) ?? DateTime.now(),
    );
  }

  final String id;
  final String userId;
  final bool pushEnabled;
  final bool smsEnabled;
  final bool whatsappEnabled;
  final bool emailEnabled;
  final bool taskRemindersEnabled;
  final bool paymentRemindersEnabled;
  final bool providerMessagesEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toUpdateJson() {
    return {
      'pushEnabled': pushEnabled,
      'smsEnabled': smsEnabled,
      'whatsappEnabled': whatsappEnabled,
      'emailEnabled': emailEnabled,
      'taskRemindersEnabled': taskRemindersEnabled,
      'paymentRemindersEnabled': paymentRemindersEnabled,
      'providerMessagesEnabled': providerMessagesEnabled,
    };
  }

  UserSettings copyWith({
    bool? pushEnabled,
    bool? smsEnabled,
    bool? whatsappEnabled,
    bool? emailEnabled,
    bool? taskRemindersEnabled,
    bool? paymentRemindersEnabled,
    bool? providerMessagesEnabled,
  }) {
    return UserSettings(
      id: id,
      userId: userId,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      smsEnabled: smsEnabled ?? this.smsEnabled,
      whatsappEnabled: whatsappEnabled ?? this.whatsappEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      taskRemindersEnabled: taskRemindersEnabled ?? this.taskRemindersEnabled,
      paymentRemindersEnabled:
          paymentRemindersEnabled ?? this.paymentRemindersEnabled,
      providerMessagesEnabled:
          providerMessagesEnabled ?? this.providerMessagesEnabled,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  bool sameValues(UserSettings other) {
    return pushEnabled == other.pushEnabled &&
        smsEnabled == other.smsEnabled &&
        whatsappEnabled == other.whatsappEnabled &&
        emailEnabled == other.emailEnabled &&
        taskRemindersEnabled == other.taskRemindersEnabled &&
        paymentRemindersEnabled == other.paymentRemindersEnabled &&
        providerMessagesEnabled == other.providerMessagesEnabled;
  }

  static DateTime? _dateTimeOrNull(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

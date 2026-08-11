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
    this.channelCapabilities = NotificationChannelCapabilities.defaults,
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
      channelCapabilities: NotificationChannelCapabilities.fromJson(
        json['channelCapabilities'],
      ),
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
  final NotificationChannelCapabilities channelCapabilities;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toUpdateJson() {
    return {
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
    NotificationChannelCapabilities? channelCapabilities,
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
      channelCapabilities: channelCapabilities ?? this.channelCapabilities,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  bool sameValues(UserSettings other) {
    return taskRemindersEnabled == other.taskRemindersEnabled &&
        paymentRemindersEnabled == other.paymentRemindersEnabled &&
        providerMessagesEnabled == other.providerMessagesEnabled;
  }

  static DateTime? _dateTimeOrNull(Object? value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}

class NotificationChannelCapability {
  const NotificationChannelCapability({
    required this.supported,
    required this.configurable,
    required this.enabled,
  });

  factory NotificationChannelCapability.fromJson(
    Object? value, {
    required NotificationChannelCapability fallback,
  }) {
    if (value is! Map) return fallback;
    return NotificationChannelCapability(
      supported: value['supported'] == true,
      configurable: value['configurable'] == true,
      enabled: value['enabled'] == true,
    );
  }

  final bool supported;
  final bool configurable;
  final bool enabled;
}

class NotificationChannelCapabilities {
  const NotificationChannelCapabilities({
    required this.inApp,
    required this.push,
    required this.sms,
    required this.whatsapp,
    required this.email,
  });

  factory NotificationChannelCapabilities.fromJson(Object? value) {
    final json = value is Map ? value : const <Object?, Object?>{};
    return NotificationChannelCapabilities(
      inApp: NotificationChannelCapability.fromJson(
        json['inApp'],
        fallback: defaults.inApp,
      ),
      push: NotificationChannelCapability.fromJson(
        json['push'],
        fallback: defaults.push,
      ),
      sms: NotificationChannelCapability.fromJson(
        json['sms'],
        fallback: defaults.sms,
      ),
      whatsapp: NotificationChannelCapability.fromJson(
        json['whatsapp'],
        fallback: defaults.whatsapp,
      ),
      email: NotificationChannelCapability.fromJson(
        json['email'],
        fallback: defaults.email,
      ),
    );
  }

  static const defaults = NotificationChannelCapabilities(
    inApp: NotificationChannelCapability(
      supported: true,
      configurable: false,
      enabled: true,
    ),
    push: NotificationChannelCapability(
      supported: false,
      configurable: false,
      enabled: false,
    ),
    sms: NotificationChannelCapability(
      supported: false,
      configurable: false,
      enabled: false,
    ),
    whatsapp: NotificationChannelCapability(
      supported: false,
      configurable: false,
      enabled: false,
    ),
    email: NotificationChannelCapability(
      supported: false,
      configurable: false,
      enabled: false,
    ),
  );

  final NotificationChannelCapability inApp;
  final NotificationChannelCapability push;
  final NotificationChannelCapability sms;
  final NotificationChannelCapability whatsapp;
  final NotificationChannelCapability email;

  bool get inAppAvailable => inApp.supported && inApp.enabled;

  bool get externalDeliverySupported =>
      push.supported || sms.supported || whatsapp.supported || email.supported;

  bool pushAvailableOnDevice(bool localGatewayAvailable) =>
      push.supported && localGatewayAvailable;
}

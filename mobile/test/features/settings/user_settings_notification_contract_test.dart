import 'package:aarast_mobile/features/settings/models/user_settings.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('notification settings parse truthful channel capabilities', () {
    final settings = UserSettings.fromJson({
      'id': 'settings-1',
      'userId': 'user-1',
      'pushEnabled': false,
      'smsEnabled': false,
      'whatsappEnabled': false,
      'emailEnabled': false,
      'taskRemindersEnabled': true,
      'paymentRemindersEnabled': false,
      'providerMessagesEnabled': true,
      'channelCapabilities': {
        'inApp': {'supported': true, 'configurable': false, 'enabled': true},
        'push': {'supported': true, 'configurable': false, 'enabled': false},
        'sms': {'supported': false, 'configurable': false, 'enabled': false},
        'whatsapp': {
          'supported': false,
          'configurable': false,
          'enabled': false,
        },
        'email': {'supported': false, 'configurable': false, 'enabled': false},
      },
      'createdAt': '2026-07-26T00:00:00.000Z',
      'updatedAt': '2026-07-26T00:00:00.000Z',
    });

    expect(settings.channelCapabilities.inAppAvailable, isTrue);
    expect(settings.channelCapabilities.externalDeliverySupported, isTrue);
    expect(settings.channelCapabilities.push.configurable, isFalse);
  });

  test(
    'settings update payload contains only supported content preferences',
    () {
      final settings = _settings();

      expect(settings.toUpdateJson(), {
        'taskRemindersEnabled': true,
        'paymentRemindersEnabled': false,
        'providerMessagesEnabled': true,
      });
      expect(settings.toUpdateJson(), isNot(contains('pushEnabled')));
      expect(settings.toUpdateJson(), isNot(contains('smsEnabled')));
      expect(settings.toUpdateJson(), isNot(contains('whatsappEnabled')));
      expect(settings.toUpdateJson(), isNot(contains('emailEnabled')));
    },
  );

  test('missing capabilities retain the app-level push capability', () {
    final settings = UserSettings.fromJson({
      'id': 'settings-1',
      'userId': 'user-1',
      'pushEnabled': true,
      'smsEnabled': true,
      'whatsappEnabled': true,
      'emailEnabled': true,
      'taskRemindersEnabled': true,
      'paymentRemindersEnabled': true,
      'providerMessagesEnabled': true,
      'createdAt': '2026-07-26T00:00:00.000Z',
      'updatedAt': '2026-07-26T00:00:00.000Z',
    });

    expect(settings.channelCapabilities.inAppAvailable, isTrue);
    expect(settings.channelCapabilities.externalDeliverySupported, isTrue);
    expect(
      settings.sameValues(
        settings.copyWith(
          pushEnabled: false,
          smsEnabled: false,
          whatsappEnabled: false,
          emailEnabled: false,
        ),
      ),
      isTrue,
    );
  });
}

UserSettings _settings() {
  return UserSettings(
    id: 'settings-1',
    userId: 'user-1',
    pushEnabled: false,
    smsEnabled: false,
    whatsappEnabled: false,
    emailEnabled: false,
    taskRemindersEnabled: true,
    paymentRemindersEnabled: false,
    providerMessagesEnabled: true,
    createdAt: DateTime.utc(2026, 7, 26),
    updatedAt: DateTime.utc(2026, 7, 26),
  );
}

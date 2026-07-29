import 'package:aarast_mobile/core/config/app_feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppFeatureFlags', () {
    test('contains only rollout switches consumed by live code', () {
      const flags = AppFeatureFlags.defaults;

      expect(flags.enableGuestFirstOnboarding, isTrue);
      expect(flags.enablePushNotifications, isTrue);
      expect(
        flags.toMap().keys,
        containsAll(<String>[
          'enableGuestFirstOnboarding',
          'enableOfflineSync',
          'enablePushNotifications',
          'devBypassLoginGatesForUxExploration',
        ]),
      );
      expect(flags.toMap(), hasLength(4));
      expect(AppFeatureFlags.devBypassLoginGatesForUxExploration, isFalse);
    });

    test('keeps offline sync enabled without changing current UI behavior', () {
      const flags = AppFeatureFlags.defaults;

      expect(flags.enableOfflineSync, isTrue);
      expect(flags.enabledFlagNames, contains('enableOfflineSync'));
      expect(flags.enabledFlagNames, contains('enableGuestFirstOnboarding'));
      expect(flags.enabledFlagNames, contains('enablePushNotifications'));
      expect(flags.isEnabled('unknownFlag'), isFalse);
    });
  });
}

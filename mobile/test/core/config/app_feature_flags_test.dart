import 'package:aarast_mobile/core/config/app_feature_flags.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppFeatureFlags', () {
    test('keeps incomplete or risky features disabled by default', () {
      const flags = AppFeatureFlags.defaults;

      expect(flags.enableGuestFirstOnboarding, isTrue);
      expect(flags.enableProviderMode, isFalse);
      expect(flags.enableProviderQuotes, isFalse);
      expect(flags.enableGuestContacts, isFalse);
      expect(flags.enableAIHelper, isFalse);
      expect(flags.enablePushNotifications, isFalse);
      expect(flags.enableSubscriptions, isFalse);
      expect(flags.enableMaps, isFalse);
      expect(flags.enableAnalytics, isFalse);
      expect(flags.enableNewUserBottomNavigation, isFalse);
      expect(flags.enableProviderShell, isFalse);
      expect(flags.enableSingleDashboardSummary, isFalse);
      expect(AppFeatureFlags.devBypassLoginGatesForUxExploration, isFalse);
    });

    test('keeps offline sync enabled without changing current UI behavior', () {
      const flags = AppFeatureFlags.defaults;

      expect(flags.enableOfflineSync, isTrue);
      expect(flags.enabledFlagNames, contains('enableOfflineSync'));
      expect(flags.enabledFlagNames, contains('enableGuestFirstOnboarding'));
      expect(flags.enabledFlagNames, isNot(contains('enableAIHelper')));
    });
  });
}

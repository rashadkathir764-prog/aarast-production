class AppFeatureFlags {
  // Explicit local development escape hatch. Normal builds keep account and
  // provider gates real unless this dart-define is intentionally enabled.
  // ApiConfig and both native release pipelines reject it in product builds.
  static const bool devBypassLoginGatesForUxExploration = bool.fromEnvironment(
    'AARAST_DEV_BYPASS_LOGIN_GATES',
    defaultValue: false,
  );

  const AppFeatureFlags({
    required this.enableGuestFirstOnboarding,
    required this.enableOfflineSync,
    required this.enablePushNotifications,
  });

  static const defaults = AppFeatureFlags(
    enableGuestFirstOnboarding: true,
    enableOfflineSync: true,
    enablePushNotifications: true,
  );

  /// These are rollout switches consumed by live production code. Product
  /// exclusions are enforced by route/auth/domain contracts, not inert flags.
  final bool enableGuestFirstOnboarding;
  final bool enableOfflineSync;
  final bool enablePushNotifications;

  bool isEnabled(String flagName) {
    return switch (flagName) {
      'enableGuestFirstOnboarding' => enableGuestFirstOnboarding,
      'enableOfflineSync' => enableOfflineSync,
      'enablePushNotifications' => enablePushNotifications,
      'devBypassLoginGatesForUxExploration' =>
        devBypassLoginGatesForUxExploration,
      _ => false,
    };
  }

  Map<String, bool> toMap() {
    return {
      'enableGuestFirstOnboarding': enableGuestFirstOnboarding,
      'enableOfflineSync': enableOfflineSync,
      'enablePushNotifications': enablePushNotifications,
      'devBypassLoginGatesForUxExploration':
          devBypassLoginGatesForUxExploration,
    };
  }

  List<String> get enabledFlagNames {
    return toMap().entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList(growable: false);
  }
}

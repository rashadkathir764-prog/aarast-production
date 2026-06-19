class AppFeatureFlags {
  const AppFeatureFlags({
    required this.enableGuestFirstOnboarding,
    required this.enableProviderMode,
    required this.enableProviderQuotes,
    required this.enableGuestContacts,
    required this.enableOfflineSync,
    required this.enableAIHelper,
    required this.enablePushNotifications,
    required this.enableSubscriptions,
    required this.enableMaps,
    required this.enableAnalytics,
    required this.enableNewUserBottomNavigation,
    required this.enableProviderShell,
    required this.enableSingleDashboardSummary,
  });

  static const defaults = AppFeatureFlags(
    enableGuestFirstOnboarding: false,
    enableProviderMode: false,
    enableProviderQuotes: false,
    enableGuestContacts: false,
    enableOfflineSync: true,
    enableAIHelper: false,
    enablePushNotifications: false,
    enableSubscriptions: false,
    enableMaps: false,
    enableAnalytics: false,
    enableNewUserBottomNavigation: false,
    enableProviderShell: false,
    enableSingleDashboardSummary: false,
  );

  final bool enableGuestFirstOnboarding;
  final bool enableProviderMode;
  final bool enableProviderQuotes;
  final bool enableGuestContacts;
  final bool enableOfflineSync;
  final bool enableAIHelper;
  final bool enablePushNotifications;
  final bool enableSubscriptions;
  final bool enableMaps;
  final bool enableAnalytics;
  final bool enableNewUserBottomNavigation;
  final bool enableProviderShell;
  final bool enableSingleDashboardSummary;

  bool isEnabled(String flagName) {
    return switch (flagName) {
      'enableGuestFirstOnboarding' => enableGuestFirstOnboarding,
      'enableProviderMode' => enableProviderMode,
      'enableProviderQuotes' => enableProviderQuotes,
      'enableGuestContacts' => enableGuestContacts,
      'enableOfflineSync' => enableOfflineSync,
      'enableAIHelper' => enableAIHelper,
      'enablePushNotifications' => enablePushNotifications,
      'enableSubscriptions' => enableSubscriptions,
      'enableMaps' => enableMaps,
      'enableAnalytics' => enableAnalytics,
      'enableNewUserBottomNavigation' => enableNewUserBottomNavigation,
      'enableProviderShell' => enableProviderShell,
      'enableSingleDashboardSummary' => enableSingleDashboardSummary,
      _ => false,
    };
  }

  Map<String, bool> toMap() {
    return {
      'enableGuestFirstOnboarding': enableGuestFirstOnboarding,
      'enableProviderMode': enableProviderMode,
      'enableProviderQuotes': enableProviderQuotes,
      'enableGuestContacts': enableGuestContacts,
      'enableOfflineSync': enableOfflineSync,
      'enableAIHelper': enableAIHelper,
      'enablePushNotifications': enablePushNotifications,
      'enableSubscriptions': enableSubscriptions,
      'enableMaps': enableMaps,
      'enableAnalytics': enableAnalytics,
      'enableNewUserBottomNavigation': enableNewUserBottomNavigation,
      'enableProviderShell': enableProviderShell,
      'enableSingleDashboardSummary': enableSingleDashboardSummary,
    };
  }

  List<String> get enabledFlagNames {
    return toMap().entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList(growable: false);
  }
}

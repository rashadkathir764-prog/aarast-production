import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:aarast_mobile/core/network/api_client.dart';
import 'package:aarast_mobile/core/preferences/device_preferences.dart';
import 'package:aarast_mobile/core/push/push_notifications_controller.dart';
import 'package:aarast_mobile/core/session/safe_user.dart';
import 'package:aarast_mobile/core/storage/auth_storage.dart';
import 'package:aarast_mobile/features/account_contexts/data/account_contexts_api.dart'
    show AccountContextsGateway;
import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:aarast_mobile/features/account_contexts/providers/account_context_controller.dart';
import 'package:aarast_mobile/features/auth/data/auth_repository.dart';
import 'package:aarast_mobile/features/auth/providers/auth_controller.dart';
import 'package:aarast_mobile/features/settings/data/settings_api.dart';
import 'package:aarast_mobile/features/settings/models/preference_coverage.dart';
import 'package:aarast_mobile/features/settings/models/user_settings.dart';
import 'package:aarast_mobile/features/settings/providers/settings_provider.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'plugin_like_push_gateway.dart';

// The notification settings' world, faked at its edges only: the phone's
// answer about notifications (`PushNotificationsController.phoneState` and
// its actions), the account's roles (`AccountContextController`), and the
// server's settings and schedule (`SettingsApi`, whose schedule is the
// server's own answer in test/fixtures/reminder_schedule.json). The pages,
// the provider and the lines run as they do in the app.

/// The server's own schedule answer (kept by the backend's
/// `reminder-schedule.test.ts`).
Map<String, dynamic> serverScheduleAnswer() =>
    jsonDecode(File('test/fixtures/reminder_schedule.json').readAsStringSync())
        as Map<String, dynamic>;

/// The phone's notifications as a test sets them.
class FakePhonePush extends PushNotificationsController {
  FakePhonePush(
    SharedPreferences preferences, {
    required this.state,
    this.blocked = const {},
    this.settingsOpen = true,
    this.stateAfterAsk,
  }) : super(
         preferences: preferences,
         gateway: PluginLikePushGateway(),
         registrationApi: RecordingPushRegistry(),
       );

  PushPhoneState state;
  Set<String> blocked;

  /// Whether the phone opens its settings when asked.
  bool settingsOpen;

  /// What the phone answers the permission question.
  PushPhoneState? stateAfterAsk;

  int reads = 0;
  int asks = 0;
  int settingsOpened = 0;
  int linked = 0;
  final channelsOpened = <String>[];

  @override
  Future<PushPhoneState> phoneState() async {
    reads += 1;
    return state;
  }

  @override
  Set<String> get blockedChannels => blocked;

  @override
  Future<PushPhoneState> askFromSettings() async {
    asks += 1;
    state = stateAfterAsk ?? state;
    return state;
  }

  @override
  Future<bool> openPhoneSettings() async {
    settingsOpened += 1;
    return settingsOpen;
  }

  @override
  Future<bool> openChannelSettings(String channelId) async {
    channelsOpened.add(channelId);
    return settingsOpen;
  }

  @override
  Future<void> turnedOnInPhoneSettings() async {
    linked += 1;
  }
}

/// The account's plans and provider profile, as the settings read them.
class RolesAccounts extends AccountContextController {
  RolesAccounts(
    SharedPreferences preferences, {
    this.owner = false,
    this.member = false,
    this.provider = false,
  }) : super(
         contextsApi: const _NoContexts(),
         authStorage: AuthStorage(preferences),
         setActiveWeddingPlan: (_) async {},
       );

  final bool owner;
  final bool member;
  final bool provider;

  @override
  List<AccountContext> get availableContexts => [
    if (owner) _context('plan:own', AccountContextRole.owner),
    if (member) _context('plan:friend', AccountContextRole.contributor),
    if (provider) _context('provider:1', AccountContextRole.provider),
  ];
}

AccountContext _context(String key, AccountContextRole role) => AccountContext(
  contextKey: key,
  role: role,
  weddingPlanId: role == AccountContextRole.provider ? null : key,
  providerId: role == AccountContextRole.provider ? key : null,
  membershipId: null,
  membershipAuthorityVersion: null,
  persona: null,
  readerFeminine: null,
  displayName: key,
  lifecycle: 'ACTIVE',
  accessMode: AccountContextAccessMode.full,
  capabilities: const AccountContextCapabilities(
    canViewProviderProfile: false,
    canManageProviderProfile: false,
    canUseProviderOperations: false,
  ),
  permissions: const AccountContextPermissions(
    canViewPlan: true,
    canEditPlan: true,
    canManageTasks: true,
    canManageGuests: true,
    canManageProviders: true,
    canInviteMembers: true,
    canViewMoney: true,
    canManageMoney: true,
    canManageProviderProfile: false,
  ),
  isAvailable: true,
  unavailableReason: null,
);

class _NoContexts implements AccountContextsGateway {
  const _NoContexts();

  @override
  Future<List<AccountContext>> listContexts() async => const [];

  @override
  Future<AccountContext> validateContext(String contextKey) =>
      throw StateError('no contexts');
}

/// How the server answers the settings.
enum SettingsServer {
  /// Answers at once.
  answers,

  /// Out of reach, with the phone's copy: the copy shows, marked.
  offlineWithCopy,

  /// Never answers (still loading): the switches' room stands empty.
  neverAnswers,

  /// Out of reach and no copy on the phone.
  fails,
}

class FakeNotificationSettingsApi extends SettingsApi {
  FakeNotificationSettingsApi({
    this.server = SettingsServer.answers,
    this.withSchedule = true,
    this.tasks = true,
    this.money = true,
    this.bookings = true,
    this.providers = true,
  }) : super(ApiClient(tokenProvider: () async => null));

  final SettingsServer server;
  final bool withSchedule;
  bool tasks;
  bool money;
  bool bookings;
  bool providers;

  int getCalls = 0;
  final saved = <Map<String, dynamic>>[];

  /// Set: a save waits for it. [saveFails]: a save is refused.
  Completer<void>? saveGate;
  bool saveFails = false;

  UserSettings _current() => UserSettings(
    id: 'settings-1',
    userId: 'user-1',
    pushEnabled: true,
    whatsappEnabled: false,
    emailEnabled: false,
    smsEnabled: false,
    taskRemindersEnabled: tasks,
    paymentRemindersEnabled: money,
    providerMessagesEnabled: providers,
    bookingRemindersEnabled: bookings,
    createdAt: DateTime(2026, 9, 1),
    updatedAt: DateTime(2026, 10, 12),
  );

  @override
  Future<UserSettings> getSettings() {
    getCalls += 1;
    return switch (server) {
      SettingsServer.answers => Future.value(_current()),
      SettingsServer.neverAnswers => Completer<UserSettings>().future,
      _ => Future.error(const SocketException('no network')),
    };
  }

  @override
  Future<UserSettings?> cachedSettings() async =>
      server == SettingsServer.offlineWithCopy ? _current() : null;

  @override
  Future<UserSettings> updateSettings(UserSettings settings) async {
    await saveGate?.future;
    if (saveFails) throw const ApiException('refused');
    saved.add(settings.toUpdateJson());
    tasks = settings.taskRemindersEnabled;
    money = settings.paymentRemindersEnabled;
    bookings = settings.bookingRemindersEnabled;
    providers = settings.providerMessagesEnabled;
    return _current();
  }

  @override
  Future<NotificationSchedule> getNotificationSchedule() async {
    if (!withSchedule || server != SettingsServer.answers) {
      throw const SocketException('no network');
    }
    return NotificationSchedule.fromResponse(serverScheduleAnswer());
  }

  @override
  Future<NotificationSchedule?> cachedNotificationSchedule() async =>
      withSchedule && server == SettingsServer.offlineWithCopy
      ? NotificationSchedule.fromResponse(serverScheduleAnswer())
      : null;
}

const settingsUser = SafeUser(
  id: 'user-1',
  name: 'محمد الحمدي',
  phone: '+967777123456',
  role: 'USER',
  status: 'ACTIVE',
);

class _SignedIn extends AuthRepository {
  _SignedIn(AuthStorage storage)
    : super(ApiClient(tokenProvider: () async => 'token'), storage);

  @override
  Future<String?> readAccessToken() async => 'token';

  @override
  SafeUser? readCachedUser() => settingsUser;

  @override
  Future<SafeUser> me() async => settingsUser;
}

/// Everything the settings pages read, signed in.
class NotificationSettingsWorld {
  NotificationSettingsWorld._(
    this.preferences,
    this.push,
    this.api,
    this.settings,
    this.providers,
  );

  final SharedPreferences preferences;

  /// Null: a build without push at all.
  final FakePhonePush? push;
  final FakeNotificationSettingsApi api;
  final SettingsProvider settings;
  final List<SingleChildWidget> providers;

  static Future<NotificationSettingsWorld> create({
    PushPhoneState? phone = PushPhoneState.on,
    Set<String> blocked = const {},
    FakeNotificationSettingsApi? api,
    bool owner = true,
    bool member = false,
    bool provider = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = AuthStorage(preferences);
    await storage.saveSession(accessToken: 'token', user: settingsUser);
    final repository = _SignedIn(storage);
    final auth = AuthController(repository);
    await auth.restoreSession();
    final push = phone == null
        ? null
        : FakePhonePush(preferences, state: phone, blocked: blocked);
    final settingsApi = api ?? FakeNotificationSettingsApi();
    final settings = SettingsProvider(settingsApi);
    return NotificationSettingsWorld._(
      preferences,
      push,
      settingsApi,
      settings,
      [
        Provider<AuthStorage>.value(value: storage),
        Provider<AuthRepository>.value(value: repository),
        ChangeNotifierProvider<AuthController>.value(value: auth),
        ChangeNotifierProvider<DevicePreferences>.value(
          value: DevicePreferences(preferences),
        ),
        ChangeNotifierProvider<AccountContextController>.value(
          value: RolesAccounts(
            preferences,
            owner: owner,
            member: member,
            provider: provider,
          ),
        ),
        if (push != null)
          ChangeNotifierProvider<PushNotificationsController>.value(
            value: push,
          ),
        ChangeNotifierProvider<SettingsProvider>.value(value: settings),
      ],
    );
  }
}

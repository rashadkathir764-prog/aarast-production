import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/l10n/aarast_text.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController, AccountContextRole;
import '../../auth/auth_api.dart' show AuthActionGuard, AuthGatePanel;
import '../models/preference_coverage.dart';
import '../providers/settings_provider.dart';
import '../utils/notice_coverage.dart';
import '../utils/reminder_timing_lines.dart';
import '../widgets/notification_settings_parts.dart';

/// g07 «إعدادات الإشعارات» (REFINEMENT_SPEC 2.5). Three things, apart:
/// - «هذا الجوال»: what this phone does with notifications, first and
///   always, whatever the server's settings are doing;
/// - «ما يصلك منّا»: the account's four switches, each saved the moment it
///   is switched (C60), each saying what it covers (the server's
///   `preferenceCoverage`, as this reader gets it) and when it comes (the
///   server's reminder table), or, off, that nothing of it comes;
/// - «حين تسند مهمة إلى أحد»: a choice of this phone about the message it
///   prepares, which is not a notification and has its own title.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isCheckingAccount = true;
  bool _showLoginGate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refreshAccountAndLoad();
    });
  }

  Future<void> _refreshAccountAndLoad() async {
    setState(() {
      _isCheckingAccount = true;
      _showLoginGate = false;
    });
    final shouldGate = await AuthActionGuard.shouldGateAccountOnly(context);
    if (!mounted) return;
    setState(() {
      _isCheckingAccount = false;
      _showLoginGate = shouldGate;
    });
    if (!shouldGate) await context.read<SettingsProvider>().loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    final words = context.text;
    return AarastScreenFrame(
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        color: context.accent.primary,
        onRefresh: _refreshAccountAndLoad,
        child: ListView(
          padding: AarastV3Density.pageInsets,
          children: [
            JourneySubHeader(
              title: words.notificationSettingsTitle,
              onBack: () =>
                  context.canPop() ? context.pop() : context.go(AppRouter.more),
            ),
            if (_showLoginGate)
              AuthGatePanel(
                title: words.settingsSignInTitle(context.gender),
                body: words.settingsSignInBody,
                icon: LucideIcons.bell,
                scrolls: false,
              )
            else ...[
              const PhoneNotificationsSection(weddingNews: true),
              _Switches(checkingAccount: _isCheckingAccount),
            ],
            if (!_isCheckingAccount) const _TaskMessageChoice(),
          ],
        ),
      ),
    );
  }
}

/// The account's four switches, as this reader gets them.
class _Switches extends StatelessWidget {
  const _Switches({required this.checkingAccount});

  final bool checkingAccount;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final draft = checkingAccount ? null : settings.draft;
    final reader = _reader(context);
    final words = context.text;
    final schedule = settings.schedule;
    final lines = schedule == null
        ? null
        : reminderTimingLines(schedule, gender: context.gender);
    final coverage = settings.coverage;
    String? includes(NotificationSwitch key) => coverage == null
        ? null
        : coverageIncludesLine(coverage.switches[key]!, reader);
    // One save at a time: every switch rests while one is saved.
    ValueChanged<bool>? saving(UserSettingsChange change) =>
        settings.isSubmitting || draft == null
        ? null
        : (value) => saveNotificationSwitch(context, change(value));
    return NotificationPreferencesSection(
      loadingRows: 4,
      alwaysLine: coverage == null
          ? null
          : coverageAlwaysLine(coverage.always, reader),
      rows: draft == null
          ? null
          : [
              NotificationSwitchRow(
                key: const Key('settings-task-reminders-switch'),
                title: words.switchTasks,
                includes: includes(NotificationSwitch.tasks),
                timing: lines?.tasks,
                value: draft.taskRemindersEnabled,
                onChanged: saving(
                  (value) => draft.copyWith(taskRemindersEnabled: value),
                ),
              ),
              NotificationSwitchRow(
                key: const Key('settings-payment-reminders-switch'),
                title: words.switchMoney,
                includes: includes(NotificationSwitch.money),
                timing: lines?.money(ownsPlan: reader.ownsPlan),
                value: draft.paymentRemindersEnabled,
                onChanged: saving(
                  (value) => draft.copyWith(paymentRemindersEnabled: value),
                ),
              ),
              NotificationSwitchRow(
                key: const Key('settings-booking-reminders-switch'),
                title: words.switchBookingReminders,
                includes: includes(NotificationSwitch.bookingReminders),
                timing: lines?.bookings,
                value: draft.bookingRemindersEnabled,
                onChanged: saving(
                  (value) => draft.copyWith(bookingRemindersEnabled: value),
                ),
              ),
              // Offers and messages come as they happen: no timing line;
              // the night line under the phone says what waits till morning.
              NotificationSwitchRow(
                key: const Key('settings-provider-messages-switch'),
                title: words.switchProviders,
                includes: includes(NotificationSwitch.providers),
                value: draft.providerMessagesEnabled,
                onChanged: saving(
                  (value) => draft.copyWith(providerMessagesEnabled: value),
                ),
              ),
            ],
    );
  }

  /// Who reads: the plan they own (the owner's money reminders), the plans
  /// they help in (a member's notices), a provider profile (his customers'
  /// notices share the providers' switch).
  static NoticeReader _reader(BuildContext context) {
    final contexts =
        context.watch<AccountContextController?>()?.availableContexts ??
        const [];
    bool has(AccountContextRole role) =>
        contexts.any((account) => account.role == role);
    return NoticeReader.couple(
      ownsPlan: has(AccountContextRole.owner),
      memberOfPlan: has(AccountContextRole.contributor),
      hasProviderProfile: has(AccountContextRole.provider),
      bridePlan: context.journeyProfile.isBride,
    );
  }
}

/// What happens right after a task is given to someone with a number. A
/// choice of this phone, not a notification: it gets its own title under
/// the notifications, and shows without an account too (the message leaves
/// from this phone).
class _TaskMessageChoice extends StatelessWidget {
  const _TaskMessageChoice();

  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<DevicePreferences?>();
    if (preferences == null) return const SizedBox.shrink();
    final current = preferences.taskMessageMode;
    final words = context.text;
    final gender = context.gender;
    return Column(
      key: const Key('settings-task-message'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        JourneySectionTitle(words.taskMessageTitle(gender)),
        JourneyBox(
          padding: AarastV3Density.cardInsets,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                words.taskMessageBody(gender),
                style: JourneyType.of(
                  JourneyType.body,
                  color: AarastV3Color.textMuted,
                ),
              ),
              const SizedBox(height: AarastV3Space.x2),
              Wrap(
                spacing: AarastV3Space.x2,
                children: [
                  for (final (mode, label) in [
                    (TaskMessageMode.ask, words.taskMessageAsk),
                    (TaskMessageMode.whatsApp, words.taskMessageWhatsApp),
                    (TaskMessageMode.off, words.taskMessageOff),
                  ])
                    JourneyChip(
                      key: Key('settings-task-message-${mode.name}'),
                      label: label,
                      selected: current == mode,
                      selectedColor: context.accent.primary,
                      onTap: () => preferences.setTaskMessageMode(mode),
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

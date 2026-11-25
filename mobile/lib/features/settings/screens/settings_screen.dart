import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/preferences/device_preferences.dart';
import '../../../core/push/push_notifications_controller.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthActionGuard, AuthGatePanel;
import '../models/user_settings.dart';
import '../providers/settings_provider.dart';

/// g07 «التنبيهات»: the reminders the server sends, each saved the moment
/// it is switched. Kept to what the server has (C60): tasks, payments (a
/// week before, the server's lead time) and offers with conversations.
/// Quiet hours, the Friday digest, guest replies and participants' activity
/// are left out (D24).
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.devicePushAvailableOverride});

  final bool? devicePushAvailableOverride;

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
    final provider = context.watch<SettingsProvider>();
    final draft = provider.draft;
    final devicePushAvailable =
        widget.devicePushAvailableOverride ??
        _maybeDevicePushAvailable(context);

    final Widget body;
    if (_showLoginGate) {
      body = AuthGatePanel(
        title: context.say(
          'سجّل الدخول لإدارة الإعدادات',
          'سجّلي الدخول لإدارة الإعدادات',
        ),
        body: 'التنبيهات مرتبطة بحسابك عشان نحفظها لك.',
        icon: LucideIcons.bell,
        scrolls: false,
      );
    } else if (_isCheckingAccount || (provider.isLoading && draft == null)) {
      body = const JourneyListState(
        phase: JourneyListPhase.loading,
        section: JourneySection.home,
      );
    } else if (draft == null) {
      body = JourneyListState(
        phase: JourneyListPhase.error,
        section: JourneySection.home,
        onRetry: provider.loadSettings,
      );
    } else {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (provider.isStale) ...[
            // D87: the copy is old; the settings queue on the phone (D85).
            JourneyListNotice(
              offline: true,
              keepsChanges: true,
              onRetry: provider.loadSettings,
            ),
            const SizedBox(height: AarastV3Space.x3),
          ],
          JourneyList(
            dividers: false,
            children: [
              _Toggle(
                key: const Key('settings-task-reminders-switch'),
                title: 'المهام',
                subtitle: 'لما يقرب موعدها أو تتأخر',
                value: draft.taskRemindersEnabled,
                onChanged: (value) => _save(
                  provider,
                  draft.copyWith(taskRemindersEnabled: value),
                ),
              ),
              _Toggle(
                key: const Key('settings-payment-reminders-switch'),
                title: 'الدفعات',
                subtitle: 'قبل موعدها بأسبوع',
                value: draft.paymentRemindersEnabled,
                onChanged: (value) => _save(
                  provider,
                  draft.copyWith(paymentRemindersEnabled: value),
                ),
              ),
              _Toggle(
                key: const Key('settings-booking-reminders-switch'),
                title: 'الحجوزات',
                subtitle: 'قبل موعدها بأسبوع وبيوم',
                value: draft.bookingRemindersEnabled,
                onChanged: (value) => _save(
                  provider,
                  draft.copyWith(bookingRemindersEnabled: value),
                ),
              ),
              _Toggle(
                key: const Key('settings-provider-messages-switch'),
                title: 'العروض والمحادثات',
                subtitle: 'أول ما توصل',
                value: draft.providerMessagesEnabled,
                onChanged: (value) => _save(
                  provider,
                  draft.copyWith(providerMessagesEnabled: value),
                ),
              ),
            ],
          ),
          const SizedBox(height: AarastV3Space.x3),
          JourneyNote(
            icon: LucideIcons.lock,
            text: devicePushAvailable
                ? 'على شاشة القفل ما تطلع أسماء ولا مبالغ.'
                : 'هذي النسخة ما توصلها تنبيهات الجوال، تلقاها داخل التطبيق.',
          ),
        ],
      );
    }

    return AarastScreenFrame(
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        color: context.accent.primary,
        onRefresh: _refreshAccountAndLoad,
        child: ListView(
          padding: AarastV3Density.pageInsets,
          children: [
            JourneySubHeader(
              // Critique ع1ت: the list is «التنبيهات»; this is its settings.
              title: 'إعدادات التنبيهات',
              onBack: () =>
                  context.canPop() ? context.pop() : context.go(AppRouter.more),
            ),
            body,
            if (!_isCheckingAccount) const _TaskMessageChoice(),
          ],
        ),
      ),
    );
  }

  /// Saves at once; a failed save puts the switch back.
  Future<void> _save(SettingsProvider provider, UserSettings next) async {
    final before = provider.settings;
    provider.updateDraft(next);
    final ok = await provider.saveSettings();
    if (!mounted || ok) return;
    if (before != null) provider.updateDraft(before);
    AarastToast.showError(
      context,
      provider.errorMessage ??
          context.say(
            'ما قدرنا نحفظ، جرّب مرة ثانية.',
            'ما قدرنا نحفظ، جرّبي مرة ثانية.',
          ),
    );
  }
}

bool _maybeDevicePushAvailable(BuildContext context) {
  try {
    return context.watch<PushNotificationsController>().isAvailable;
  } on ProviderNotFoundException {
    return false;
  }
}

/// What happens right after a task is given to someone with a number. A
/// choice of this phone, kept with its other preferences: the message
/// leaves from here, so it shows without an account too.
class _TaskMessageChoice extends StatelessWidget {
  const _TaskMessageChoice();

  @override
  Widget build(BuildContext context) {
    final preferences = context.watch<DevicePreferences?>();
    if (preferences == null) return const SizedBox.shrink();
    final current = preferences.taskMessageMode;
    return Padding(
      padding: const EdgeInsets.only(top: AarastV3Space.x4),
      child: JourneyBox(
        key: const Key('settings-task-message'),
        padding: const EdgeInsets.all(AarastV3Space.x3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.say('لما تعطي مهمة لأحد', 'لما تعطين مهمة لأحد'),
              style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
            ),
            Text(
              context.say(
                'نجهّز له رسالة فيها المهمة وموعدها، تنرسل من جوالك أنت.',
                'نجهّز له رسالة فيها المهمة وموعدها، تنرسل من جوالك أنتِ.',
              ),
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
            const SizedBox(height: AarastV3Space.x2),
            Wrap(
              spacing: AarastV3Space.x2,
              children: [
                for (final (mode, label) in [
                  (TaskMessageMode.ask, 'اسألني'),
                  (
                    TaskMessageMode.whatsApp,
                    context.say('افتح واتساب مباشرة', 'افتحي واتساب مباشرة'),
                  ),
                  (TaskMessageMode.off, context.say('لا ترسل', 'لا ترسلي')),
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
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    // The whole row flips the switch.
    return AarastPressable(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.all(AarastV3Space.x3),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            JourneyToggle(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

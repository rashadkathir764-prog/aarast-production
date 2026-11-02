import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/push/push_notifications_controller.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/auth_api.dart' show AuthActionGuard, AuthGatePanel;
import '../models/user_settings.dart';
import '../providers/settings_provider.dart';

/// A fixed dimension of this layout, not a spacing step (D74).
const _settingsLoadingHeight = 420.0;

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
      body = const SizedBox(
        height: _settingsLoadingHeight,
        child: AuthGatePanel(
          title: 'سجّل الدخول لإدارة الإعدادات',
          body: 'التنبيهات مرتبطة بحسابك عشان نحفظها لك.',
          icon: LucideIcons.bell,
        ),
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
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        color: context.accent.primary,
        onRefresh: _refreshAccountAndLoad,
        child: ListView(
          padding: AarastV3Density.pageInsets,
          children: [
            JourneySubHeader(
              title: 'التنبيهات',
              onBack: () =>
                  context.canPop() ? context.pop() : context.go(AppRouter.more),
            ),
            body,
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
            'ما قدرنا نحفظ، جرب مرة ثانية.',
            'ما قدرنا نحفظ، جربي مرة ثانية.',
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

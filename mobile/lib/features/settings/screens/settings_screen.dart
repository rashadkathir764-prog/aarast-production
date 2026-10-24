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
        widget.devicePushAvailableOverride ?? _maybeDevicePushAvailable(context);

    final Widget body;
    if (_showLoginGate) {
      body = const SizedBox(
        height: 420,
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
          const SizedBox(height: 14),
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
        color: AarastV3Color.primary,
        onRefresh: _refreshAccountAndLoad,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
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
      provider.errorMessage ?? 'ما قدرنا نحفظ، جرب مرة ثانية.',
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: JourneyType.of(
                    JourneyType.bodyLarge,
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
          Switch(
            value: value,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            activeTrackColor: AarastV3Color.primary,
            inactiveTrackColor: AarastV3Color.line,
            inactiveThumbColor: AarastV3Color.paper,
            trackOutlineColor: const WidgetStatePropertyAll(
              AarastV3Color.line,
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

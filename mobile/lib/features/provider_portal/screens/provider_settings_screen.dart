import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/l10n/aarast_text.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;
import '../../auth/auth_api.dart' show AuthController;
import '../../settings/settings_api.dart'
    show
        NoticeReader,
        NotificationPreferencesSection,
        NotificationSwitch,
        NotificationSwitchRow,
        PhoneNotificationsSection,
        SettingsProvider,
        coverageAlwaysLine,
        coverageIncludesLine,
        saveNotificationSwitch;
import '../providers/provider_dashboard_provider.dart';

/// p40 «الإعدادات»: his notifications and his account. The notifications
/// are the couple's page's design (REFINEMENT_SPEC 2.5): «هذا الجوال» first,
/// then his one switch, the server's `providerMessagesEnabled` (F19), with
/// what it covers for a provider from the server's coverage, and what
/// always comes (the team's decisions, Q-60, D127). The drawn «رقمك يظهر»,
/// «تعهّد…», «ملخص يومي» and «مين يدير الحساب» have nothing behind them
/// (B-31, B-32, B-37). Deleting opens w05 (D63): the account waits 30 days,
/// and a provider with confirmed bookings ahead is refused until they are
/// handed over (B-33).
class ProviderSettingsScreen extends StatefulWidget {
  const ProviderSettingsScreen({super.key});

  @override
  State<ProviderSettingsScreen> createState() => _ProviderSettingsScreenState();
}

class _ProviderSettingsScreenState extends State<ProviderSettingsScreen> {
  bool _working = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SettingsProvider>().loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final words = context.text;
    final settings = context.watch<SettingsProvider>();
    final dashboard = context.watch<ProviderDashboardProvider>();
    final draft = settings.draft;
    final coverage = settings.coverage;
    const reader = NoticeReader.provider;
    final ahead = dashboard.bookingsLoadFailed
        ? null
        : dashboard.upcomingConfirmedBookings;
    return AarastScreenFrame(
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        color: AarastV3Color.primary,
        onRefresh: settings.loadSettings,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: AarastV3Density.pageInsets,
          children: [
            JourneySubHeader(title: words.providerSettingsTitle),
            const PhoneNotificationsSection(weddingNews: false),
            NotificationPreferencesSection(
              loadingRows: 1,
              alwaysLine: coverage == null
                  ? null
                  : coverageAlwaysLine(coverage.always, reader),
              rows: draft == null
                  ? null
                  : [
                      // His requests and messages come as they happen: no
                      // timing line; the night line says what waits.
                      NotificationSwitchRow(
                        key: const Key('provider-settings-messages'),
                        title: words.providerSwitchCustomers,
                        includes: coverage == null
                            ? null
                            : coverageIncludesLine(
                                coverage.switches[NotificationSwitch
                                    .providers]!,
                                reader,
                              ),
                        value: draft.providerMessagesEnabled,
                        onChanged: settings.isSubmitting
                            ? null
                            : (value) => saveNotificationSwitch(
                                context,
                                draft.copyWith(providerMessagesEnabled: value),
                              ),
                      ),
                    ],
            ),
            JourneySectionTitle(words.providerAccountTitle),
            JourneyList(
              children: [
                JourneyListRow(
                  key: const Key('provider-exit-workspace-action'),
                  icon: LucideIcons.repeat,
                  color: AarastV3Color.primary,
                  soft: AarastV3Color.primarySoft,
                  title: words.providerOpenPlanRow,
                  subtitle: words.providerOpenPlanSub,
                  onTap: _working ? null : _confirmExitWorkspace,
                ),
                JourneyListRow(
                  key: const Key('provider-logout-action'),
                  icon: LucideIcons.logOut,
                  color: AarastV3Color.textMuted,
                  soft: AarastV3Color.line,
                  title: words.providerSignOutRow,
                  subtitle: words.providerSignOutSub,
                  onTap: _working ? null : _confirmLogout,
                ),
                JourneyListRow(
                  key: const Key('provider-delete-account-action'),
                  icon: LucideIcons.trash2,
                  color: AarastV3Color.danger,
                  soft: AarastV3Color.dangerSoft,
                  title: words.providerDeleteRow,
                  subtitle: ahead != null && ahead > 0
                      ? words.providerDeleteBlockedSub(ahead)
                      : words.providerDeleteSub,
                  // w05 (D63): one deletion for every account.
                  onTap: _working
                      ? null
                      : () => context.push(AppRouter.deleteAccount),
                ),
              ],
            ),
            if (_failed) ...[
              const SizedBox(height: AarastV3Space.x2),
              JourneyNote(
                key: const Key('provider-settings-error'),
                text: words.providerSettingsActionFailed,
                icon: LucideIcons.alertCircle,
                color: AarastV3Color.danger,
                soft: AarastV3Color.dangerSoft,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<bool> _confirm({
    required String title,
    required String subtitle,
    required String action,
    required Key actionKey,
    Color background = AarastV3Color.primary,
  }) async {
    final words = context.text;
    final confirmed = await showJourneySheet<bool>(
      context: context,
      builder: (sheetContext) => JourneySheetBody(
        title: title,
        subtitle: subtitle,
        children: [
          JourneyButton(
            key: actionKey,
            label: action,
            background: background,
            large: true,
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: AarastV3Space.x2),
          JourneyButton.quiet(
            label: words.providerConfirmCancel,
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
      ),
    );
    return confirmed == true && mounted;
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _working = true;
      _failed = false;
    });
    var failed = false;
    try {
      await action();
    } on Object {
      failed = true;
    }
    if (!mounted) return;
    setState(() {
      _working = false;
      _failed = failed;
    });
  }

  Future<void> _confirmExitWorkspace() async {
    final words = context.text;
    final ok = await _confirm(
      // Critique ب6: no «المسار»; said for any provider.
      title: words.providerOpenPlanConfirmTitle,
      subtitle: words.providerOpenPlanConfirmBody,
      action: words.providerOpenPlanConfirm,
      actionKey: const Key('provider-exit-workspace-confirm'),
    );
    if (!ok) return;
    await _run(_exitWorkspace);
  }

  Future<void> _confirmLogout() async {
    final words = context.text;
    final ok = await _confirm(
      title: words.providerSignOutConfirmTitle,
      subtitle: words.providerSignOutConfirmBody,
      action: words.providerSignOutRow,
      actionKey: const Key('provider-logout-confirm'),
      background: AarastV3Color.danger,
    );
    if (!ok) return;
    await _run(_logout);
  }

  /// Publishes the sign out only: the app's router takes it to the login.
  Future<void> _logout() async {
    await context.read<AuthController>().logout();
  }

  Future<void> _exitWorkspace() async {
    final router = GoRouter.of(context);
    final accountContexts = context.read<AccountContextController>();
    await accountContexts.exitWorkspace();
    await accountContexts.refresh();
    router.go(AppRouter.home);
  }
}

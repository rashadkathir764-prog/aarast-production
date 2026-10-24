import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/push/push_notifications_controller.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;
import '../../auth/auth_api.dart' show AuthController, confirmAccountDeletion;
import '../../settings/settings_api.dart' show SettingsProvider;
import '../providers/provider_dashboard_provider.dart';

/// p40 «الإعدادات»: his notices and his account. One switch is the server's
/// `providerMessagesEnabled`, which covers requests, offers, bookings and
/// messages (F19); notices on the phone follow the phone's own permission
/// (the server refuses to switch `pushEnabled` on), so they get a line, not
/// a switch. The drawn «رقمك يظهر», «تعهّد…», «ملخص يومي» and «مين يدير
/// الحساب» have nothing behind them (B-31, B-32, B-33, B-37). Deleting warns
/// with his confirmed bookings ahead, which the server does not check.
class ProviderSettingsScreen extends StatefulWidget {
  const ProviderSettingsScreen({this.devicePushAvailableOverride, super.key});

  final bool? devicePushAvailableOverride;

  @override
  State<ProviderSettingsScreen> createState() => _ProviderSettingsScreenState();
}

class _ProviderSettingsScreenState extends State<ProviderSettingsScreen> {
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<SettingsProvider>().loadSettings();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final dashboard = context.watch<ProviderDashboardProvider>();
    final draft = settings.draft;
    final pushAvailable =
        widget.devicePushAvailableOverride ?? _devicePushAvailable(context);
    final ahead = dashboard.bookingsLoadFailed
        ? null
        : dashboard.upcomingConfirmedBookings;
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: RefreshIndicator(
        color: AarastV3Color.primary,
        onRefresh: settings.loadSettings,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            const JourneySubHeader(title: 'الإعدادات'),
            if (draft == null)
              settings.isLoading
                  ? const JourneyListState(
                      phase: JourneyListPhase.loading,
                      section: JourneySection.home,
                    )
                  : JourneyListState(
                      phase: JourneyListPhase.error,
                      section: JourneySection.home,
                      onRetry: settings.loadSettings,
                    )
            else
              JourneyList(
                dividers: false,
                children: [
                  _ToggleRow(
                    key: const Key('provider-settings-messages'),
                    title: 'تنبيه لكل طلب ورسالة',
                    subtitle: 'الطلبات والعروض والحجوزات والرسائل',
                    value: draft.providerMessagesEnabled,
                    onChanged: settings.isSubmitting
                        ? null
                        : (value) => _saveMessages(settings, value),
                  ),
                ],
              ),
            const SizedBox(height: 12),
            JourneyNote(
              icon: LucideIcons.smartphone,
              text: pushAvailable
                  ? 'تنبيهات الجوال تشتغل من إذن التنبيهات في جوالك.'
                  : 'هذي النسخة ما توصلها تنبيهات الجوال، تلقاها داخل التطبيق.',
            ),
            const SizedBox(height: 12),
            JourneyList(
              children: [
                JourneyListRow(
                  key: const Key('provider-exit-workspace-action'),
                  icon: LucideIcons.repeat,
                  color: AarastV3Color.primary,
                  soft: AarastV3Color.primarySoft,
                  title: 'افتح خطة عرسي',
                  subtitle: 'نفس الرقم، مسار ثاني',
                  onTap: _working ? null : _confirmExitWorkspace,
                ),
                JourneyListRow(
                  key: const Key('provider-logout-action'),
                  icon: LucideIcons.logOut,
                  color: AarastV3Color.textMuted,
                  soft: AarastV3Color.line,
                  title: 'تسجيل الخروج',
                  subtitle: 'من هذا الجوال',
                  onTap: _working ? null : _confirmLogout,
                ),
                JourneyListRow(
                  key: const Key('provider-delete-account-action'),
                  icon: LucideIcons.trash2,
                  color: AarastV3Color.danger,
                  soft: AarastV3Color.dangerSoft,
                  title: 'حذف الحساب',
                  subtitle: ahead != null && ahead > 0
                      ? 'عندك ${arabicCount(ahead, one: 'حجز جاي', two: 'حجزين جاية', few: 'حجوزات جاية', many: 'حجز جاي')}، الغها قبل ما تحذف'
                      : 'يحذف حسابك وملفك نهائيًا',
                  onTap: _working ? null : _confirmDelete,
                ),
              ],
            ),
            if (_error case final error?) ...[
              const SizedBox(height: 10),
              JourneyNote(
                key: const Key('provider-settings-error'),
                text: error,
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

  /// Saves at once; a failed save puts the switch back.
  Future<void> _saveMessages(SettingsProvider settings, bool value) async {
    final before = settings.settings;
    final draft = settings.draft;
    if (draft == null) return;
    settings.updateDraft(draft.copyWith(providerMessagesEnabled: value));
    final ok = await settings.saveSettings();
    if (!mounted || ok) return;
    if (before != null) settings.updateDraft(before);
    AarastToast.showError(
      context,
      settings.errorMessage ?? 'ما قدرنا نحفظ، جرب مرة ثانية.',
    );
  }

  Future<bool> _confirm({
    required String title,
    required String subtitle,
    required String action,
    required Key actionKey,
    Color background = AarastV3Color.primary,
  }) async {
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
          const SizedBox(height: 8),
          JourneyButton.quiet(
            label: 'لا، خلّيني',
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
      ),
    );
    return confirmed == true && mounted;
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      _working = true;
      _error = null;
    });
    String? error;
    try {
      error = await action();
    } on Object {
      error = 'ما قدرنا نكمّل، جرب مرة ثانية.';
    }
    if (!mounted) return;
    setState(() {
      _working = false;
      _error = error;
    });
  }

  Future<void> _confirmExitWorkspace() async {
    final ok = await _confirm(
      title: 'تفتح خطة عرسك؟',
      subtitle: 'تطلع من حساب المزود لاختيار المسار، وتبقى مسجّل.',
      action: 'افتح المسارات',
      actionKey: const Key('provider-exit-workspace-confirm'),
    );
    if (!ok) return;
    await _run(_exitWorkspace);
  }

  Future<void> _confirmLogout() async {
    final ok = await _confirm(
      title: 'تسجّل خروج؟',
      subtitle: 'تحتاج تدخل من جديد عشان توصل لحساب المزود.',
      action: 'تسجيل الخروج',
      actionKey: const Key('provider-logout-confirm'),
      background: AarastV3Color.danger,
    );
    if (!ok) return;
    await _run(_logout);
  }

  Future<void> _confirmDelete() async {
    final confirmed = await confirmAccountDeletion(
      context,
      keyPrefix: 'provider',
    );
    if (!confirmed || !mounted) return;
    await _run(_deleteAccount);
  }

  Future<String?> _exitWorkspace() async {
    final router = GoRouter.of(context);
    final accountContexts = context.read<AccountContextController>();
    await accountContexts.exitWorkspace();
    await accountContexts.refresh();
    router.go(AppRouter.home);
    return null;
  }

  Future<String?> _logout() async {
    await context.read<AuthController>().logout();
    return null;
  }

  Future<String?> _deleteAccount() async {
    final auth = context.read<AuthController>();
    final deleted = await auth.deleteAccount();
    if (deleted) return null;
    return auth.errorMessage ?? 'ما قدرنا نحذف الحساب، جرب مرة ثانية.';
  }
}

bool _devicePushAvailable(BuildContext context) {
  try {
    return context.watch<PushNotificationsController>().isAvailable;
  } on ProviderNotFoundException {
    return false;
  }
}

/// A switch row (prototype p40 `r`): the title, a muted line, the switch;
/// the whole row flips it.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
                      JourneyType.label,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            JourneyToggle(
              value: value,
              onChanged: onChanged,
              semanticLabel: title,
            ),
          ],
        ),
      ),
    );
  }
}

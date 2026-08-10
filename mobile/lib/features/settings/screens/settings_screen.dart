import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/providers/auth_controller.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../models/user_settings.dart';
import '../providers/settings_provider.dart';

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
      if (!mounted) return;
      _refreshAccountAndLoad();
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

    if (!shouldGate) {
      await context.read<SettingsProvider>().loadSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final auth = context.watch<AuthController>();
    final draft = provider.draft;

    return AarastPageScaffold(
      title: 'الإعدادات',
      subtitle: 'تفضيلات الحساب والتنبيهات',
      child: RefreshIndicator(
        color: AppTheme.brand,
        onRefresh: _refreshAccountAndLoad,
        child: ListView(
          children: [
            _AccountCard(
              name: auth.user?.name ?? 'مستخدم أعرست',
              phone: auth.user?.phone,
              email: auth.user?.email,
            ),
            const SizedBox(height: 14),
            if (_isCheckingAccount)
              AarastSkeleton.list(
                rows: 2,
                rowHeight: 210,
                withHeader: false,
                inline: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
              )
            else if (_showLoginGate)
              const SizedBox(
                height: 420,
                child: AuthGatePanel(
                  title: 'سجّل الدخول لإدارة الإعدادات',
                  body:
                      'الإعدادات مرتبطة بحسابك حتى نحفظ تفضيلات التنبيهات والمزامنة بأمان.',
                  icon: LucideIcons.settings,
                ),
              )
            else if (provider.isLoading && draft == null)
              AarastSkeleton.list(
                rows: 2,
                rowHeight: 210,
                withHeader: false,
                inline: true,
                padding: const EdgeInsets.symmetric(vertical: 8),
              )
            else if (provider.errorMessage != null && draft == null)
              AarastErrorState(
                title: 'تعذر تحميل الإعدادات',
                message: provider.errorMessage!,
                onRetry: provider.loadSettings,
              )
            else if (draft != null) ...[
              _NotificationSettingsCard(
                settings: draft,
                onChanged: provider.updateDraft,
              ),
              const SizedBox(height: 14),
              _StaticPreferencesCard(updatedAt: draft.updatedAt),
              const SizedBox(height: 18),
              if (provider.errorMessage != null) ...[
                _MessageCard(
                  message: provider.errorMessage!,
                  color: AppTheme.danger,
                ),
                const SizedBox(height: 12),
              ],
              if (provider.successMessage != null) ...[
                _MessageCard(
                  message: provider.successMessage!,
                  color: AppTheme.success,
                ),
                const SizedBox(height: 12),
              ],
              AarastButton(
                label: 'حفظ الإعدادات',
                icon: LucideIcons.save,
                isLoading: provider.isSubmitting,
                onPressed: provider.isSubmitting || !provider.hasChanges
                    ? null
                    : provider.saveSettings,
              ),
            ],
            const SizedBox(height: 90),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.name, this.phone, this.email});

  final String name;
  final String? phone;
  final String? email;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AarastV3ContinuousSurface(
      children: [
        AarastV3ListRow(
          title: name,
          subtitle: phone?.trim().isNotEmpty == true
              ? null
              : email?.trim().isNotEmpty == true
              ? email!.trim()
              : 'حساب أعرست',
          details: phone?.trim().isNotEmpty == true
              ? AarastPhoneText(
                  phone: phone!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.brandMuted.withAlpha(120),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(
              LucideIcons.user,
              color: AppTheme.focus,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationSettingsCard extends StatelessWidget {
  const _NotificationSettingsCard({
    required this.settings,
    required this.onChanged,
  });

  final UserSettings settings;
  final ValueChanged<UserSettings> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AarastV3SectionHeader(
          title: 'تفضيلات التنبيهات',
          subtitle: 'الوصول والمتابعة في مكان واحد',
        ),
        const SizedBox(height: AarastV3Space.x2),
        AarastV3ContinuousSurface(
          children: [
            _DeliveryStatusRow(
              key: const Key('settings-in-app-delivery-status'),
              icon: LucideIcons.checkCircle,
              title: 'تنبيهات داخل التطبيق',
              body: settings.channelCapabilities.inAppAvailable
                  ? 'متاحة دائماً داخل صندوق التنبيهات.'
                  : 'غير متاحة حالياً.',
              available: settings.channelCapabilities.inAppAvailable,
            ),
            _DeliveryStatusRow(
              key: const Key('settings-external-delivery-status'),
              icon: LucideIcons.bell,
              title: 'إشعارات الجهاز',
              body: settings.channelCapabilities.push.supported
                  ? 'متاحة للرسائل والمهام عند السماح بها من إعدادات الجهاز.'
                  : 'غير متاحة حالياً على هذا الجهاز.',
              available: settings.channelCapabilities.push.supported,
            ),
            _SwitchRow(
              key: const Key('settings-task-reminders-switch'),
              title: 'تذكير المهام',
              value: settings.taskRemindersEnabled,
              onChanged: (value) =>
                  onChanged(settings.copyWith(taskRemindersEnabled: value)),
            ),
            _SwitchRow(
              key: const Key('settings-payment-reminders-switch'),
              title: 'تذكير مواعيد الدفع',
              value: settings.paymentRemindersEnabled,
              onChanged: (value) =>
                  onChanged(settings.copyWith(paymentRemindersEnabled: value)),
            ),
            _SwitchRow(
              key: const Key('settings-provider-messages-switch'),
              title: 'رسائل الموردين وعروض الأسعار',
              value: settings.providerMessagesEnabled,
              onChanged: (value) =>
                  onChanged(settings.copyWith(providerMessagesEnabled: value)),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeliveryStatusRow extends StatelessWidget {
  const _DeliveryStatusRow({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.available,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final color = available ? AppTheme.success : AppTheme.textSecondary;
    return AarastV3ListRow(
      title: title,
      subtitle: body,
      accent: color,
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
      status: Text(
        available ? 'متاح' : 'غير متاح',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StaticPreferencesCard extends StatelessWidget {
  const _StaticPreferencesCard({required this.updatedAt});

  final DateTime updatedAt;

  @override
  Widget build(BuildContext context) {
    return AarastV3ContinuousSurface(
      children: [
        AarastV3ListRow(
          title: 'لغة التطبيق: العربية',
          meta: 'آخر حفظ: ${formatArabicCompactDate(updatedAt)}',
          accent: AppTheme.focus,
          leading: const Icon(
            LucideIcons.languages,
            size: 18,
            color: AppTheme.focus,
          ),
        ),
      ],
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return AarastV3ListRow(
      title: title,
      accent: value ? AppTheme.brand : AppTheme.textSecondary,
      action: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: Colors.white,
        activeTrackColor: AppTheme.brand,
        inactiveThumbColor: AppTheme.surfaceRaised,
        inactiveTrackColor: AppTheme.surfaceMuted,
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppTheme.brand
              : AppTheme.borderStrong,
        ),
        thumbIcon: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Icon(LucideIcons.check, size: 14, color: AppTheme.brand)
              : null,
        ),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({required this.message, required this.color});

  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: color.withValues(alpha: 0.1),
      border: Border.all(color: color.withValues(alpha: 0.1)),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

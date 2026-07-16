import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/aarast_motion.dart';
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
        color: AppTheme.burgundy,
        onRefresh: _refreshAccountAndLoad,
        child: ListView(
          children: AarastStagger.children(context, [
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
          ]),
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
    return AarastCard(
      color: AppTheme.ivory,
      border: Border.all(color: AppTheme.goldSoft.withAlpha(80)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.goldSoft.withAlpha(120),
              borderRadius: BorderRadius.circular(AppTheme.radiusSm),
            ),
            child: const Icon(LucideIcons.user, color: AppTheme.gold, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                if (phone?.trim().isNotEmpty == true)
                  AarastPhoneText(
                    phone: phone!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  )
                else
                  Text(
                    email?.trim().isNotEmpty == true
                        ? email!.trim()
                        : 'حساب أعرست',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelSmall?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
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
    return AarastCard(
      color: AppTheme.ivory,
      border: Border.all(color: AppTheme.goldSoft.withAlpha(80)),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SettingsHeader(
            icon: LucideIcons.bellRing,
            title: 'تفضيلات التنبيهات',
            compact: true,
          ),
          const _GroupLabel('داخل التطبيق'),
          _SwitchRow(
            title: 'التنبيهات المهمة',
            value: settings.pushEnabled,
            onChanged: (value) =>
                onChanged(settings.copyWith(pushEnabled: value)),
          ),
          _SwitchRow(
            title: 'تذكير المهام',
            value: settings.taskRemindersEnabled,
            onChanged: (value) =>
                onChanged(settings.copyWith(taskRemindersEnabled: value)),
          ),
          _SwitchRow(
            title: 'تذكير مواعيد الدفع',
            value: settings.paymentRemindersEnabled,
            onChanged: (value) =>
                onChanged(settings.copyWith(paymentRemindersEnabled: value)),
          ),
          _SwitchRow(
            title: 'رسائل الموردين وعروض الأسعار',
            value: settings.providerMessagesEnabled,
            onChanged: (value) =>
                onChanged(settings.copyWith(providerMessagesEnabled: value)),
          ),
          const _GroupLabel('قنوات خارجية · عند توفرها'),
          _SwitchRow(
            title: 'واتساب',
            value: settings.whatsappEnabled,
            onChanged: (value) =>
                onChanged(settings.copyWith(whatsappEnabled: value)),
          ),
          _SwitchRow(
            title: 'رسائل SMS',
            value: settings.smsEnabled,
            onChanged: (value) =>
                onChanged(settings.copyWith(smsEnabled: value)),
          ),
          _SwitchRow(
            title: 'البريد الإلكتروني',
            value: settings.emailEnabled,
            onChanged: (value) =>
                onChanged(settings.copyWith(emailEnabled: value)),
          ),
        ],
      ),
    );
  }
}

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: AppTheme.muted,
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
    return AarastCard(
      color: AppTheme.ivory,
      border: Border.all(color: AppTheme.goldSoft.withAlpha(80)),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(LucideIcons.languages, size: 16, color: AppTheme.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'لغة التطبيق: العربية · آخر حفظ: '
              '${formatArabicCompactDate(updatedAt)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppTheme.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: AppTheme.burgundy,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ],
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader({
    required this.icon,
    required this.title,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: compact
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.burgundy, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppTheme.burgundyDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
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

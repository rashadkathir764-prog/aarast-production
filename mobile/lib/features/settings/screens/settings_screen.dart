import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/providers/auth_controller.dart';
import '../models/user_settings.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SettingsProvider>().loadSettings();
    });
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
        onRefresh: provider.loadSettings,
        child: ListView(
          children: [
            _AccountCard(
              name: auth.user?.name ?? 'مستخدم اعّرست',
              phone: auth.user?.phone,
              email: auth.user?.email,
            ),
            const SizedBox(height: 14),
            if (provider.isLoading && draft == null)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (provider.errorMessage != null && draft == null)
              AarastEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'تعذر تحميل الإعدادات',
                message: provider.errorMessage!,
                action: OutlinedButton.icon(
                  onPressed: provider.loadSettings,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('إعادة المحاولة'),
                ),
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
              FilledButton.icon(
                onPressed: provider.isSubmitting || !provider.hasChanges
                    ? null
                    : provider.saveSettings,
                icon: provider.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: const Text('حفظ الإعدادات'),
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
    return AarastCard(
      color: AppTheme.ivory,
      border: Border.all(color: AppTheme.goldSoft.withAlpha(80)),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.ivory,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: AppTheme.gold,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  phone?.trim().isNotEmpty == true
                      ? phone!.trim()
                      : email?.trim().isNotEmpty == true
                      ? email!.trim()
                      : 'حساب اعّرست',
                  textDirection: phone?.trim().isNotEmpty == true
                      ? TextDirection.ltr
                      : TextDirection.rtl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
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
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const _SettingsHeader(
            icon: Icons.notifications_active_outlined,
            title: 'تفضيلات التنبيهات',
          ),
          _SwitchRow(
            title: 'تنبيهات داخل التطبيق',
            subtitle: 'إظهار التنبيهات المهمة في اعّرست',
            value: settings.pushEnabled,
            onChanged: (value) =>
                onChanged(settings.copyWith(pushEnabled: value)),
          ),
          _SwitchRow(
            title: 'تذكير المهام',
            subtitle: 'المهام القريبة والمتأخرة',
            value: settings.taskRemindersEnabled,
            onChanged: (value) =>
                onChanged(settings.copyWith(taskRemindersEnabled: value)),
          ),
          _SwitchRow(
            title: 'تذكير الأقساط',
            subtitle: 'الأقساط القريبة والمتأخرة',
            value: settings.paymentRemindersEnabled,
            onChanged: (value) =>
                onChanged(settings.copyWith(paymentRemindersEnabled: value)),
          ),
          _SwitchRow(
            title: 'رسائل الموردين',
            subtitle: 'تحديثات عروض الأسعار والموردين',
            value: settings.providerMessagesEnabled,
            onChanged: (value) =>
                onChanged(settings.copyWith(providerMessagesEnabled: value)),
          ),
          _SwitchRow(
            title: 'واتساب',
            subtitle: 'تفضيل استقبال إشعارات عبر واتساب عند توفر القناة',
            value: settings.whatsappEnabled,
            onChanged: (value) =>
                onChanged(settings.copyWith(whatsappEnabled: value)),
          ),
          _SwitchRow(
            title: 'رسائل SMS',
            subtitle: 'تفضيل استقبال رسائل قصيرة عند توفر القناة',
            value: settings.smsEnabled,
            onChanged: (value) =>
                onChanged(settings.copyWith(smsEnabled: value)),
          ),
          _SwitchRow(
            title: 'البريد الإلكتروني',
            subtitle: 'تفضيل استقبال رسائل بريدية عند توفر البريد',
            value: settings.emailEnabled,
            onChanged: (value) =>
                onChanged(settings.copyWith(emailEnabled: value)),
            isLast: true,
          ),
        ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SettingsHeader(
            icon: Icons.language_outlined,
            title: 'العرض والخصوصية',
            compact: true,
          ),
          const SizedBox(height: 10),
          const Text(
            'اللغة الحالية: العربية',
            style: TextStyle(color: AppTheme.ink, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'آخر حفظ: ${updatedAt.day}/${updatedAt.month}/${updatedAt.year}',
            style: const TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
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
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.isLast = false,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AppTheme.burgundySoft.withAlpha(150))),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: AppTheme.burgundy,
        title: Text(
          title,
          style: const TextStyle(
            color: AppTheme.ink,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.muted,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
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
          Icon(icon, color: AppTheme.burgundy),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: AppTheme.burgundyDeep,
                fontWeight: FontWeight.w900,
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

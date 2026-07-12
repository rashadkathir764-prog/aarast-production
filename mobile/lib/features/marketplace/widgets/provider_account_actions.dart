import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';

class ProviderAccountActions extends StatefulWidget {
  const ProviderAccountActions({
    required this.onOpenSettings,
    required this.onSync,
    required this.onLogout,
    super.key,
  });

  final VoidCallback onOpenSettings;
  final Future<void> Function() onSync;
  final Future<void> Function() onLogout;

  @override
  State<ProviderAccountActions> createState() => _ProviderAccountActionsState();
}

class _ProviderAccountActionsState extends State<ProviderAccountActions> {
  bool _isSyncing = false;
  bool _isLoggingOut = false;
  String? _statusMessage;
  bool _statusIsError = false;

  bool get _isBusy => _isSyncing || _isLoggingOut;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AarastSectionHeader(
          title: 'الحساب والتطبيق',
          subtitle: 'إعدادات حسابك وتحديث بيانات لوحة المزوّد بأمان.',
          icon: LucideIcons.settings,
        ),
        const SizedBox(height: 12),
        AarastCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ProviderAccountTile(
                key: const Key('provider-settings-action'),
                title: 'الإعدادات',
                subtitle: 'الإشعارات واللغة وتفضيلات الحساب',
                icon: LucideIcons.settings,
                onTap: _isBusy ? null : widget.onOpenSettings,
              ),
              const Divider(height: 1),
              _ProviderAccountTile(
                key: const Key('provider-sync-action'),
                title: _isSyncing ? 'جارٍ التحديث...' : 'مزامنة الآن',
                subtitle: 'تحديث الملف والخدمات والطلبات والمحادثات',
                icon: LucideIcons.refreshCw,
                trailing: _isSyncing
                    ? const AarastInlineSpinner(dimension: 20)
                    : null,
                onTap: _isBusy ? null : _sync,
              ),
              const Divider(height: 1),
              _ProviderAccountTile(
                key: const Key('provider-logout-action'),
                title: _isLoggingOut ? 'جارٍ تسجيل الخروج...' : 'تسجيل الخروج',
                subtitle: 'إنهاء جلسة حساب المزوّد على هذا الجهاز',
                icon: LucideIcons.logOut,
                color: AppTheme.danger,
                trailing: _isLoggingOut
                    ? const AarastInlineSpinner(dimension: 20)
                    : null,
                onTap: _isBusy ? null : _confirmLogout,
              ),
            ],
          ),
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 10),
          Semantics(
            liveRegion: true,
            child: Text(
              _statusMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _statusIsError ? AppTheme.danger : AppTheme.success,
                fontWeight: FontWeight.w800,
                height: 1.45,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _sync() async {
    if (_isBusy) return;
    setState(() {
      _isSyncing = true;
      _statusMessage = null;
      _statusIsError = false;
    });
    try {
      await widget.onSync();
      if (!mounted) return;
      setState(() => _statusMessage = 'تم تحديث بيانات لوحة المزوّد.');
    } on Object {
      if (!mounted) return;
      setState(() {
        _statusIsError = true;
        _statusMessage =
            'تعذّر تحديث بيانات المزوّد. تحقق من الاتصال وحاول مجدداً.';
      });
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _confirmLogout() async {
    if (_isBusy) return;
    final confirmed = await showAarastBottomSheet<bool>(
      context: context,
      builder: (sheetContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  LucideIcons.logOut,
                  size: 34,
                  color: AppTheme.danger,
                ),
                const SizedBox(height: 14),
                Text(
                  'الخروج من حساب المزوّد؟',
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'ستحتاج إلى تسجيل الدخول مجدداً للوصول إلى لوحة المزوّد.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const Key('provider-logout-cancel'),
                        onPressed: () => Navigator.pop(sheetContext, false),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        key: const Key('provider-logout-confirm'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.danger,
                        ),
                        onPressed: () => Navigator.pop(sheetContext, true),
                        icon: const Icon(LucideIcons.logOut),
                        label: const Text('تسجيل الخروج'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _isLoggingOut = true;
      _statusMessage = null;
      _statusIsError = false;
    });
    try {
      await widget.onLogout();
    } on Object {
      if (!mounted) return;
      setState(() {
        _statusIsError = true;
        _statusMessage = 'تعذّر تسجيل الخروج. حاول مرة أخرى.';
      });
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }
}

class _ProviderAccountTile extends StatelessWidget {
  const _ProviderAccountTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.color = AppTheme.burgundy,
    this.trailing,
    super.key,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  final Color color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      leading: Icon(icon, color: color),
      title: Text(
        title,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: AppTheme.muted,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing:
          trailing ??
          const Icon(LucideIcons.chevronLeft, color: AppTheme.muted),
      enabled: onTap != null,
      onTap: onTap,
    );
  }
}

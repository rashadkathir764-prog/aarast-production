import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/diagnostics/app_logger.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/account_context.dart';
import '../providers/account_context_controller.dart';

class AccountContextSelectionScreen extends StatefulWidget {
  const AccountContextSelectionScreen({super.key});

  @override
  State<AccountContextSelectionScreen> createState() =>
      _AccountContextSelectionScreenState();
}

class _AccountContextSelectionScreenState
    extends State<AccountContextSelectionScreen> {
  bool _shownEventRecorded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shownEventRecorded) return;
    _shownEventRecorded = true;
    final controller = context.read<AccountContextController>();
    appLogEvent(
      'ROLE_CHOOSER_SHOWN',
      category: AppLogCategory.context,
      source: 'AccountContextSelectionScreen',
      reason: 'active_context_required',
      attributes: {
        'availableContextCount': controller.availableContexts.length,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AccountContextController>();
    final paths = controller.availableContexts;

    return AarastScaffold(
      key: const ValueKey('account-context-selection-screen'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
        children: [
          const Icon(LucideIcons.layers, color: AppTheme.burgundy, size: 42),
          const SizedBox(height: 16),
          Text(
            'اختر المسار',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'اختر المساحة التي تريد فتحها الآن. لن نطلب تسجيل الدخول أو رمز تحقق مرة أخرى.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          for (final path in paths) ...[
            _AccountPathCard(
              path: path,
              enabled: !controller.isSelecting,
              onTap: () => controller.select(path.contextKey),
            ),
            const SizedBox(height: 12),
          ],
          if (controller.errorMessage != null) ...[
            const SizedBox(height: 4),
            AarastErrorState(
              title: 'تعذر فتح المسار',
              message: controller.errorMessage!,
              onRetry: controller.refresh,
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountPathCard extends StatelessWidget {
  const _AccountPathCard({
    required this.path,
    required this.enabled,
    required this.onTap,
  });

  final AccountContext path;
  final bool enabled;
  final Future<bool> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final role = _roleLabel(path.role);
    return AarastCard(
      key: ValueKey('account-path-option-${path.contextKey}'),
      onTap: enabled ? () => onTap() : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.burgundySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _roleIcon(path.role),
              color: AppTheme.burgundy,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  role,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.burgundy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  path.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (enabled)
            const Icon(LucideIcons.chevronLeft, color: AppTheme.muted, size: 20)
          else
            const AarastInlineSpinner(dimension: 20, color: AppTheme.burgundy),
        ],
      ),
    );
  }
}

String _roleLabel(AccountContextRole role) {
  return switch (role) {
    AccountContextRole.owner => 'عريس',
    AccountContextRole.contributor => 'مساهم',
    AccountContextRole.provider => 'مزود',
  };
}

IconData _roleIcon(AccountContextRole role) {
  return switch (role) {
    AccountContextRole.owner => LucideIcons.heartHandshake,
    AccountContextRole.contributor => LucideIcons.users,
    AccountContextRole.provider => LucideIcons.store,
  };
}

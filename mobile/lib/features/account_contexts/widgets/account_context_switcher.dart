import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/account_context.dart';
import '../providers/account_context_controller.dart';

class AccountContextSwitcher extends StatelessWidget {
  const AccountContextSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AccountContextController?>();
    if (controller == null) return const SizedBox.shrink();
    final selected = controller.selectedContext;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Semantics(
        button: true,
        label: selected == null
            ? 'اختيار مساحة الحساب'
            : 'مساحة الحساب الحالية: ${_contextLabel(selected)}',
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            key: const ValueKey('account-context-switcher'),
            borderRadius: BorderRadius.circular(16),
            onTap: controller.isSelecting
                ? null
                : () => _showContextSheet(context, controller),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.layers,
                      color: AppTheme.burgundy,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        selected == null
                            ? 'اختر مساحة الحساب'
                            : _contextLabel(selected),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppTheme.ink,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      LucideIcons.chevronsUpDown,
                      color: AppTheme.muted,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showContextSheet(
    BuildContext context,
    AccountContextController controller,
  ) async {
    await showAarastBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SafeArea(
          child: Material(
            color: AppTheme.ivory,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(24),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 520),
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                children: [
                  Text(
                    'مساحات الحساب',
                    textAlign: TextAlign.center,
                    style: Theme.of(sheetContext).textTheme.titleMedium
                        ?.copyWith(
                          color: AppTheme.ink,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 8),
                  for (final item in controller.contexts)
                    _ContextOption(
                      context: item,
                      selected: item.contextKey ==
                          controller.selectedContext?.contextKey,
                      onTap: () async {
                        final opened = item.isAvailable
                            ? await controller.select(item.contextKey)
                            : await controller.openReadOnlyContext(
                                item.contextKey,
                              );
                        if (opened && sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ContextOption extends StatelessWidget {
  const _ContextOption({
    required this.context,
    required this.selected,
    required this.onTap,
  });

  final AccountContext context;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext buildContext) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Material(
        color: selected ? AppTheme.burgundySoft : Colors.white,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey('account-context-option-${context.contextKey}'),
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    _iconFor(context),
                    color: selected ? AppTheme.burgundy : AppTheme.muted,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _contextLabel(context),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(buildContext).textTheme.bodyMedium
                          ?.copyWith(
                            color: AppTheme.ink,
                            fontWeight: FontWeight.w800,
                            height: 1.3,
                          ),
                    ),
                  ),
                  if (context.lifecycle == 'ARCHIVED')
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: Text(
                        'قراءة فقط',
                        style: TextStyle(
                          color: AppTheme.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  if (selected)
                    const Icon(
                      LucideIcons.check,
                      color: AppTheme.burgundy,
                      size: 18,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _contextLabel(AccountContext context) {
  final prefix = switch (context.role) {
    AccountContextRole.owner => 'مالك',
    AccountContextRole.contributor => 'مساهم',
    AccountContextRole.provider => 'مزود',
  };
  return '$prefix: ${context.displayName}';
}

IconData _iconFor(AccountContext context) {
  return switch (context.role) {
    AccountContextRole.owner => LucideIcons.heartHandshake,
    AccountContextRole.contributor => LucideIcons.users,
    AccountContextRole.provider => LucideIcons.store,
  };
}

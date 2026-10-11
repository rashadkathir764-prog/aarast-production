import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import 'contributor_workspace_view.dart' show ContributorWorkspaceColors;

/// Shows what the plan owner allowed this contributor to do. The sheet takes
/// the height it needs and scrolls, so every right and the close action stay
/// reachable on short screens and with large text.
Future<void> showContributorPermissionsSheet(
  BuildContext context, {
  required List<String> labels,
}) {
  return showAarastBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: ContributorWorkspaceColors.surface,
    builder: (sheetContext) => ContributorPermissionsSheet(
      labels: labels,
      onDone: () => Navigator.of(sheetContext).pop(),
    ),
  );
}

class ContributorPermissionsSheet extends StatelessWidget {
  const ContributorPermissionsSheet({
    required this.labels,
    required this.onDone,
    super.key,
  });

  final List<String> labels;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ContributorWorkspaceColors.border,
                    borderRadius: BorderRadius.circular(AppTheme.radiusPill),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Icon(
                LucideIcons.shieldCheck,
                color: ContributorWorkspaceColors.warning,
                size: 34,
              ),
              const SizedBox(height: 10),
              Text(
                'صلاحياتك في هذه الخطة',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: ContributorWorkspaceColors.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'حدد مالك الخطة هذه الصلاحيات، وتظهر لك الواجهة على أساسها.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: ContributorWorkspaceColors.muted,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              for (final label in labels)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: ContributorWorkspaceColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: ContributorWorkspaceColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          LucideIcons.checkCircle2,
                          color: AppTheme.success,
                          size: 19,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            label,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: ContributorWorkspaceColors.ink,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              FilledButton(onPressed: onDone, child: const Text('تم')),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../data/local_plan_migration.dart';

/// Shown right after login when a complete guest plan exists on the device.
///
/// Trust rules:
/// - Local data is deleted ONLY after the server confirms the import.
/// - Discarding is explicit and double-confirmed.
class LocalPlanMigrationScreen extends StatefulWidget {
  const LocalPlanMigrationScreen({
    super.key,
    required this.snapshot,
    required this.migrationService,
    required this.onFinished,
    this.autoSave = false,
  });

  final LocalPlanSnapshot snapshot;
  final LocalPlanMigrationService migrationService;
  final VoidCallback onFinished;

  /// The account was just created to save this plan (a08b), so it is saved
  /// at once; the choice shows only if saving fails.
  final bool autoSave;

  @override
  State<LocalPlanMigrationScreen> createState() =>
      _LocalPlanMigrationScreenState();
}

class _LocalPlanMigrationScreenState extends State<LocalPlanMigrationScreen> {
  bool _isUploading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    if (widget.autoSave) {
      _isUploading = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _migrate();
      });
    }
  }

  Future<void> _migrate() async {
    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      final response = await widget.migrationService.migrate(widget.snapshot);
      if (!mounted) return;

      // Server confirmed — only now is it safe to clear local guest data.
      AuthStorage? authStorage;
      OfflineSyncService? offlineSync;
      try {
        authStorage = context.read<AuthStorage>();
      } on ProviderNotFoundException {
        authStorage = null;
      }
      try {
        offlineSync = context.read<OfflineSyncService>();
      } on ProviderNotFoundException {
        offlineSync = null;
      }

      await authStorage?.saveActivePlanId(response.activePlanId);
      await widget.migrationService.guestStorage.clearDraft();
      final guestPlanId = widget.snapshot.draft.guestPlanId;
      if (guestPlanId != null && guestPlanId.trim().isNotEmpty) {
        await offlineSync?.database.deletePlanGraph(guestPlanId);
        await offlineSync?.refreshStatus();
      }

      if (!mounted) return;
      widget.onFinished();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isUploading = false;
        _errorMessage = 'تعذر رفع الخطة الآن. تحقق من الاتصال وحاول مرة أخرى.';
      });
    }
  }

  Future<void> _confirmDiscard() async {
    final confirmed = await showAarastBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'تجاهل الخطة المحلية نهائياً؟',
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'سيتم حذف الخطة المحفوظة على هذا الجهاز ولن تتمكن من استعادتها لاحقاً.',
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                AarastButton(
                  label: 'احتفظ بالخطة',
                  onPressed: () => Navigator.of(sheetContext).pop(false),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(true),
                  child: const Text(
                    'نعم، تجاهلها نهائياً',
                    style: TextStyle(
                      color: AppTheme.danger,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;
    OfflineSyncService? offlineSync;
    try {
      offlineSync = context.read<OfflineSyncService>();
    } on ProviderNotFoundException {
      offlineSync = null;
    }
    final guestPlanId = widget.snapshot.draft.guestPlanId;
    await widget.migrationService.guestStorage.clearDraft();
    if (guestPlanId != null && guestPlanId.trim().isNotEmpty) {
      await offlineSync?.database.deletePlanGraph(guestPlanId);
      await offlineSync?.refreshStatus();
    }
    if (!mounted) return;
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.snapshot.draft;
    final theme = Theme.of(context);

    if (widget.autoSave && _isUploading && _errorMessage == null) {
      return AarastScreenFrame(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AarastInlineSpinner(dimension: 40),
              const SizedBox(height: 16),
              Text(
                'نحفظ ${draft.planName ?? 'خطتك'} في حسابك',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      );
    }

    return AarastScreenFrame(
      maxWidth: 600,
      safeAreaBottom: true,
      child: ColoredBox(
        color: AppTheme.canvas,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AarastCard(
                  padding: const EdgeInsets.all(20),
                  color: AppTheme.canvas,
                  border: Border.all(
                    color: AppTheme.focus.withValues(alpha: 0.28),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: AppTheme.brandMuted,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusLg,
                          ),
                          border: Border.all(
                            color: AppTheme.focus.withValues(alpha: 0.32),
                          ),
                        ),
                        child: const Icon(
                          LucideIcons.uploadCloud,
                          color: AppTheme.brand,
                          size: 28,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'وجدنا خطتك المحفوظة على هذا الجهاز',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ارفعها إلى حسابك حتى تبقى محفوظة وتقدر تشاركها مع عائلتك من أي جهاز.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                          height: 1.55,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                AarastCard(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        draft.planName ?? 'خطة زفافي',
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _CountChip(
                            icon: LucideIcons.wallet,
                            label: 'المصاريف',
                            count: widget.snapshot.costs.length,
                          ),
                          _CountChip(
                            icon: LucideIcons.listChecks,
                            label: 'المهام',
                            count: widget.snapshot.tasks.length,
                          ),
                          _CountChip(
                            icon: LucideIcons.users,
                            label: 'الضيوف',
                            count: widget.snapshot.guests.length,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.dangerSoft,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.danger.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.danger,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                AarastButton(
                  label: 'رفع الخطة إلى حسابي',
                  icon: LucideIcons.uploadCloud,
                  isLoading: _isUploading,
                  onPressed: _isUploading ? null : _migrate,
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: _isUploading ? null : _confirmDiscard,
                  child: Text(
                    'تجاهل الخطة المحلية',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      LucideIcons.lock,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'لن تُحذف بياناتك من الجهاز حتى يكتمل الرفع بنجاح.',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
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
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({
    required this.icon,
    required this.label,
    required this.count,
  });

  final IconData icon;
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.brandMuted,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.focus.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.brand),
          const SizedBox(width: 6),
          Text(
            '$label: $count',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

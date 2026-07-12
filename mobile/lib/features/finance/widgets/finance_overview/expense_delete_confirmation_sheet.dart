import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/aarast_ui.dart';
import '../../models/expense.dart';

Future<bool?> showExpenseDeleteConfirmation({
  required BuildContext context,
  required Expense expense,
}) {
  return showAarastBottomSheet<bool>(
    context: context,
    builder: (sheetContext) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _SheetHandle(),
                const SizedBox(height: 20),
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: AppTheme.dangerSoft,
                    borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  ),
                  child: const Icon(
                    LucideIcons.trash2,
                    color: AppTheme.danger,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'حذف المصروف؟',
                  style: Theme.of(sheetContext).textTheme.titleLarge?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'سيتم حذف "${expense.title}" من المصاريف. لا يمكن التراجع عن هذا الإجراء.',
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(false),
                        child: const Text('إلغاء'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => Navigator.of(sheetContext).pop(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.danger,
                        ),
                        icon: const Icon(LucideIcons.trash2),
                        label: const Text('حذف'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 5,
        decoration: BoxDecoration(
          color: AppTheme.border,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

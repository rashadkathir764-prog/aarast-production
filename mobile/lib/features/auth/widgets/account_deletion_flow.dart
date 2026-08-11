import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';

/// The shared typed confirmation for account deletion.
Future<bool> confirmAccountDeletion(
  BuildContext context, {
  required String keyPrefix,
}) async {
  var confirmationText = '';
  return await showAarastBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) => Directionality(
            textDirection: TextDirection.rtl,
            child: SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  18,
                  20,
                  20 + MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      LucideIcons.trash2,
                      size: 36,
                      color: AppTheme.danger,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'حذف حسابك نهائيًا؟',
                      textAlign: TextAlign.center,
                      style: Theme.of(sheetContext).textTheme.titleLarge
                          ?.copyWith(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'سيُحذف الحساب وبياناته المرتبطة نهائياً. لا يمكن التراجع بعد الحذف.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: Key('$keyPrefix-delete-account-input'),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'اكتب «حذف» للتأكيد',
                      ),
                      onChanged: (value) =>
                          setSheetState(() => confirmationText = value),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(sheetContext, false),
                            child: const Text('إلغاء'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: FilledButton.icon(
                            key: Key('$keyPrefix-delete-account-confirm'),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.danger,
                            ),
                            onPressed: confirmationText.trim() == 'حذف'
                                ? () => Navigator.pop(sheetContext, true)
                                : null,
                            icon: const Icon(LucideIcons.trash2),
                            label: const Text('حذف نهائي'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ) ==
      true;
}

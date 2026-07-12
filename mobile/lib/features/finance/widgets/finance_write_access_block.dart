import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/widgets/aarast_ui.dart';
import '../providers/finance_provider.dart';
import '../../auth/utils/auth_action_guard.dart';

Widget? financeWriteAccessBlock({
  required BuildContext context,
  required FinanceProvider provider,
  required String weddingPlanId,
}) {
  if (AuthActionGuard.isLocalGuestPlanId(weddingPlanId)) return null;
  if (provider.loadedWeddingPlanId != weddingPlanId || provider.isLoading) {
    return const AarastScreenLoading(
      label: 'جاري التحقق من صلاحية تعديل المال',
    );
  }
  if (provider.errorMessage != null && !provider.access.hasAnyFinanceAccess) {
    return AarastScreenFrame(
      maxWidth: 520,
      child: Center(
        child: AarastErrorState(
          title: 'تعذر التحقق من الصلاحيات',
          message: provider.errorMessage!,
          onRetry: () => provider.loadFinance(weddingPlanId),
        ),
      ),
    );
  }
  if (!provider.canManageFinancialRecords) {
    return const AarastScreenFrame(
      maxWidth: 520,
      child: Center(
        child: AarastEmptyState(
          title: 'العرض فقط',
          message: 'لا تملك صلاحية تعديل السجلات المالية لهذه الخطة.',
          icon: LucideIcons.lock,
        ),
      ),
    );
  }
  return null;
}

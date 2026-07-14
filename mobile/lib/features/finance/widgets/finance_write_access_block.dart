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
  if (provider.loadedPlanId != weddingPlanId || provider.isLoading) {
    return const AarastScreenLoading(
      label: 'جاري التحقق من صلاحية تعديل المال',
    );
  }
  if (!provider.hasLoadedMoney) {
    final error = provider.errorMessage;
    if (error == null) {
      return const AarastScreenLoading(
        label: 'جاري التحقق من صلاحية تعديل المال',
      );
    }
    return AarastScreenFrame(
      maxWidth: 520,
      child: Center(
        child: AarastErrorState(
          title: 'تعذر التحقق من الصلاحيات',
          message: error,
          onRetry: () => provider.loadMoney(weddingPlanId),
        ),
      ),
    );
  }
  if (!provider.canManageMoney) {
    return const AarastScreenFrame(
      maxWidth: 520,
      child: Center(
        child: AarastEmptyState(
          title: 'العرض فقط',
          message: 'لا تملك صلاحية إدارة المال في هذه الخطة.',
          icon: LucideIcons.lock,
        ),
      ),
    );
  }
  return null;
}

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/widgets/aarast_ui.dart';
import '../providers/finance_provider.dart';
import '../../auth/auth_api.dart' show AuthActionGuard;

Widget? financeWriteAccessBlock({
  required BuildContext context,
  required FinanceProvider provider,
  required String weddingPlanId,
  bool ownerOnly = false,
}) {
  if (AuthActionGuard.isLocalGuestPlanId(weddingPlanId)) return null;
  if (provider.loadedPlanId != weddingPlanId || provider.isLoading) {
    return const AarastScreenLoading(label: 'نتأكد من صلاحيتك في المال');
  }
  if (!provider.hasLoadedMoney) {
    final error = provider.loadErrorMessage;
    if (error == null) {
      return const AarastScreenLoading(label: 'نتأكد من صلاحيتك في المال');
    }
    return AarastScreenFrame(
      maxWidth: 520,
      child: Center(
        child: AarastErrorState(
          title: 'ما قدرنا نتأكد من صلاحيتك',
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
          title: 'للقراءة بس',
          message: 'ما عندك صلاحية تعدّل المال في هذي الخطة.',
          icon: LucideIcons.lock,
        ),
      ),
    );
  }
  if (ownerOnly && !provider.canManageBudget) {
    return const AarastScreenFrame(
      maxWidth: 520,
      child: Center(
        child: AarastEmptyState(
          title: 'لصاحب الخطة',
          message: 'الميزانية والبنود يعدّلها صاحب الخطة.',
          icon: LucideIcons.lock,
        ),
      ),
    );
  }
  return null;
}

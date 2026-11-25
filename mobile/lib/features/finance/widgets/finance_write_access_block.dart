import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
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
    // p16: the page was a dead end that named no one. It says who edits
    // and leads back to the money he reads; the owner reading a memory is
    // told why instead (D112, Q-21).
    final owner = context.planWord('العريس', 'العروسة');
    return _ReadOnlyMoney(
      weddingPlanId: weddingPlanId,
      message: provider.ownerReadsOnly
          ? 'الخطة في الذكريات، ومالها للقراءة بس.'
          : context.say(
              'تقدر تشوف المال بس، والتعديل عند $owner.',
              'تقدرين تشوفين المال بس، والتعديل عند $owner.',
            ),
    );
  }
  if (ownerOnly && !provider.canManageBudget) {
    return const AarastScreenFrame(
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

/// «للقراءة بس» with the way back to the money, inside the page's margins
/// (the card touched the screen's edges).
class _ReadOnlyMoney extends StatelessWidget {
  const _ReadOnlyMoney({required this.weddingPlanId, required this.message});

  final String weddingPlanId;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AarastScreenFrame(
      child: Center(
        child: SingleChildScrollView(
          padding: AarastV3Density.pageInsets,
          child: AarastEmptyState(
            key: const ValueKey('money-read-only'),
            title: 'للقراءة بس',
            message: message,
            icon: LucideIcons.lock,
            action: JourneyButton(
              key: const ValueKey('money-read-only-back'),
              label: context.say('ارجع للمال', 'ارجعي للمال'),
              icon: LucideIcons.wallet,
              onPressed: () => context.go(AppRouter.money(weddingPlanId)),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/widgets/aarast_ui.dart';
import '../../auth/providers/auth_controller.dart';
import '../models/account_context.dart';
import '../providers/account_context_controller.dart';

class WeddingPlanContextGate extends StatefulWidget {
  const WeddingPlanContextGate({
    required this.weddingPlanId,
    required this.child,
    super.key,
  });

  final String weddingPlanId;
  final Widget child;

  @override
  State<WeddingPlanContextGate> createState() =>
      _WeddingPlanContextGateState();
}

class _WeddingPlanContextGateState extends State<WeddingPlanContextGate> {
  String? _openingContextKey;
  String? _failedContextKey;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AccountContextController?>();
    // The production account subtree always provides this controller. Keeping
    // the null branch makes isolated public previews and legacy route tests
    // render without inventing client-side authority.
    if (controller == null) return widget.child;
    final auth = context.watch<AuthController?>();
    if (auth != null && auth.status == AuthStatus.checking) {
      return const AarastScaffold(child: AarastScreenLoading());
    }
    if (auth != null && auth.status == AuthStatus.unauthenticated) {
      return _LoginRequiredPlanContext(planId: widget.weddingPlanId);
    }
    final selected = controller.selectedContext;
    if (selected?.isPlan == true &&
        selected?.weddingPlanId == widget.weddingPlanId) {
      return widget.child;
    }

    final target = _contextForPlan(
      controller.contexts,
      widget.weddingPlanId,
    );
    if (target != null &&
        _openingContextKey != target.contextKey &&
        _failedContextKey != target.contextKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _openContext(controller, target);
      });
    }

    if (controller.isRefreshing ||
        controller.isSelecting ||
        _openingContextKey != null ||
        target != null && _failedContextKey != target.contextKey) {
      return const AarastScaffold(child: AarastScreenLoading());
    }

    return const _UnavailablePlanContext();
  }

  Future<void> _openContext(
    AccountContextController controller,
    AccountContext target,
  ) async {
    if (_openingContextKey == target.contextKey) return;
    setState(() => _openingContextKey = target.contextKey);

    final opened = target.isAvailable
        ? await controller.select(target.contextKey)
        : await controller.openReadOnlyContext(target.contextKey);
    if (!mounted) return;
    setState(() {
      _openingContextKey = null;
      _failedContextKey = opened ? null : target.contextKey;
    });
  }
}

class _LoginRequiredPlanContext extends StatelessWidget {
  const _LoginRequiredPlanContext({required this.planId});

  final String planId;

  @override
  Widget build(BuildContext context) {
    return AarastScaffold(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: AarastEmptyState(
                key: const ValueKey('wedding-plan-context-login'),
                icon: LucideIcons.lock,
                title: 'تسجيل الدخول مطلوب',
                message:
                    'سجّل الدخول للتحقق من مساحة خطة الزفاف قبل فتح هذا المسار.',
                action: AarastButton(
                  label: 'تسجيل الدخول',
                  icon: LucideIcons.logIn,
                  onPressed: () {
                    final resume = '/wedding-plans/$planId/dashboard';
                    context.go(
                      Uri(
                        path: '/login',
                        queryParameters: {'resume': resume},
                      ).toString(),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UnavailablePlanContext extends StatelessWidget {
  const _UnavailablePlanContext();

  @override
  Widget build(BuildContext context) {
    return AarastScaffold(
      child: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: const AarastEmptyState(
                key: ValueKey('wedding-plan-context-unavailable'),
                icon: LucideIcons.shieldAlert,
                title: 'مساحة الخطة غير متاحة',
                message:
                    'لم تعد هذه الخطة ضمن مساحات حسابك المتاحة. ارجع للرئيسية واختر مساحة أخرى.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

AccountContext? _contextForPlan(
  List<AccountContext> contexts,
  String weddingPlanId,
) {
  for (final context in contexts) {
    if (context.isPlan && context.weddingPlanId == weddingPlanId) {
      return context;
    }
  }
  return null;
}

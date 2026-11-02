import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_ui.dart'
    show AarastInlineSpinner, AarastScreenFrame;
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;
import '../../auth/auth_api.dart' show AuthController, AuthStatus;

class ProviderAuthGate extends StatelessWidget {
  const ProviderAuthGate({
    required this.child,
    required this.resumeLocation,
    this.embedded = false,
    this.registerAsProvider = false,
    this.providerAccountRequired = false,
    this.providerProfileManageRequired = false,
    this.providerOperationsRequired = false,
    super.key,
  });

  static const message = 'ادخل بحسابك عشان ترسل طلب عرض وتتابع الردود.';

  final Widget child;
  final String resumeLocation;
  final bool embedded;
  final bool registerAsProvider;
  final bool providerAccountRequired;
  final bool providerProfileManageRequired;
  final bool providerOperationsRequired;

  @override
  Widget build(BuildContext context) {
    if (AppFeatureFlags.devBypassLoginGatesForUxExploration) {
      return child;
    }

    final auth = context.watch<AuthController>();
    if (auth.status == AuthStatus.checking) {
      return AarastScreenFrame(
        maxWidth: 520,
        backgroundColor: AarastV3Color.canvas,
        child: Center(
          child: AarastInlineSpinner(
            dimension: 28,
            color: context.accent.primary,
          ),
        ),
      );
    }
    if (auth.status == AuthStatus.authenticated) {
      if (!providerAccountRequired &&
          !providerProfileManageRequired &&
          !providerOperationsRequired) {
        return child;
      }
      final selectedContext = context
          .watch<AccountContextController?>()
          ?.selectedContext;
      final isProviderContext =
          selectedContext?.isProvider == true &&
          selectedContext?.isAvailable == true;
      final canManageProfile =
          selectedContext?.capabilities.canManageProviderProfile == true;
      final canOperate =
          selectedContext?.capabilities.canUseProviderOperations == true;
      if (isProviderContext &&
          (!providerAccountRequired || isProviderContext) &&
          (!providerProfileManageRequired || canManageProfile) &&
          (!providerOperationsRequired || canOperate)) {
        return child;
      }
      return _ProviderAccountRequiredGate(
        embedded: embedded,
        hasProviderContext: isProviderContext,
      );
    }

    return _GateCard(
      key: const Key('provider-auth-gate'),
      embedded: embedded,
      icon: LucideIcons.lock,
      title: 'ادخل أول',
      message: message,
      actions: [
        JourneyButton(
          key: const Key('provider-auth-gate-login'),
          label: 'تسجيل الدخول',
          background: context.accent.primary,
          expand: true,
          large: true,
          onPressed: () =>
              context.go(_withResume(AppRouter.login, resumeLocation)),
        ),
        const SizedBox(height: 8),
        JourneyButton.quiet(
          key: const Key('provider-auth-gate-register'),
          label: registerAsProvider ? 'أنشئ حساب مزود' : 'أنشئ حساب',
          expand: true,
          onPressed: () => context.go(
            _withResume(
              registerAsProvider
                  ? '${AppRouter.register}?type=provider'
                  : AppRouter.register,
              resumeLocation,
            ),
          ),
        ),
      ],
    );
  }

  static String _withResume(String location, String resumeLocation) {
    final uri = Uri.parse(location);
    final query = {...uri.queryParameters, 'resume': resumeLocation};
    return uri.replace(queryParameters: query).toString();
  }
}

class _ProviderAccountRequiredGate extends StatelessWidget {
  const _ProviderAccountRequiredGate({
    required this.embedded,
    required this.hasProviderContext,
  });

  final bool embedded;
  final bool hasProviderContext;

  @override
  Widget build(BuildContext context) {
    return _GateCard(
      key: const Key('provider-account-required-gate'),
      embedded: embedded,
      icon: LucideIcons.store,
      title: hasProviderContext ? 'هذا مو متاح الآن' : 'هذا للمزودين بس',
      message: hasProviderContext
          ? 'حالة حساب المزود ما تسمح بهذا. راجع الحالة أو جرّب بعدين.'
          : 'حسابك حساب تخطيط عرس. ارجع لخطتك، أو قدّم طلب انضمام كمزود.',
      actions: [
        JourneyButton(
          key: const Key('provider-account-required-apply'),
          label: 'قدّم طلب مزود',
          background: context.accent.primary,
          expand: true,
          large: true,
          onPressed: () => context.go(AppRouter.providerApply),
        ),
        const SizedBox(height: 8),
        JourneyButton.quiet(
          key: const Key('provider-account-required-home'),
          label: 'ارجع لخطتي',
          expand: true,
          onPressed: () => context.go(AppRouter.home),
        ),
      ],
    );
  }
}

/// A gate on the canvas: the icon, why, and what to do (journey kit).
class _GateCard extends StatelessWidget {
  const _GateCard({
    required this.embedded,
    required this.icon,
    required this.title,
    required this.message,
    required this.actions,
    super.key,
  });

  final bool embedded;
  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      safeAreaBottom: !embedded,
      child: ListView(
        padding: EdgeInsets.fromLTRB(16, 24, 16, embedded ? 120 : 32),
        children: [
          JourneyBox(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: JourneyIconTile(
                    icon: icon,
                    color: context.accent.primary,
                    soft: context.accent.primarySoft,
                    size: 56,
                    radius: 20,
                  ),
                ),
                const SizedBox(height: 16),
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    style: JourneyType.of(
                      JourneyType.sheetTitle,
                      weight: JourneyType.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: JourneyType.of(
                    JourneyType.body,
                    color: AarastV3Color.textMuted,
                  ),
                ),
                const SizedBox(height: 18),
                ...actions,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

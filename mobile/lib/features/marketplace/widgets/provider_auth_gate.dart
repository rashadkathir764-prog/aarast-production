import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/providers/account_context_controller.dart';
import '../../auth/providers/auth_controller.dart';

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

  static const message = 'سجّل الدخول لإرسال طلب عرض ومتابعة الردود';

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
      return const AarastScaffold(child: AarastScreenLoading());
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

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.canvas,
        body: SafeArea(
          bottom: !embedded,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(20, 24, 20, embedded ? 120 : 24),
                children: [
                  AarastCard(
                    key: const Key('provider-auth-gate'),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppTheme.brandMuted,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            LucideIcons.lock,
                            color: AppTheme.brand,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'تسجيل الدخول مطلوب',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w700,
                                height: 1.5,
                              ),
                        ),
                        const SizedBox(height: 18),
                        AarastButton(
                          key: const Key('provider-auth-gate-login'),
                          label: 'تسجيل الدخول',
                          icon: LucideIcons.logIn,
                          onPressed: () => context.go(
                            _withResume(AppRouter.login, resumeLocation),
                          ),
                        ),
                        const SizedBox(height: 10),
                        AarastButton(
                          key: const Key('provider-auth-gate-register'),
                          label: registerAsProvider
                              ? 'إنشاء حساب مزود'
                              : 'إنشاء حساب',
                          icon: LucideIcons.userPlus,
                          variant: AarastButtonVariant.secondary,
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
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.canvas,
        body: SafeArea(
          bottom: !embedded,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.fromLTRB(20, 24, 20, embedded ? 120 : 24),
                children: [
                  AarastCard(
                    key: const Key('provider-account-required-gate'),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppTheme.brandMuted,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            LucideIcons.store,
                            color: AppTheme.brand,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          hasProviderContext
                              ? 'هذه العملية غير متاحة حاليًا'
                              : 'هذا المسار للمزوّدين فقط',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          hasProviderContext
                              ? 'حالة مساحة المزود الحالية لا تسمح بهذه العملية. راجع الحالة أو جرّب لاحقًا.'
                              : 'حسابك الحالي حساب تخطيط زفاف. افتح لوحة العريس/العروسة أو قدّم طلب الانضمام كمزوّد.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.textSecondary,
                                fontWeight: FontWeight.w700,
                                height: 1.5,
                              ),
                        ),
                        const SizedBox(height: 18),
                        AarastButton(
                          key: const Key('provider-account-required-apply'),
                          label: 'تقديم طلب مزوّد',
                          icon: LucideIcons.store,
                          onPressed: () => context.go(AppRouter.providerApply),
                        ),
                        const SizedBox(height: 10),
                        AarastButton(
                          key: const Key('provider-account-required-home'),
                          label: 'فتح لوحة التخطيط',
                          icon: LucideIcons.heart,
                          variant: AarastButtonVariant.secondary,
                          onPressed: () => context.go(AppRouter.home),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

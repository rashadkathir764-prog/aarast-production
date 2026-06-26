import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/providers/auth_controller.dart';

class ProviderAuthGate extends StatelessWidget {
  const ProviderAuthGate({
    required this.child,
    required this.resumeLocation,
    this.embedded = false,
    this.registerAsProvider = false,
    super.key,
  });

  static const message =
      'تصفح الموردين وطلب عروض الأسعار يحتاج حسابًا لحفظ طلباتك ومتابعتها.';

  final Widget child;
  final String resumeLocation;
  final bool embedded;
  final bool registerAsProvider;

  @override
  Widget build(BuildContext context) {
    if (AppFeatureFlags.devBypassLoginGatesForUxExploration) {
      return child;
    }

    final auth = context.watch<AuthController>();
    if (auth.status == AuthStatus.checking) {
      return const AarastScaffold(child: AarastScreenLoading());
    }
    if (auth.status == AuthStatus.authenticated) return child;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.dBg,
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
                            color: AppTheme.dPinkBg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            color: AppTheme.dMaroon,
                            size: 32,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'تسجيل الدخول مطلوب',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: AppTheme.dInk,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: AppTheme.dInkSoft,
                                fontWeight: FontWeight.w700,
                                height: 1.5,
                              ),
                        ),
                        const SizedBox(height: 18),
                        AarastButton(
                          key: const Key('provider-auth-gate-login'),
                          label: 'تسجيل الدخول',
                          icon: Icons.login_rounded,
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
                          icon: Icons.person_add_alt_1_rounded,
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

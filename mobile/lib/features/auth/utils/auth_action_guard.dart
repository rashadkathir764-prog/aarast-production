import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_bottom_sheet.dart';
import '../../../core/widgets/aarast_toast.dart';

class AuthActionGuard {
  const AuthActionGuard._();

  static const sharingLoginGateTitle = 'سجّل الدخول لمشاركة الخطة';
  static const sharingLoginGateBody =
      'تسجيل الدخول يتيح لك دعوة العائلة وتحديد الصلاحيات ومزامنة الخطة.';
  static const sessionExpiredTitle = 'انتهت الجلسة';
  static const sharingSessionExpiredBody =
      'سجّل الدخول مرة أخرى لمتابعة مشاركة الخطة.';
  static const protectedActionMessage =
      'سجّل الدخول لحفظ هذا الإجراء على حسابك ومزامنته.';
  static const quoteSubmitMessage = 'سجّل الدخول لإرسال طلب عرض ومتابعة الردود';
  static const localPlanningSaveMessage =
      'تم الحفظ محليًا. سجّل الدخول لاحقًا لمزامنة خطتك.';

  static bool isLocalGuestPlanId(String? planId) {
    final value = planId?.trim() ?? '';
    return value.isEmpty ||
        value == 'local-guest-plan' ||
        value.startsWith('guest-plan-') ||
        value.startsWith('local-guest-');
  }

  static Future<bool> hasAccount(BuildContext context) async {
    final token = await context.read<AuthStorage>().readAccessToken();
    return token != null && token.trim().isNotEmpty;
  }

  static Future<bool> shouldGateAccountOnly(BuildContext context) async {
    if (AppFeatureFlags.devBypassLoginGatesForUxExploration) return false;
    return !await hasAccount(context);
  }

  static Future<bool> shouldGateProtectedSharing(
    BuildContext context, {
    required String? weddingPlanId,
  }) async {
    if (AppFeatureFlags.devBypassLoginGatesForUxExploration) return false;
    if (isLocalGuestPlanId(weddingPlanId)) return true;
    return !await hasAccount(context);
  }

  static Future<bool> requireAccount(
    BuildContext context, {
    required String reason,
  }) async {
    if (AppFeatureFlags.devBypassLoginGatesForUxExploration) return true;
    if (await hasAccount(context)) return true;
    if (!context.mounted) return false;

    await showAarastBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(
                    LucideIcons.refreshCw,
                    size: 42,
                    color: AppTheme.burgundy,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'هذه الخطوة تحتاج حساباً',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppTheme.ink,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.go(_withResume(AppRouter.login, context));
                    },
                    icon: const Icon(LucideIcons.logIn),
                    label: const Text('تسجيل الدخول'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.go(_withResume(AppRouter.register, context));
                    },
                    icon: const Icon(LucideIcons.userPlus),
                    label: const Text('إنشاء حساب'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return false;
  }

  static Future<bool> blockProtectedSubmitWithoutAccount(
    BuildContext context, {
    String message = protectedActionMessage,
  }) async {
    if (AppFeatureFlags.devBypassLoginGatesForUxExploration) return false;
    if (await hasAccount(context)) return false;
    if (!context.mounted) return true;

    AarastToast.showInfo(context, message);
    return true;
  }

  static Future<bool> blockCloudSubmitForNonLocalPlanning(
    BuildContext context, {
    required String? weddingPlanId,
  }) {
    if (isLocalGuestPlanId(weddingPlanId)) return Future<bool>.value(false);
    return blockProtectedSubmitWithoutAccount(context);
  }

  static String _withResume(String location, BuildContext context) {
    final resumeLocation = _currentLocation(context);
    if (resumeLocation == null) return location;
    final uri = Uri.parse(location);
    return uri
        .replace(
          queryParameters: {...uri.queryParameters, 'resume': resumeLocation},
        )
        .toString();
  }

  static String? _currentLocation(BuildContext context) {
    try {
      final location = GoRouterState.of(context).uri.toString();
      if (location.trim().isEmpty) return null;
      if (!location.startsWith('/') || location.startsWith('//')) return null;
      if (location.startsWith(AppRouter.login)) return null;
      if (location.startsWith(AppRouter.register)) return null;
      return location;
    } catch (_) {
      return null;
    }
  }
}

class AuthGatePanel extends StatelessWidget {
  const AuthGatePanel({
    required this.title,
    required this.body,
    this.icon = LucideIcons.lock,
    super.key,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    return ListView(
      key: const Key('sharing-auth-gate'),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 72),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(icon, size: 44, color: AppTheme.burgundy),
              const SizedBox(height: 14),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              FilledButton.icon(
                key: const Key('sharing-auth-gate-login'),
                onPressed: () => context.go(
                  AuthActionGuard._withResume(AppRouter.login, context),
                ),
                icon: const Icon(LucideIcons.logIn),
                label: const Text('تسجيل الدخول'),
              ),
              if (canPop) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('sharing-auth-gate-back'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(LucideIcons.chevronRight),
                  label: const Text('رجوع'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

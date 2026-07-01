import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/theme/app_theme.dart';

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

    await showModalBottomSheet<void>(
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
                    Icons.cloud_sync_rounded,
                    size: 42,
                    color: AppTheme.burgundy,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'هذه الخطوة تحتاج حساباً',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.ink,
                      fontSize: 20,
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
                      context.go(AppRouter.login);
                    },
                    icon: const Icon(Icons.login_rounded),
                    label: const Text('تسجيل الدخول'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      context.go(AppRouter.register);
                    },
                    icon: const Icon(Icons.person_add_alt_1_rounded),
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

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
    return true;
  }

  static Future<bool> blockCloudSubmitForNonLocalPlanning(
    BuildContext context, {
    required String? weddingPlanId,
  }) {
    if (isLocalGuestPlanId(weddingPlanId)) return Future<bool>.value(false);
    return blockProtectedSubmitWithoutAccount(context);
  }
}

class AuthGatePanel extends StatelessWidget {
  const AuthGatePanel({
    required this.title,
    required this.body,
    this.icon = Icons.lock_outline_rounded,
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
                style: const TextStyle(
                  color: AppTheme.ink,
                  fontSize: 20,
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
                onPressed: () => context.go(AppRouter.login),
                icon: const Icon(Icons.login_rounded),
                label: const Text('تسجيل الدخول'),
              ),
              if (canPop) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  key: const Key('sharing-auth-gate-back'),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.chevron_right_rounded),
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

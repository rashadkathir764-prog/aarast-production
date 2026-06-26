import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/theme/app_theme.dart';

class AuthActionGuard {
  const AuthActionGuard._();

  static const protectedActionMessage =
      'هذا الإجراء يحتاج تسجيل الدخول عند الحفظ النهائي.';
  static const quoteSubmitMessage = protectedActionMessage;

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

  static Future<bool> requireAccount(
    BuildContext context, {
    required String reason,
  }) async {
    if (AppFeatureFlags.devBypassLoginGatesForUxExploration) return true;
    if (await hasAccount(context)) return true;
    if (!context.mounted) return false;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.dCard,
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
                    color: AppTheme.dMaroon,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'هذه الخطوة تحتاج حساباً',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.dInk,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reason,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.dInkSoft,
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
}

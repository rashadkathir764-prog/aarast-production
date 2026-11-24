import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/config/app_feature_flags.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/offline/local_plan_id.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/storage/auth_storage.dart';
import '../../../core/widgets/aarast_toast.dart';

class AuthActionGuard {
  const AuthActionGuard._();

  static String get sharingLoginGateTitle => ReaderVoice.say(
    'سجّل الدخول لمشاركة الخطة',
    'سجّلي الدخول لمشاركة الخطة',
  );
  static const sharingLoginGateBody =
      'تسجيل الدخول يتيح لك دعوة العائلة وتحديد الصلاحيات ومزامنة الخطة.';
  static const sessionExpiredTitle = 'انتهى دخولك';
  static String get sharingSessionExpiredBody => ReaderVoice.say(
    'سجّل دخول مرة ثانية عشان تكمل مشاركة الخطة.',
    'سجّلي دخول مرة ثانية عشان تكملين مشاركة الخطة.',
  );
  // RA-MO-256: «لحفظ هذا الإجراء… ومزامنته» was formal and a programmer's
  // word; said as the app says things.
  static String get protectedActionMessage => ReaderVoice.say(
    'هذا ينحفظ في حسابك. سجّل دخول عشان تكمل.',
    'هذا ينحفظ في حسابك. سجّلي دخول عشان تكملين.',
  );
  static String get quoteSubmitMessage => ReaderVoice.say(
    'سجّل الدخول لإرسال طلب عرض ومتابعة الردود',
    'سجّلي الدخول لإرسال طلب عرض ومتابعة الردود',
  );
  static String get localPlanningSaveMessage => ReaderVoice.say(
    'انحفظ على جوالك. سجّل دخول بعدين عشان تنحفظ خطتك في حسابك.',
    'انحفظ على جوالك. سجّلي دخول بعدين عشان تنحفظ خطتك في حسابك.',
  );

  static bool isLocalGuestPlanId(String? planId) => isLocalPlanId(planId);

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

    // RA-MO-108: whoever meets this has no account yet (a plan kept on the
    // phone), so the way that leads the sheet makes one with their number,
    // as «احفظ خطتي برقم جوالي» does. «تسجيل الدخول» led it before: a new
    // person took it, went through a code, and was told the number had no
    // account. In the kit's sheet and the app's dialect, as every other.
    await showJourneySheet<void>(
      context: context,
      builder: (sheetContext) => JourneySheetBody(
        title: 'هذي تحتاج حساب',
        subtitle: reason,
        children: [
          JourneyButton(
            key: const ValueKey('account-needed-register'),
            label: 'حساب جديد برقم جوالي',
            icon: LucideIcons.smartphone,
            expand: true,
            onPressed: () {
              Navigator.of(sheetContext).pop();
              context.go(_withResume(AppRouter.register, context));
            },
          ),
          const SizedBox(height: AarastV3Space.x2),
          Center(
            child: JourneyTextAction(
              key: const ValueKey('account-needed-login'),
              label: 'عندي حساب، أدخل',
              onPressed: () {
                Navigator.of(sheetContext).pop();
                context.go(_withResume(AppRouter.login, context));
              },
            ),
          ),
        ],
      ),
    );
    return false;
  }

  static Future<bool> blockProtectedSubmitWithoutAccount(
    BuildContext context, {
    String? message,
  }) async {
    if (AppFeatureFlags.devBypassLoginGatesForUxExploration) return false;
    if (await hasAccount(context)) return false;
    if (!context.mounted) return true;

    AarastToast.showInfo(context, message ?? protectedActionMessage);
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
    this.scrolls = true,
    super.key,
  });

  final String title;
  final String body;
  final IconData icon;

  /// False inside a page that already scrolls (the settings list): the panel
  /// is as tall as what it says, not a scroll of its own on a fixed height.
  final bool scrolls;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();

    final children = [
      const SizedBox(height: AarastV3Space.x5),
      AarastV3StateSurface(
        kind: AarastV3ScreenStateKind.locked,
        icon: icon,
        title: title,
        message: body,
        action: Wrap(
          spacing: AarastV3Space.x2,
          runSpacing: AarastV3Space.x2,
          children: [
            FilledButton.icon(
              key: const Key('sharing-auth-gate-login'),
              onPressed: () => context.go(
                AuthActionGuard._withResume(AppRouter.login, context),
              ),
              icon: const Icon(LucideIcons.logIn),
              label: const Text('تسجيل الدخول'),
            ),
            if (canPop)
              OutlinedButton.icon(
                key: const Key('sharing-auth-gate-back'),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(LucideIcons.chevronRight),
                label: const Text('رجوع'),
              ),
          ],
        ),
      ),
    ];
    if (!scrolls) {
      return Column(
        key: const Key('sharing-auth-gate'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      );
    }
    return ListView(
      key: const Key('sharing-auth-gate'),
      physics: const AlwaysScrollableScrollPhysics(),
      children: children,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import 'aarast_journey_profile.dart';
import 'aarast_v3_foundations.dart';
import 'aarast_v3_content.dart';

enum AarastV3ScreenArchetype { root, list, detail, form, utility }

enum AarastV3ScreenStateKind {
  ready,
  loading,
  empty,
  error,
  offline,
  locked,
  readOnly,
  pending,
}

enum AarastV3PrivacyLevel { standard, personal, sensitive }

enum AarastV3AttentionTone { calm, information, success, warning, danger }

/// The product contract carried by every routed Mobile screen.
///
/// It deliberately contains no mutable feature data. The route declares its
/// purpose, density archetype, truth states and privacy boundary here; the
/// feature remains responsible for resolving the real state and action from
/// its provider/API data.
@immutable
class AarastV3ScreenContract {
  const AarastV3ScreenContract({
    required this.id,
    required this.location,
    required this.purpose,
    required this.archetype,
    this.states = const {
      AarastV3ScreenStateKind.ready,
      AarastV3ScreenStateKind.loading,
      AarastV3ScreenStateKind.error,
    },
    this.privacy = AarastV3PrivacyLevel.standard,
    this.supportsOffline = false,
    this.oneHandCritical = false,
  }) : assert(id != ''),
       assert(location != ''),
       assert(purpose != '');

  final String id;
  final String location;
  final String purpose;
  final AarastV3ScreenArchetype archetype;
  final Set<AarastV3ScreenStateKind> states;
  final AarastV3PrivacyLevel privacy;
  final bool supportsOffline;
  final bool oneHandCritical;

  bool supports(AarastV3ScreenStateKind state) => states.contains(state);
}

const _standardStates = {
  AarastV3ScreenStateKind.ready,
  AarastV3ScreenStateKind.loading,
  AarastV3ScreenStateKind.empty,
  AarastV3ScreenStateKind.error,
  AarastV3ScreenStateKind.offline,
};

const _protectedStates = {
  ..._standardStates,
  AarastV3ScreenStateKind.locked,
  AarastV3ScreenStateKind.readOnly,
  AarastV3ScreenStateKind.pending,
};

/// Central route-to-experience registry.
///
/// Keeping matching here prevents a new route from silently inventing its own
/// hierarchy. Dynamic identifiers are ignored; the product area and decision
/// shape determine the contract.
abstract final class AarastV3ScreenCatalog {
  static const startup = AarastV3ScreenContract(
    id: 'startup',
    location: 'بدء اعّرست',
    purpose: 'استعادة الجلسة والمسار بأمان',
    archetype: AarastV3ScreenArchetype.utility,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.personal,
    supportsOffline: true,
  );

  static const welcome = AarastV3ScreenContract(
    id: 'welcome',
    location: 'البداية',
    purpose: 'اختيار المسار وبدء خطة حقيقية',
    archetype: AarastV3ScreenArchetype.root,
    states: _standardStates,
    supportsOffline: true,
  );

  static const auth = AarastV3ScreenContract(
    id: 'auth',
    location: 'الحساب',
    purpose: 'الدخول أو إنشاء الحساب بأقل بيانات لازمة',
    archetype: AarastV3ScreenArchetype.form,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.sensitive,
  );

  static const contextSelection = AarastV3ScreenContract(
    id: 'context-selection',
    location: 'اختر المسار',
    purpose: 'فتح مساحة المستخدم الصحيحة دون تخمين',
    archetype: AarastV3ScreenArchetype.list,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.personal,
  );

  static const home = AarastV3ScreenContract(
    id: 'home',
    location: 'الرئيسية',
    purpose: 'عرض أهم قرار حقيقي في الخطة الآن',
    archetype: AarastV3ScreenArchetype.root,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.personal,
    supportsOffline: true,
  );

  static const money = AarastV3ScreenContract(
    id: 'money',
    location: 'المال',
    purpose: 'فهم الميزانية والالتزامات ثم تنفيذ القرار الأقرب',
    archetype: AarastV3ScreenArchetype.root,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.sensitive,
    supportsOffline: true,
  );

  static const moneyDetail = AarastV3ScreenContract(
    id: 'money-detail',
    location: 'تفاصيل مالية',
    purpose: 'فهم المبلغ والحالة والإجراء المالي التالي',
    archetype: AarastV3ScreenArchetype.detail,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.sensitive,
    supportsOffline: true,
  );

  static const moneyForm = AarastV3ScreenContract(
    id: 'money-form',
    location: 'قرار مالي',
    purpose: 'تسجيل قرار مالي ومراجعة أثره قبل الحفظ',
    archetype: AarastV3ScreenArchetype.form,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.sensitive,
    supportsOffline: true,
  );

  static const tasks = AarastV3ScreenContract(
    id: 'tasks',
    location: 'المهام',
    purpose: 'تنفيذ الأقرب والأهم دون تشتيت',
    archetype: AarastV3ScreenArchetype.list,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.personal,
    supportsOffline: true,
  );

  static const taskForm = AarastV3ScreenContract(
    id: 'task-form',
    location: 'المهمة',
    purpose: 'تحويل قرار واحد إلى مهمة قابلة للتنفيذ',
    archetype: AarastV3ScreenArchetype.form,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.personal,
    supportsOffline: true,
  );

  static const guests = AarastV3ScreenContract(
    id: 'guests',
    location: 'الضيوف',
    purpose: 'معرفة الحضور ومعالجة الرد أو البيانات الأهم',
    archetype: AarastV3ScreenArchetype.list,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.sensitive,
    supportsOffline: true,
  );

  static const guestForm = AarastV3ScreenContract(
    id: 'guest-form',
    location: 'إضافة ضيف',
    purpose: 'حفظ أقل بيانات لازمة ثم استكمالها لاحقًا',
    archetype: AarastV3ScreenArchetype.form,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.sensitive,
    supportsOffline: true,
  );

  static const providers = AarastV3ScreenContract(
    id: 'providers',
    location: 'المزوّدون',
    purpose: 'اكتشاف ومقارنة مزوّد مناسب دون ادعاء حجز',
    archetype: AarastV3ScreenArchetype.root,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.personal,
  );

  static const providerDetail = AarastV3ScreenContract(
    id: 'provider-detail',
    location: 'تفاصيل المزوّد',
    purpose: 'فهم الخدمة والثقة والسعر ثم طلب عرض حقيقي',
    archetype: AarastV3ScreenArchetype.detail,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.personal,
  );

  static const providerWorkspace = AarastV3ScreenContract(
    id: 'provider-workspace',
    location: 'مساحة المزوّد',
    purpose: 'إدارة الطلبات والخدمات والحالة المهنية',
    archetype: AarastV3ScreenArchetype.root,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.personal,
  );

  static const providerForm = AarastV3ScreenContract(
    id: 'provider-form',
    location: 'بيانات المزوّد',
    purpose: 'حفظ خدمة أو ملف مهني بقرار واضح',
    archetype: AarastV3ScreenArchetype.form,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.personal,
  );

  static const conversations = AarastV3ScreenContract(
    id: 'conversations',
    location: 'المحادثات',
    purpose: 'متابعة المحادثات المرتبطة بطلبات عروض حقيقية',
    archetype: AarastV3ScreenArchetype.list,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.sensitive,
  );

  static const conversation = AarastV3ScreenContract(
    id: 'conversation',
    location: 'المحادثة',
    purpose: 'مراجعة الطلب والعرض والرسائل ضمن العلاقة الحالية',
    archetype: AarastV3ScreenArchetype.detail,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.sensitive,
  );

  static const notifications = AarastV3ScreenContract(
    id: 'notifications',
    location: 'الإشعارات',
    purpose: 'عرض ما يحتاج الانتباه دون كشف تفاصيل حساسة',
    archetype: AarastV3ScreenArchetype.list,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.personal,
  );

  static const plans = AarastV3ScreenContract(
    id: 'plans',
    location: 'خططك',
    purpose: 'اختيار الخطة أو إدارتها دون تكرار لوحة التحكم',
    archetype: AarastV3ScreenArchetype.list,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.personal,
    supportsOffline: true,
  );

  static const planDetail = AarastV3ScreenContract(
    id: 'plan-detail',
    location: 'إدارة الخطة',
    purpose: 'إدارة هوية الخطة وبياناتها ومشاركتها',
    archetype: AarastV3ScreenArchetype.detail,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.sensitive,
    supportsOffline: true,
  );

  static const planForm = AarastV3ScreenContract(
    id: 'plan-form',
    location: 'إنشاء خطة',
    purpose: 'إنشاء خطة بأقل تفاصيل لازمة وقابلة للتعديل',
    archetype: AarastV3ScreenArchetype.form,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.personal,
    supportsOffline: true,
  );

  static const sharing = AarastV3ScreenContract(
    id: 'sharing',
    location: 'المشاركة',
    purpose: 'إدارة المشاركين والصلاحيات بوضوح وخصوصية',
    archetype: AarastV3ScreenArchetype.list,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.sensitive,
  );

  static const sharingForm = AarastV3ScreenContract(
    id: 'sharing-form',
    location: 'صلاحيات المشاركة',
    purpose: 'منح الصلاحيات المقصودة فقط قبل الإرسال',
    archetype: AarastV3ScreenArchetype.form,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.sensitive,
  );

  static const contributionHistory = AarastV3ScreenContract(
    id: 'contribution-history',
    location: 'سجل المساهمات',
    purpose: 'عرض سجل ثابت دون فتح بيانات حية غير مصرح بها',
    archetype: AarastV3ScreenArchetype.list,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.sensitive,
    supportsOffline: true,
  );

  /// b12 «مناسبات عرسك» (D65): the events the wedding week and day are
  /// built from.
  static const planEvents = AarastV3ScreenContract(
    id: 'plan-events',
    location: 'مناسبات عرسك',
    purpose: 'ترتيب مناسبات العرس اللي يتبنى منها أسبوع العرس ويومه',
    archetype: AarastV3ScreenArchetype.list,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.personal,
    supportsOffline: true,
  );

  static const utility = AarastV3ScreenContract(
    id: 'utility',
    location: 'أدواتك',
    purpose: 'الوصول إلى الحساب والإعدادات والمساندة',
    archetype: AarastV3ScreenArchetype.utility,
    states: _protectedStates,
    privacy: AarastV3PrivacyLevel.personal,
    supportsOffline: true,
  );

  static const unmapped = AarastV3ScreenContract(
    id: 'unmapped',
    location: 'اعّرست',
    purpose: 'مسار غير مصنّف يحتاج مراجعة قبل الإطلاق',
    archetype: AarastV3ScreenArchetype.utility,
    states: _protectedStates,
  );

  static AarastV3ScreenContract resolve(String location) {
    final uri = Uri.tryParse(location);
    final path = (uri?.path ?? location).replaceAll(RegExp(r'/+$'), '');
    final normalized = path.isEmpty ? '/' : path;

    if (normalized == '/') return startup;
    if (normalized == '/welcome' ||
        normalized == '/onboarding' ||
        normalized == '/guest-onboarding-preview' ||
        normalized == '/dev/guest-onboarding') {
      return welcome;
    }
    if (normalized == '/login' ||
        normalized == '/register' ||
        normalized == '/reset-password' ||
        normalized == '/otp') {
      return auth;
    }
    if (normalized == '/home') return contextSelection;
    if (normalized == '/providers') return providers;
    if (normalized == '/providers/favorites') return providers;
    if (RegExp(r'^/providers/[^/]+/quote(?:-request)?$').hasMatch(normalized)) {
      return providerForm;
    }
    if (RegExp(r'^/providers/[^/]+$').hasMatch(normalized)) {
      return providerDetail;
    }
    if (normalized == '/provider/apply' ||
        normalized == '/provider/profile/edit' ||
        normalized == '/provider/services/new' ||
        normalized == '/provider/packages/new') {
      return providerForm;
    }
    if (normalized == '/provider/dashboard') {
      return providerWorkspace;
    }
    if (normalized == '/conversations') return conversations;
    if (RegExp(
      r'^/(?:conversations|quotes)/[^/]+(?:/conversation)?$',
    ).hasMatch(normalized)) {
      return conversation;
    }
    if (normalized == '/notifications') return notifications;
    if (normalized == '/invites' ||
        normalized == '/invites/access' ||
        RegExp(r'^/invites/[^/]+$').hasMatch(normalized)) {
      return sharing;
    }
    if (normalized == '/more' ||
        normalized == '/settings' ||
        normalized == '/support') {
      return utility;
    }
    if (normalized == '/wedding-plans') return plans;
    if (normalized == '/wedding-plans/create') return planForm;
    if (normalized == '/shared/wedding-plans' ||
        normalized == '/shared-wedding-plans') {
      return plans;
    }

    if (!normalized.startsWith('/wedding-plans/')) return unmapped;

    if (normalized.endsWith('/dashboard')) return home;
    if (normalized.endsWith('/plan-center')) return planDetail;
    if (normalized.endsWith('/events')) return planEvents;
    // y06 and y07 are the home's own moments.
    if (RegExp(r'/moments/[^/]+$').hasMatch(normalized)) return home;
    if (normalized.endsWith('/timeline')) return tasks;
    if (normalized.endsWith('/contributions')) return contributionHistory;
    if (normalized.endsWith('/notifications')) return notifications;
    if (normalized.endsWith('/sharing/add') ||
        RegExp(r'/sharing/[^/]+/edit$').hasMatch(normalized)) {
      return sharingForm;
    }
    if (normalized.endsWith('/sharing')) return sharing;
    if (normalized.endsWith('/tasks/create') ||
        RegExp(r'/tasks/[^/]+/edit$').hasMatch(normalized)) {
      return taskForm;
    }
    if (normalized.endsWith('/tasks')) return tasks;
    if (normalized.endsWith('/guests/add')) return guestForm;
    if (normalized.endsWith('/guests')) return guests;
    if (normalized.endsWith('/providers')) return providers;
    if (normalized.endsWith('/money')) return money;
    if (normalized.endsWith('/money/budget') ||
        normalized.endsWith('/money/categories/create') ||
        RegExp(r'/money/categories/[^/]+/edit$').hasMatch(normalized) ||
        normalized.endsWith('/money/costs/create') ||
        RegExp(r'/money/costs/[^/]+/edit$').hasMatch(normalized) ||
        RegExp(r'/money/costs/[^/]+/payments/create$').hasMatch(normalized) ||
        RegExp(
          r'/money/costs/[^/]+/schedules/[^/]+/pay$',
        ).hasMatch(normalized)) {
      return moneyForm;
    }
    if (normalized.contains('/money/')) return moneyDetail;
    return planDetail;
  }
}

/// Makes the current route contract available to every descendant without
/// forcing feature screens to import routing code or duplicate path logic.
class AarastV3ExperienceScope extends InheritedWidget {
  const AarastV3ExperienceScope({
    required this.contract,
    required super.child,
    super.key,
  });

  final AarastV3ScreenContract contract;

  static AarastV3ScreenContract? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<AarastV3ExperienceScope>()
      ?.contract;

  static AarastV3ScreenContract of(BuildContext context) {
    final contract = maybeOf(context);
    assert(contract != null, 'No AarastV3ExperienceScope found in context.');
    return contract ?? AarastV3ScreenCatalog.unmapped;
  }

  @override
  bool updateShouldNotify(AarastV3ExperienceScope oldWidget) =>
      oldWidget.contract != contract;
}

/// Route-level adapter used by the app shell. It rebuilds only the semantic
/// scope when navigation changes and keeps the Navigator subtree intact.
class AarastV3AdaptiveExperienceShell extends StatelessWidget {
  const AarastV3AdaptiveExperienceShell({
    required this.routeListenable,
    required this.readLocation,
    required this.child,
    super.key,
  });

  final Listenable routeListenable;
  final String Function() readLocation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: routeListenable,
      child: child,
      builder: (context, child) {
        final contract = AarastV3ScreenCatalog.resolve(readLocation());
        return AarastV3ExperienceScope(
          contract: contract,
          child: Semantics(
            container: true,
            scopesRoute: true,
            namesRoute: true,
            explicitChildNodes: true,
            label: contract.location,
            child: child,
          ),
        );
      },
    );
  }
}

/// One explicit, compact decision surface. It is intentionally not a generic
/// card: it accepts one action only and always explains why it is shown.
class AarastV3AttentionSurface extends StatelessWidget {
  const AarastV3AttentionSurface({
    required this.eyebrow,
    required this.title,
    required this.reason,
    required this.icon,
    this.actionLabel,
    this.onAction,
    this.onTap,
    this.tone = AarastV3AttentionTone.information,
    super.key,
  }) : assert((actionLabel == null) == (onAction == null));

  final String eyebrow;
  final String title;
  final String reason;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback? onTap;
  final AarastV3AttentionTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = _attentionColors(tone, context.accent);
    final surface = Semantics(
      container: true,
      button: onTap != null,
      label: '$eyebrow، $title. $reason',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AarastV3Space.x3),
        decoration: BoxDecoration(
          color: AarastV3Color.paper,
          borderRadius: BorderRadius.circular(AarastV3Radius.surface),
          border: Border.all(color: AarastV3Color.line),
        ),
        child: Builder(
          builder: (context) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final screenWidth = MediaQuery.sizeOf(context).width;
            final stackAction =
                actionLabel != null && (screenWidth < 400 || textScale > 1.1);
            final action = actionLabel == null
                ? null
                : TextButton.icon(
                    onPressed: onAction,
                    style: TextButton.styleFrom(
                      foregroundColor: colors.foreground,
                      backgroundColor: colors.background,
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AarastV3Space.x3,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AarastV3Radius.control,
                        ),
                      ),
                    ),
                    icon: const Icon(LucideIcons.arrowLeft, size: 16),
                    label: Text(
                      actionLabel!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  );

            final narrative = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 3,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colors.foreground,
                    borderRadius: BorderRadius.circular(AarastV3Radius.pill),
                  ),
                ),
                const SizedBox(width: AarastV3Space.x3),
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.background,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 18, color: colors.foreground),
                ),
                const SizedBox(width: AarastV3Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        eyebrow,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AarastV3Type.label(
                          context,
                        ).copyWith(color: colors.foreground),
                      ),
                      const SizedBox(height: AarastV3Space.x1),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AarastV3Color.ink,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AarastV3Space.x1),
                      Text(
                        reason,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AarastV3Color.textMuted,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            if (action == null) return narrative;
            if (stackAction) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  narrative,
                  const SizedBox(height: AarastV3Space.x1),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: action,
                  ),
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: narrative),
                const SizedBox(width: AarastV3Space.x2),
                Flexible(child: action),
              ],
            );
          },
        ),
      ),
    );
    if (onTap == null) return surface;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AarastV3Radius.surface),
        child: surface,
      ),
    );
  }
}

({Color foreground, Color background}) _attentionColors(
  AarastV3AttentionTone tone,
  JourneyAccent accent,
) {
  return switch (tone) {
    AarastV3AttentionTone.calm => (
      foreground: accent.primary,
      background: accent.primarySoft,
    ),
    AarastV3AttentionTone.information => (
      foreground: AarastV3Color.cobalt,
      background: AarastV3Color.cobaltSoft,
    ),
    AarastV3AttentionTone.success => (
      foreground: AarastV3Color.mint,
      background: AarastV3Color.mintSoft,
    ),
    AarastV3AttentionTone.warning => (
      foreground: AarastV3Color.amber,
      background: AarastV3Color.amberSoft,
    ),
    AarastV3AttentionTone.danger => (
      foreground: AarastV3Color.danger,
      background: AarastV3Color.dangerSoft,
    ),
  };
}

/// Small trust signal for offline, queued, read-only and privacy explanations.
class AarastV3TrustLine extends StatelessWidget {
  const AarastV3TrustLine({
    required this.message,
    this.icon = LucideIcons.shieldCheck,
    this.tone = AarastV3AttentionTone.calm,
    super.key,
  });

  final String message;
  final IconData icon;
  final AarastV3AttentionTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = _attentionColors(tone, context.accent);
    return Semantics(
      container: true,
      label: message,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colors.foreground),
          const SizedBox(width: AarastV3Space.x1),
          Flexible(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AarastV3Color.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One compact visual grammar for empty, failure, offline, locked, read-only
/// and pending states. Feature code owns the truthful copy and action; this
/// component owns density, hierarchy and semantic announcement.
class AarastV3StateSurface extends StatelessWidget {
  const AarastV3StateSurface({
    required this.kind,
    required this.title,
    required this.message,
    this.icon,
    this.action,
    this.preferInlineAction = false,
    super.key,
  });

  factory AarastV3StateSurface.offline({Widget? action, Key? key}) {
    return AarastV3StateSurface(
      key: key,
      kind: AarastV3ScreenStateKind.offline,
      title: AarastV3Copy.offlineTitle,
      message: AarastV3Copy.offlineMessage,
      action: action,
    );
  }

  factory AarastV3StateSurface.locked({Widget? action, Key? key}) {
    return AarastV3StateSurface(
      key: key,
      kind: AarastV3ScreenStateKind.locked,
      title: AarastV3Copy.lockedTitle,
      message: AarastV3Copy.lockedMessage,
      action: action,
    );
  }

  factory AarastV3StateSurface.readOnly({Widget? action, Key? key}) {
    return AarastV3StateSurface(
      key: key,
      kind: AarastV3ScreenStateKind.readOnly,
      title: AarastV3Copy.readOnlyTitle,
      message: AarastV3Copy.readOnlyMessage,
      action: action,
    );
  }

  factory AarastV3StateSurface.pending({Widget? action, Key? key}) {
    return AarastV3StateSurface(
      key: key,
      kind: AarastV3ScreenStateKind.pending,
      title: AarastV3Copy.pendingTitle,
      message: AarastV3Copy.pendingMessage,
      action: action,
    );
  }

  final AarastV3ScreenStateKind kind;
  final String title;
  final String message;
  final IconData? icon;
  final Widget? action;
  final bool preferInlineAction;

  @override
  Widget build(BuildContext context) {
    final visual = _stateVisual(kind, context.accent);
    return Semantics(
      container: true,
      liveRegion:
          kind == AarastV3ScreenStateKind.error ||
          kind == AarastV3ScreenStateKind.offline,
      label: '$title. $message',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AarastV3Space.x3),
        decoration: BoxDecoration(
          color: AarastV3Color.paper,
          borderRadius: BorderRadius.circular(AarastV3Radius.surface),
          border: Border.all(color: AarastV3Color.line),
        ),
        child: Builder(
          builder: (context) {
            final textScale = MediaQuery.textScalerOf(context).scale(1);
            final screenWidth = MediaQuery.sizeOf(context).width;
            final inline =
                preferInlineAction &&
                action != null &&
                screenWidth >= 370 &&
                textScale <= 1.3;
            final narrative = Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: visual.background,
                    borderRadius: BorderRadius.circular(AarastV3Radius.control),
                  ),
                  child: Icon(
                    icon ?? visual.icon,
                    size: 18,
                    color: visual.foreground,
                  ),
                ),
                const SizedBox(width: AarastV3Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AarastV3Color.ink,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: AarastV3Space.x1),
                      Text(
                        message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AarastV3Color.textMuted,
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );

            if (action == null) return narrative;
            if (inline) {
              return Row(
                children: [
                  Expanded(child: narrative),
                  const SizedBox(width: AarastV3Space.x2),
                  action!,
                ],
              );
            }
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                narrative,
                const SizedBox(height: AarastV3Space.x2),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: action!,
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

({Color foreground, Color background, IconData icon}) _stateVisual(
  AarastV3ScreenStateKind kind,
  JourneyAccent accent,
) {
  return switch (kind) {
    AarastV3ScreenStateKind.ready => (
      foreground: AarastV3Color.mint,
      background: AarastV3Color.mintSoft,
      icon: LucideIcons.check,
    ),
    AarastV3ScreenStateKind.loading => (
      foreground: accent.primary,
      background: accent.primarySoft,
      icon: LucideIcons.loader,
    ),
    AarastV3ScreenStateKind.empty => (
      foreground: accent.primary,
      background: accent.primarySoft,
      icon: LucideIcons.inbox,
    ),
    AarastV3ScreenStateKind.error => (
      foreground: AarastV3Color.danger,
      background: AarastV3Color.dangerSoft,
      icon: LucideIcons.alertCircle,
    ),
    AarastV3ScreenStateKind.offline => (
      foreground: AarastV3Color.amber,
      background: AarastV3Color.amberSoft,
      icon: LucideIcons.wifiOff,
    ),
    AarastV3ScreenStateKind.locked => (
      foreground: AarastV3Color.rose,
      background: AarastV3Color.roseSoft,
      icon: LucideIcons.lock,
    ),
    AarastV3ScreenStateKind.readOnly => (
      foreground: AarastV3Color.cobalt,
      background: AarastV3Color.cobaltSoft,
      icon: LucideIcons.eye,
    ),
    AarastV3ScreenStateKind.pending => (
      foreground: AarastV3Color.amber,
      background: AarastV3Color.amberSoft,
      icon: LucideIcons.uploadCloud,
    ),
  };
}

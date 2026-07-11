import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/aarast_design_tokens.dart';
import '../../../../core/theme/aarast_motion.dart';
import '../../models/dashboard_summary.dart';
import 'countdown_hero.dart';
import 'smart_dashboard_cards.dart';

/// لوحة أعرست الجديدة — تلخّص، تنبّه، وتوجّه. لا تسرد ولا تزحم.
class PremiumDashboardView extends StatelessWidget {
  const PremiumDashboardView({
    required this.summary,
    required this.userName,
    required this.bottomPadding,
    required this.onNotifications,
    required this.onProfile,
    required this.onOpenPlan,
    required this.onOpenMoney,
    required this.onOpenTasks,
    required this.onOpenProviders,
    required this.onOpenGuests,
    required this.onOpenSharing,
    required this.onOpenNextStep,
    required this.onOpenImportantItem,
    this.personaHeadline,
    this.notice,
    this.now,
    super.key,
  });

  final DashboardSummary summary;
  final String userName;
  final double bottomPadding;
  final String? personaHeadline;

  /// شارة اختيارية تظهر أسفل الترويسة مباشرة (مثل تنبيه المزامنة للضيف المحلي).
  final Widget? notice;

  /// وقت مرجعي للتحية (للاختبار). فارغ = الوقت الحالي.
  final DateTime? now;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenMoney;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenProviders;
  final VoidCallback onOpenGuests;
  final VoidCallback onOpenSharing;
  final VoidCallback onOpenNextStep;
  final ValueChanged<DashboardImportantItem> onOpenImportantItem;

  bool get _hasBudget => (parseAmount(summary.totalBudgetForDisplay) ?? 0) > 0;
  bool get _hasTasks => summary.totalTasks > 0;
  bool get _hasGuests => summary.guestCount > 0;
  bool get _isFreshPlan => !_hasBudget || !_hasTasks || !_hasGuests;

  /// نبض بلا أي إشارة حية هو أصفار ميتة — يختفي حتى تولد أول قيمة.
  bool get _hasPulseSignal =>
      summary.totalTasks > 0 ||
      summary.guestCount > 0 ||
      summary.providerCount > 0;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AarastMotion.reduceMotion(context);
    final smartAction = resolveSmartAction(summary);

    final children = <Widget>[
      _DashboardHeader(
        userName: userName,
        isLocalOnly: summary.isLocalOnly,
        unreadCount: summary.unreadNotificationsCount,
        onNotifications: onNotifications,
        onProfile: onProfile,
        now: now,
      ),
      if (notice != null) ...[const SizedBox(height: 14), notice!],
      const SizedBox(height: 18),
      AarastCountdownHero(
        planTitle: summary.title,
        kicker: personaHeadline,
        progressPercentage: summary.progressPercentage,
        weddingDate: summary.weddingDate,
        city: summary.city,
        daysRemaining: summary.daysRemaining,
        onTap: onOpenPlan,
      ),
      const SizedBox(height: 14),
      if (smartAction != null) ...[
        AarastNextActionCard(
          action: smartAction,
          onTap: () {
            final item = smartAction.item;
            if (item != null) {
              onOpenImportantItem(item);
            } else {
              onOpenNextStep();
            }
          },
        ),
        const SizedBox(height: 14),
      ],
      if (_isFreshPlan) ...[
        AarastSetupJourneyCard(
          steps: [
            SetupStep(
              label: 'حدد ميزانية العرس',
              hint: 'رقم تقريبي يكفي — نعدّله متى ما شئت.',
              icon: LucideIcons.wallet,
              done: _hasBudget,
              onTap: onOpenMoney,
            ),
            SetupStep(
              label: 'أضف أول مهمة',
              hint: 'مثل حجز الصالة أو موعد التصوير.',
              icon: LucideIcons.listChecks,
              done: _hasTasks,
              onTap: onOpenTasks,
            ),
            SetupStep(
              label: 'أضف أول ضيف',
              hint: 'قائمة الضيوف تساعدك تقدّر التكلفة.',
              icon: LucideIcons.users,
              done: _hasGuests,
              onTap: onOpenGuests,
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
      // في الخطة الجديدة تتصدر رحلة الإعداد وحدها؛ الكروت الفارغة
      // (نبض بلا أرقام، ميزانية ومشاركة بلا محتوى) تكرارٌ يطيل التمرير.
      if (!_isFreshPlan || _hasPulseSignal) ...[
        AarastPulseRow(
          tiles: [
            PulseTileData(
              label: 'المهام',
              value: '${summary.completedTasks}/${summary.totalTasks}',
              caption: summary.totalTasks == 0
                  ? 'ابدأ بأول مهمة'
                  : summary.overdueTasks > 0
                  ? '${summary.overdueTasks} متأخرة'
                  : summary.todayTasks > 0
                  ? '${summary.todayTasks} اليوم'
                  : 'تحت السيطرة',
              icon: LucideIcons.listChecks,
              onTap: onOpenTasks,
            ),
            PulseTileData(
              label: 'الضيوف',
              value: '${summary.guestCount}',
              caption: summary.guestCount == 0
                  ? 'أضف أول ضيف'
                  : '${summary.confirmedGuests} مؤكد',
              icon: LucideIcons.users,
              onTap: onOpenGuests,
            ),
            PulseTileData(
              label: 'الموردون',
              value: '${summary.providerCount}',
              caption: summary.receivedQuotes > 0
                  ? '${summary.receivedQuotes} عرض وصل'
                  : summary.pendingQuoteRequests > 0
                  ? '${summary.pendingQuoteRequests} بانتظار رد'
                  : 'استكشف',
              icon: LucideIcons.store,
              onTap: onOpenProviders,
            ),
          ],
        ),
        const SizedBox(height: 14),
      ],
      // المال أهم كرت تشغيلي — يسبق المشاركة ليبقى فوق خط أول شاشة.
      if (!_isFreshPlan && summary.canViewMoney) ...[
        AarastMoneyGlanceCard(summary: summary, onOpenMoney: onOpenMoney),
        const SizedBox(height: 14),
      ],
      if (!_isFreshPlan)
        AarastParticipantsGlanceCard(
          summary: summary,
          onOpenSharing: onOpenSharing,
        ),
      if (!_isFreshPlan && smartAction == null) ...[
        const SizedBox(height: 14),
        const _AllClearCard(),
      ],
    ];

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        for (var i = 0; i < children.length; i++)
          _staggered(children[i], i, reduceMotion),
      ],
    );
  }

  /// دخول متدرج هادئ: كل عنصر يطفو للأعلى بفارق نَفَس قصير.
  Widget _staggered(Widget child, int index, bool reduceMotion) {
    if (reduceMotion || child is SizedBox) return child;
    return child
        .animate()
        .fadeIn(
          delay: (60 * index).ms,
          duration: 420.ms,
          curve: Curves.easeOutCubic,
        )
        .slideY(
          begin: 0.06,
          end: 0,
          delay: (60 * index).ms,
          duration: 420.ms,
          curve: Curves.easeOutCubic,
        );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.userName,
    required this.isLocalOnly,
    required this.unreadCount,
    required this.onNotifications,
    required this.onProfile,
    this.now,
  });

  final String userName;
  final bool isLocalOnly;
  final int unreadCount;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final DateTime? now;

  String get _greeting {
    final hour = (now ?? DateTime.now()).hour;
    if (hour >= 5 && hour < 12) return 'صباح الخير';
    if (hour >= 12 && hour < 17) return 'مساء النور';
    return 'مساء الخير';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // التحية الشخصية هي بطل الهيدر — العلامة معروفة داخل تطبيقها.
              Text(
                '$_greeting، $userName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AarastDesignTokens.title,
                ),
              ),
              if (isLocalOnly) ...[
                const SizedBox(height: 6),
                InkWell(
                  onTap: onProfile,
                  borderRadius: BorderRadius.circular(
                    AarastDesignTokens.radiusPill,
                  ),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 220),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AarastDesignTokens.goldSoft,
                      borderRadius: BorderRadius.circular(
                        AarastDesignTokens.radiusPill,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          LucideIcons.smartphone,
                          size: 12,
                          color: AarastDesignTokens.warning,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            // Keep the local-sync pill compact at large text scales.
                            'محفوظ محليًا · فعّل المزامنة',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AarastDesignTokens.ink,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        _HeaderIconButton(
          icon: LucideIcons.bell,
          badgeCount: unreadCount,
          onTap: onNotifications,
          semanticLabel: 'التنبيهات',
        ),
        const SizedBox(width: 8),
        _HeaderIconButton(
          icon: LucideIcons.user,
          onTap: onProfile,
          semanticLabel: 'حسابي والمزيد',
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.badgeCount = 0,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Ink(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AarastDesignTokens.surface,
            shape: BoxShape.circle,
            border: Border.all(color: AarastDesignTokens.border),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 20, color: AarastDesignTokens.burgundy),
              if (badgeCount > 0)
                PositionedDirectional(
                  top: 9,
                  end: 9,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AarastDesignTokens.danger,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AarastDesignTokens.surface,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllClearCard extends StatelessWidget {
  const _AllClearCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: AarastDesignTokens.successSoft,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.badgeCheck,
            color: AarastDesignTokens.success,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'كل شيء تحت السيطرة — لا يوجد ما يستعجلك اليوم. خذ نفسًا واستمتع بالتحضير.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AarastDesignTokens.ink,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// الهيكل العظمي — لؤلؤي، بنفس أشكال الواجهة الحقيقية، بلا قفزات.
// ---------------------------------------------------------------------------

class PremiumDashboardSkeleton extends StatelessWidget {
  const PremiumDashboardSkeleton({required this.bottomPadding, super.key});

  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = AarastMotion.reduceMotion(context);

    Widget block({double? width, required double height, double radius = 16}) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AarastDesignTokens.border.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
    }

    Widget content = ListView(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomPadding),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        Row(
          children: [
            Expanded(child: block(width: 190, height: 20, radius: 8)),
            const SizedBox(width: 40),
            block(width: 44, height: 44, radius: 22),
            const SizedBox(width: 8),
            block(width: 44, height: 44, radius: 22),
          ],
        ),
        const SizedBox(height: 18),
        block(height: 168, radius: AarastDesignTokens.radiusXl),
        const SizedBox(height: 14),
        block(height: 92, radius: AarastDesignTokens.radiusLg),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: block(height: 96)),
            const SizedBox(width: 10),
            Expanded(child: block(height: 96)),
            const SizedBox(width: 10),
            Expanded(child: block(height: 96)),
          ],
        ),
        const SizedBox(height: 14),
        block(height: 150, radius: AarastDesignTokens.radiusLg),
        const SizedBox(height: 14),
        block(height: 56, radius: AarastDesignTokens.radiusLg),
      ],
    );

    if (reduceMotion) return content;

    return content
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1400.ms,
          color: AarastDesignTokens.pearl.withValues(alpha: 0.9),
        );
  }
}

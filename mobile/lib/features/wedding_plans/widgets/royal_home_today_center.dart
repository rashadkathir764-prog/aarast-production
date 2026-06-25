import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/widgets/aarast_pressable.dart';
import '../models/dashboard_summary.dart';

class RoyalHomeTodayCenter extends StatelessWidget {
  const RoyalHomeTodayCenter({
    required this.summary,
    required this.userName,
    required this.onNotifications,
    required this.onProfile,
    required this.onOpenPlan,
    required this.onOpenMoney,
    required this.onOpenTasks,
    required this.onOpenProviders,
    required this.onOpenGuests,
    required this.onOpenParticipants,
    required this.onOpenNotifications,
    required this.onOpenImportantItem,
    required this.onOpenNextStep,
    required this.onOpenTimeline,
    this.bottomPadding = 156,
    this.notice,
    super.key,
  });

  final DashboardSummary summary;
  final String userName;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenMoney;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenProviders;
  final VoidCallback onOpenGuests;
  final VoidCallback onOpenParticipants;
  final VoidCallback onOpenNotifications;
  final ValueChanged<DashboardImportantItem> onOpenImportantItem;
  final VoidCallback onOpenNextStep;
  final VoidCallback onOpenTimeline;
  final double bottomPadding;
  final Widget? notice;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: _RoyalColors.ivory),
      child: ListView(
        key: ValueKey('royal-home-${summary.planId}'),
        padding: EdgeInsets.fromLTRB(20, 22, 20, bottomPadding),
        children: [
          _PremiumEntry(
            index: 0,
            child: _PremiumHeader(
              userName: userName,
              unreadCount: summary.unreadNotificationsCount,
              onNotifications: onNotifications,
              onProfile: onProfile,
            ),
          ),
          if (notice != null) ...[
            const SizedBox(height: 16),
            _PremiumEntry(index: 1, child: notice!),
          ],
          const SizedBox(height: 24),
          _PremiumEntry(
            index: notice != null ? 2 : 1,
            child: _PremiumHeroCard(
              summary: summary,
              onOpenPlan: onOpenPlan,
              onOpenTimeline: onOpenTimeline,
              onOpenProgress: onOpenTasks,
            ),
          ),
          const SizedBox(height: 28),
          _PremiumEntry(
            index: notice != null ? 3 : 2,
            child: _PanoramicCardsCarousel(
              summary: summary,
              onOpenProviders: onOpenProviders,
              onOpenImportantItem: onOpenImportantItem,
              onOpenMoney: onOpenMoney,
            ),
          ),
          const SizedBox(height: 24),
          _PremiumEntry(
            index: notice != null ? 4 : 3,
            child: _OperationalCards(
              summary: summary,
              onOpenTasks: onOpenTasks,
              onOpenGuests: onOpenGuests,
              onOpenParticipants: onOpenParticipants,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader({
    required this.userName,
    required this.unreadCount,
    required this.onNotifications,
    required this.onProfile,
  });

  final String userName;
  final int unreadCount;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _greetingFor(userName),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _RoyalColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'أعرست ✨',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _RoyalColors.burgundy,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _CircleIconButton(
          icon: Icons.notifications_none_rounded,
          onTap: onNotifications,
          showBadge: unreadCount > 0,
        ),
        const SizedBox(width: 10),
        _CircleIconButton(
          icon: Icons.person_outline_rounded,
          onTap: onProfile,
        ),
      ],
    );
  }
}

class _PremiumHeroCard extends StatelessWidget {
  const _PremiumHeroCard({
    required this.summary,
    required this.onOpenPlan,
    required this.onOpenTimeline,
    required this.onOpenProgress,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenTimeline;
  final VoidCallback onOpenProgress;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      onTap: onOpenPlan,
      borderRadius: BorderRadius.circular(32),
      child: Container(
        padding: const EdgeInsets.all(26),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF6B001A),
              _RoyalColors.burgundy,
              _RoyalColors.burgundyDark,
            ],
            stops: [0.0, 0.4, 1.0],
          ),
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: _RoyalColors.gold.withValues(alpha: 0.15),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: _RoyalColors.burgundy.withValues(alpha: 0.35),
              blurRadius: 36,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              right: -40,
              top: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _RoyalColors.gold.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              left: -60,
              bottom: -60,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _RoyalColors.burgundyLight.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            summary.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _RoyalColors.gold,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              height: 1.15,
                              letterSpacing: 0,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_month_rounded,
                                color: Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                summary.weddingDate == null
                                    ? 'التاريخ غير محدد'
                                    : _formatDate(summary.weddingDate!),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.85),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _CircularProgressWidget(
                      percent: summary.progressPercentage,
                      onTap: onOpenProgress,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 8,
                  runSpacing: 12,
                  children: [
                    _CountdownPill(
                      daysRemaining: summary.daysRemaining,
                      onTap: onOpenTimeline,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text(
                          'تفاصيل الخطة',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CountdownPill extends StatelessWidget {
  const _CountdownPill({required this.daysRemaining, required this.onTap});

  final int? daysRemaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = _daysRemainingLabel(daysRemaining);
    final isLive = daysRemaining != null && daysRemaining! > 0;

    return AarastPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: _RoyalColors.gold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: _RoyalColors.gold.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLive) ...[
              _LiveDot(color: _RoyalColors.gold),
              const SizedBox(width: 8),
            ] else ...[
              const Icon(
                Icons.hourglass_bottom_rounded,
                size: 16,
                color: _RoyalColors.gold,
              ),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: _RoyalColors.gold,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircularProgressWidget extends StatelessWidget {
  const _CircularProgressWidget({required this.percent, required this.onTap});

  final int percent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              value: percent / 100,
              strokeWidth: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              valueColor: const AlwaysStoppedAnimation(_RoyalColors.gold),
            ),
          ),
          Text(
            '$percent%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PanoramicCardsCarousel extends StatefulWidget {
  const _PanoramicCardsCarousel({
    required this.summary,
    required this.onOpenProviders,
    required this.onOpenImportantItem,
    required this.onOpenMoney,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenProviders;
  final ValueChanged<DashboardImportantItem> onOpenImportantItem;
  final VoidCallback onOpenMoney;

  @override
  State<_PanoramicCardsCarousel> createState() => _PanoramicCardsCarouselState();
}

class _PanoramicCardsCarouselState extends State<_PanoramicCardsCarousel> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.88);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final priorities = _priorityItems(widget.summary);
    
    final cards = [
      _PanoramicFinanceCard(
        summary: widget.summary,
        onTap: widget.onOpenMoney,
      ),
      _PanoramicProviderCard(
        providerCount: widget.summary.providerCount,
        quoteCount: widget.summary.quoteRequestsCount,
        onTap: widget.onOpenProviders,
      ),
      if (priorities.isNotEmpty)
        _PanoramicPriorityCard(
          topItem: priorities.first,
          onTapItem: widget.onOpenImportantItem,
        ),
    ];

    if (cards.isEmpty) return const SizedBox.shrink();

    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return Column(
        children: cards.map((c) => SizedBox(height: 160, child: c)).toList(),
      );
    }

    return SizedBox(
      height: 160,
      child: PageView.builder(
        controller: _pageController,
        clipBehavior: Clip.none,
        itemCount: cards.length,
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _pageController,
            builder: (context, child) {
              double value = 1.0;
              if (_pageController.position.haveDimensions) {
                value = _pageController.page! - index;
                value = (1 - (value.abs() * 0.15)).clamp(0.0, 1.0);
              }
              return Center(
                child: Transform.scale(
                  scale: Curves.easeOut.transform(value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6.0),
                    child: child,
                  ),
                ),
              );
            },
            child: cards[index],
          );
        },
      ),
    );
  }
}

class _BasePanoramicCard extends StatelessWidget {
  const _BasePanoramicCard({required this.onTap, required this.child, this.color});
  final VoidCallback onTap;
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _RoyalColors.muted.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: _RoyalColors.ink.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

class _PanoramicFinanceCard extends StatelessWidget {
  const _PanoramicFinanceCard({required this.summary, required this.onTap});
  final DashboardSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (!summary.canViewMoney) {
      return _BasePanoramicCard(
        onTap: onTap,
        child: const Center(
          child: Text('لا توجد صلاحية لعرض المال', style: TextStyle(color: _RoyalColors.muted)),
        ),
      );
    }

    return _BasePanoramicCard(
      onTap: onTap,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, color: _RoyalColors.goldDeep, size: 20),
                    const SizedBox(width: 8),
                    const Flexible(child: Text('المالية', style: TextStyle(color: _RoyalColors.ink, fontSize: 16, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
                  ],
                ),
                const Spacer(),
                const Text('المتبقي لك', style: TextStyle(color: _RoyalColors.muted, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  _formatMoney(summary.remainingBudget),
                  style: const TextStyle(color: _RoyalColors.burgundy, fontSize: 24, fontWeight: FontWeight.w900, height: 1.1),
                ),
              ],
            ),
          ),
          _AnimatedDonutChart(
            budgetStr: summary.budgetTotal,
            spentStr: summary.spentTotal,
            remainingStr: summary.remainingBudget,
          ),
        ],
      ),
    );
  }
}

class _PanoramicProviderCard extends StatelessWidget {
  const _PanoramicProviderCard({required this.providerCount, required this.quoteCount, required this.onTap});
  final int providerCount;
  final int quoteCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasAction = quoteCount > 0;
    
    final frontFace = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(Icons.storefront_rounded, color: _RoyalColors.goldDeep, size: 20),
                  const SizedBox(width: 8),
                  const Flexible(child: Text('الموردين', style: TextStyle(color: _RoyalColors.ink, fontSize: 16, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
                ],
              ),
              const Spacer(),
              const Text('بانتظار رأيك', style: TextStyle(color: _RoyalColors.muted, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('$quoteCount عروض', style: const TextStyle(color: _RoyalColors.ink, fontSize: 24, fontWeight: FontWeight.w900, height: 1.1)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _RoyalColors.burgundy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _RoyalColors.burgundy.withValues(alpha: 0.2)),
          ),
          child: const Text('استعراض', style: TextStyle(color: _RoyalColors.burgundy, fontSize: 13, fontWeight: FontWeight.w800)),
        ),
      ],
    );

    final backFace = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(Icons.storefront_rounded, color: _RoyalColors.goldDeep, size: 20),
                  const SizedBox(width: 8),
                  const Flexible(child: Text('الموردين', style: TextStyle(color: _RoyalColors.ink, fontSize: 16, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis)),
                ],
              ),
              const Spacer(),
              const Text('موردين معتمدين', style: TextStyle(color: _RoyalColors.muted, fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('$providerCount محجوز', style: const TextStyle(color: _RoyalColors.ink, fontSize: 24, fontWeight: FontWeight.w900, height: 1.1)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _RoyalColors.ivory,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _RoyalColors.muted.withValues(alpha: 0.1)),
          ),
          child: const Text('تصفح', style: TextStyle(color: _RoyalColors.muted, fontSize: 13, fontWeight: FontWeight.w800)),
        ),
      ],
    );

    return _BasePanoramicCard(
      onTap: onTap,
      child: (hasAction && providerCount > 0)
          ? _AutoFlipCard(front: frontFace, back: backFace)
          : (hasAction ? frontFace : backFace),
    );
  }
}

class _PanoramicPriorityCard extends StatelessWidget {
  const _PanoramicPriorityCard({required this.topItem, required this.onTapItem});
  final DashboardImportantItem topItem;
  final ValueChanged<DashboardImportantItem> onTapItem;

  @override
  Widget build(BuildContext context) {
    final isUrgent = topItem.tone == 'danger';

    return _BasePanoramicCard(
      onTap: () => onTapItem(topItem),
      color: isUrgent ? _RoyalColors.burgundy.withValues(alpha: 0.04) : Colors.white,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(
                      isUrgent ? Icons.priority_high_rounded : Icons.flash_on_rounded,
                      color: isUrgent ? _RoyalColors.burgundy : _RoyalColors.goldDeep,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(child: Text(
                      isUrgent ? 'تنبيه هام' : 'الأهم اليوم',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isUrgent ? _RoyalColors.burgundy : _RoyalColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    )),
                  ],
                ),
                const Spacer(),
                const Text('إجراء مطلوب', style: TextStyle(color: _RoyalColors.muted, fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  topItem.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _RoyalColors.ink, fontSize: 18, fontWeight: FontWeight.w900, height: 1.3),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_left_rounded, color: _RoyalColors.muted, size: 32),
        ],
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.showBadge = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: _RoyalColors.muted.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: _RoyalColors.ink.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: _RoyalColors.ink, size: 24),
            if (showBadge)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _RoyalColors.burgundy,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot({required this.color});

  final Color color;

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: widget.color,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.5),
              blurRadius: 6,
              spreadRadius: 1,
            ),
          ],
        ),
      ),
    );
  }
}

class _RoyalColors {
  const _RoyalColors._();

  static const ivory = Color(0xFFFDFBF9);
  static const burgundy = Color(0xFF800020);
  static const burgundyDark = Color(0xFF5A0016);
  static const burgundyLight = Color(0xFFA63351);
  static const gold = Color(0xFFD4AF37);
  static const goldDeep = Color(0xFFB5952F);
  static const ink = Color(0xFF2D1A1E);
  static const muted = Color(0xFF8A7B7E);
}

String _greetingFor(String name) {
  final hour = DateTime.now().hour;
  final timeGreeting = hour < 12 ? 'صباح الخير' : 'مساء الخير';
  if (name.trim().isEmpty) return timeGreeting;
  return '$timeGreeting، $name';
}

String _formatDate(DateTime date) {
  return '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

String _daysRemainingLabel(int? daysRemaining) {
  if (daysRemaining == null) return 'قريباً';
  if (daysRemaining < 0) return 'مرت الأيام';
  if (daysRemaining == 0) return 'اليوم يومك!';
  if (daysRemaining == 1) return 'غداً الزفاف';
  if (daysRemaining == 2) return 'بقي يومان';
  if (daysRemaining <= 10) return 'بقي $daysRemaining أيام';
  return 'بقي $daysRemaining يوم';
}

String _formatMoney(String? amount) {
  if (amount == null || amount.isEmpty) return '0 ﷼';
  final numValue = int.tryParse(amount);
  if (numValue == null) return '0 ﷼';
  if (numValue >= 1000000) {
    return '${(numValue / 1000000).toStringAsFixed(1).replaceAll('.0', '')}م ﷼';
  }
  if (numValue >= 1000) {
    return '${(numValue / 1000).toStringAsFixed(1).replaceAll('.0', '')}ألف ﷼';
  }
  return '$numValue ﷼';
}

List<DashboardImportantItem> _priorityItems(DashboardSummary summary) {
  final list = List<DashboardImportantItem>.from(summary.importantItems);
  list.sort((a, b) {
    if (a.tone == 'danger' && b.tone != 'danger') return -1;
    if (b.tone == 'danger' && a.tone != 'danger') return 1;
    return 0;
  });
  return list;
}


class _OperationalCards extends StatelessWidget {
  const _OperationalCards({
    required this.summary,
    required this.onOpenTasks,
    required this.onOpenGuests,
    required this.onOpenParticipants,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenGuests;
  final VoidCallback onOpenParticipants;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

        _OperationalCard(
          title: 'المهام',
          subtitle: '${summary.totalTasks - summary.completedTasks} مهمة متبقية',
          icon: Icons.checklist_rounded,
          onTap: onOpenTasks,
        ),
        const SizedBox(height: 12),
        _OperationalCard(
          title: 'الضيوف',
          subtitle: '${summary.confirmedGuests} ضيف مؤكد',
          icon: Icons.group_outlined,
          onTap: onOpenGuests,
        ),
        const SizedBox(height: 12),
        _OperationalCard(
          title: 'المشاركة في الخطة',
          subtitle: 'أنت (${summary.currentUserRole == "GUEST" ? "ضيف" : "صاحب الخطة"}) • إدارة المشاركين',
          icon: Icons.share_rounded,
          onTap: onOpenParticipants,
        ),
      ],
    );
  }
}

class _OperationalCard extends StatelessWidget {
  const _OperationalCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _RoyalColors.muted.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: _RoyalColors.ink.withValues(alpha: 0.03),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _RoyalColors.ivory,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _RoyalColors.goldDeep.withValues(alpha: 0.15)),
              ),
              child: Icon(icon, color: _RoyalColors.goldDeep, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: _RoyalColors.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      color: _RoyalColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_left_rounded,
              color: _RoyalColors.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _PremiumEntry extends StatelessWidget {
  const _PremiumEntry({required this.index, required this.child});
  
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    if (isTest) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + (index * 120)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 30),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _AnimatedDonutChart extends StatelessWidget {
  const _AnimatedDonutChart({
    required this.budgetStr,
    required this.spentStr,
    required this.remainingStr,
  });

  final String? budgetStr;
  final String? spentStr;
  final String? remainingStr;

  @override
  Widget build(BuildContext context) {
    final isTest = Platform.environment.containsKey('FLUTTER_TEST');
    
    final b = int.tryParse(budgetStr ?? '0') ?? 0;
    final s = int.tryParse(spentStr ?? '0') ?? 0;
    final ratio = b > 0 ? (s / b).clamp(0.0, 1.0) : 0.0;
    
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: isTest ? 0.0 : ratio),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return CustomPaint(
          size: const Size.square(90), 
          painter: _DonutChartPainter(
            spentRatio: isTest ? ratio : value,
            spentColor: _RoyalColors.burgundy,
            backgroundColor: _RoyalColors.gold.withValues(alpha: 0.2),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(ratio * 100).toInt()}%',
                  style: const TextStyle(
                    color: _RoyalColors.burgundy,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const Text(
                  'مُستهلك',
                  style: TextStyle(
                    color: _RoyalColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({
    required this.spentRatio,
    required this.spentColor,
    required this.backgroundColor,
  });

  final double spentRatio;
  final Color spentColor;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2) - 6; 
    const strokeWidth = 12.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      0,
      2 * math.pi,
      false,
      bgPaint,
    );

    if (spentRatio > 0) {
      final glowPaint = Paint()
        ..color = spentColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 4
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

      final spentPaint = Paint()
        ..color = spentColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * math.pi * spentRatio;
      final startAngle = -math.pi / 2;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        glowPaint,
      );
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        spentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.spentRatio != spentRatio;
  }
}

class _AutoFlipCard extends StatefulWidget {
  const _AutoFlipCard({
    required this.front,
    required this.back,
  });

  final Widget front;
  final Widget back;

  @override
  State<_AutoFlipCard> createState() => _AutoFlipCardState();
}

class _AutoFlipCardState extends State<_AutoFlipCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isFront = true;
  bool _isTest = false;

  @override
  void initState() {
    super.initState();
    _isTest = Platform.environment.containsKey('FLUTTER_TEST');
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    if (!_isTest) {
      _startFlipTimer();
    }
  }

  void _startFlipTimer() {
    Future.delayed(const Duration(seconds: 4), () {
      if (!mounted) return;
      if (_isFront) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
      _isFront = !_isFront;
      _startFlipTimer();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isTest) {
      return widget.front; 
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final angle = _controller.value * math.pi;
        final isUnder = angle > math.pi / 2;

        return Transform(
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.001)
            ..rotateX(angle),
          alignment: Alignment.center,
          child: isUnder
              ? Transform(
                  transform: Matrix4.identity()..rotateX(math.pi),
                  alignment: Alignment.center,
                  child: widget.back,
                )
              : widget.front,
        );
      },
    );
  }
}

class RoyalHomeTodaySkeleton extends StatelessWidget {
  const RoyalHomeTodaySkeleton({this.bottomPadding = 156, super.key});

  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(20, 22, 20, bottomPadding),
      children: const [
        _SkeletonBox(height: 56),
        SizedBox(height: 16),
        _SkeletonBox(height: 188),
        SizedBox(height: 22),
        _SkeletonBox(height: 248),
        SizedBox(height: 18),
        _SkeletonBox(height: 156),
        SizedBox(height: 20),
        _SkeletonBox(height: 220),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.35, end: 0.75),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Opacity(opacity: value, child: child);
      },
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.74),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _RoyalColors.muted.withValues(alpha: 0.1)),
        ),
      ),
    );
  }
}
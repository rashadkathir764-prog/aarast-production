// ignore_for_file: unused_element

import 'dart:io' show Platform;
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
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
    this.onAddExpense,
    this.bottomPadding = 156,
    this.notice,
    this.personaHeadline,
    this.personaSupportText,
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
  final VoidCallback? onAddExpense;
  final double bottomPadding;
  final Widget? notice;
  final String? personaHeadline;
  final String? personaSupportText;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: _RoyalColors.ivory),
      child: ListView(
        key: ValueKey('royal-home-${summary.planId}'),
        padding: EdgeInsets.fromLTRB(18, 18, 18, bottomPadding),
        children: [
          _PremiumEntry(
            index: 0,
            child: _PremiumHeader(
              summary: summary,
              userName: userName,
              unreadCount: summary.unreadNotificationsCount,
              onNotifications: onNotifications,
              onProfile: onProfile,
            ),
          ),
          if (notice != null) ...[
            const SizedBox(height: 12),
            _PremiumEntry(index: 1, child: notice!),
          ],
          const SizedBox(height: 18),
          _PremiumEntry(
            index: notice != null ? 2 : 1,
            child: _CompactPlanHeroCard(
              summary: summary,
              personaHeadline: personaHeadline,
              personaSupportText: personaSupportText,
              onOpenPlan: onOpenPlan,
            ),
          ),
          const SizedBox(height: 16),
          _PremiumEntry(
            index: notice != null ? 3 : 2,
            child: _ImportantNowCard(
              summary: summary,
              onOpenImportantItem: onOpenImportantItem,
            ),
          ),
          const SizedBox(height: 14),
          _PremiumEntry(
            index: notice != null ? 4 : 3,
            child: _MoneySummaryCard(
              summary: summary,
              onOpenMoney: onOpenMoney,
              onAddExpense: onAddExpense,
            ),
          ),
          const SizedBox(height: 14),
          _PremiumEntry(
            index: notice != null ? 5 : 4,
            child: _QuickOverviewGrid(
              summary: summary,
              onOpenTasks: onOpenTasks,
              onOpenGuests: onOpenGuests,
              onOpenProviders: onOpenProviders,
              onOpenMoney: onOpenMoney,
            ),
          ),
          const SizedBox(height: 14),
          _PremiumEntry(
            index: notice != null ? 6 : 5,
            child: _SharingUpdatesRow(
              summary: summary,
              onOpenParticipants: onOpenParticipants,
              onOpenImportantItem: onOpenImportantItem,
            ),
          ),
        ],
      ),
    );
  }
}

class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader({
    required this.summary,
    required this.userName,
    required this.unreadCount,
    required this.onNotifications,
    required this.onProfile,
  });

  final DashboardSummary summary;
  final String userName;
  final int unreadCount;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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
              const SizedBox(height: 2),
              const Text(
                'اعّرست',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: _RoyalColors.gold,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              _StatePill(label: summary.dataStateLabel),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _CircleIconButton(
          key: const ValueKey('royal-home-notifications-button'),
          icon: Icons.notifications_none_rounded,
          onTap: onNotifications,
          badgeCount: unreadCount,
        ),
        const SizedBox(width: 8),
        _CircleIconButton(
          key: const ValueKey('royal-home-profile-button'),
          icon: Icons.person_outline_rounded,
          onTap: onProfile,
        ),
      ],
    );
  }
}

class _CompactPlanHeroCard extends StatelessWidget {
  const _CompactPlanHeroCard({
    required this.summary,
    required this.onOpenPlan,
    this.personaHeadline,
    this.personaSupportText,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenPlan;
  final String? personaHeadline;
  final String? personaSupportText;

  @override
  Widget build(BuildContext context) {
    int? days;
    int? hours;
    if (summary.weddingDate != null) {
      final now = DateTime.now();
      final diff = summary.weddingDate!.difference(now);
      if (diff.isNegative) {
        days = 0;
        hours = 0;
      } else {
        days = diff.inDays;
        hours = diff.inHours % 24;
      }
    }

    final String locationText = _shortLocation(summary) ?? 'المكان غير محدد';

    return AarastPressable(
      onTap: onOpenPlan,
      borderRadius: BorderRadius.circular(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_hasText(personaHeadline)) ...[
                        Text(
                          personaHeadline!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      Text(
                        summary.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _RoyalColors.gold,
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.calendar_month_rounded, color: Colors.white.withValues(alpha: 0.5), size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              summary.weddingDate == null
                                  ? 'التاريخ غير محدد'
                                  : _formatDate(summary.weddingDate!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_rounded, color: Colors.white.withValues(alpha: 0.5), size: 14),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              locationText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (days != null) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Icon(Icons.hourglass_bottom_rounded, color: const Color(0xFF00FF66).withValues(alpha: 0.7), size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'متبقي $days يوم و $hours ساعة',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF00FF66),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _CircularProgressWidget(percent: summary.progressPercentage),
              ],
            ),
          ),
        ),
      ),
    );
  }
}



class _HeroMetaLine extends StatelessWidget {
  const _HeroMetaLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeroCta extends StatelessWidget {
  const _HeroCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(99),
          border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'متابعة الخطة',
              style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 0,
              ),
            ),
            SizedBox(width: 5),
            Icon(Icons.arrow_back_rounded, color: Colors.white, size: 16),
          ],
        ),
      ),
    );
  }
}

class _StatePill extends StatelessWidget {
  const _StatePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _RoyalColors.gold.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: _RoyalColors.gold.withValues(alpha: 0.15),
        ),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: _RoyalColors.gold,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _PremiumHeroCard extends StatelessWidget {
  const _PremiumHeroCard({
    required this.summary,
    required this.onOpenPlan,
    required this.onOpenTimeline,
    required this.onOpenProgress,
    required this.personaHeadline,
    required this.personaSupportText,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenPlan;
  final VoidCallback? onOpenTimeline;
  final VoidCallback? onOpenProgress;
  final String? personaHeadline;
  final String? personaSupportText;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      onTap: onOpenPlan,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
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
          borderRadius: BorderRadius.circular(24),
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
                          if (_hasText(personaHeadline)) ...[
                            Text(
                              personaHeadline!.trim(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.9),
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                height: 1.25,
                                letterSpacing: 0,
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
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
                          if (_hasText(personaSupportText)) ...[
                            const SizedBox(height: 8),
                            Text(
                              personaSupportText!.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.78),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                                letterSpacing: 0,
                              ),
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_month_rounded,
                                color: Colors.white70,
                                size: 14,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  summary.weddingDate == null
                                      ? 'التاريخ غير محدد'
                                      : _formatDate(summary.weddingDate!),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (_hasText(summary.city)) ...[
                            const SizedBox(height: 7),
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_rounded,
                                  color: Colors.white70,
                                  size: 14,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    summary.city!.trim(),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(
                                        alpha: 0.85,
                                      ),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 9),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.16),
                                ),
                              ),
                              child: Text(
                                summary.dataStateLabel,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.88),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    _CircularProgressWidget(
                      percent: summary.progressPercentage,
                      onTap: onOpenProgress ?? onOpenPlan,
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
                      onTap: onOpenTimeline ?? onOpenPlan,
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
  const _CountdownPill({required this.daysRemaining, this.onTap});

  final int? daysRemaining;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final label = _daysRemainingLabel(daysRemaining);
    final isLive = daysRemaining != null && daysRemaining! > 0;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
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
              size: 15,
              color: _RoyalColors.gold,
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: _RoyalColors.gold,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 1,
                letterSpacing: 0,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return pill;
    return AarastPressable(
      onTap: onTap!,
      borderRadius: BorderRadius.circular(99),
      child: pill,
    );
  }
}

class _CircularProgressWidget extends StatelessWidget {
  const _CircularProgressWidget({required this.percent, this.onTap});

  final int percent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final progress = Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00FF66).withValues(alpha: 0.3),
                blurRadius: 12,
              )
            ],
          ),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: percent / 100),
          duration: const Duration(milliseconds: 1500),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return SizedBox(
              width: 58,
              height: 58,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation(Color(0xFF00FF66)),
                strokeCap: StrokeCap.round,
              ),
            );
          },
        ),
        Text(
          '$percent%',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 0,
          ),
        ),
      ],
    );
    if (onTap == null) return progress;
    return AarastPressable(
      onTap: onTap!,
      borderRadius: BorderRadius.circular(28),
      child: progress,
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
  State<_PanoramicCardsCarousel> createState() =>
      _PanoramicCardsCarouselState();
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
      _PanoramicFinanceCard(summary: widget.summary, onTap: widget.onOpenMoney),
      _PanoramicProviderCard(
        pendingCount:
            widget.summary.pendingQuoteRequests +
                    widget.summary.receivedQuotes >
                0
            ? widget.summary.pendingQuoteRequests
            : widget.summary.quoteRequestsCount,
        receivedCount: widget.summary.receivedQuotes,
        acceptedCount: widget.summary.acceptedProviders > 0
            ? widget.summary.acceptedProviders
            : widget.summary.providerCount,
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
  const _BasePanoramicCard({
    required this.onTap,
    required this.child,
    this.color,
  });
  final VoidCallback onTap;
  final Widget child;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: color ?? const Color(0x99191919),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: child,
          ),
        ),
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
          child: Text(
            'لا توجد صلاحية لعرض المال',
            style: TextStyle(color: _RoyalColors.muted),
          ),
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
                    Icon(
                      Icons.account_balance_wallet_rounded,
                      color: _RoyalColors.goldDeep,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'المالية',
                        style: TextStyle(
                          color: _RoyalColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Text(
                  'المتبقي لك',
                  style: TextStyle(
                    color: _RoyalColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                _AnimatedMoneyText(
                  value: summary.remainingBudget ?? '0',
                  style: const TextStyle(
                    color: _RoyalColors.burgundy,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
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
  const _PanoramicProviderCard({
    required this.pendingCount,
    required this.receivedCount,
    required this.acceptedCount,
    required this.onTap,
  });
  final int pendingCount;
  final int receivedCount;
  final int acceptedCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasAction = receivedCount > 0 || pendingCount > 0;
    final actionLabel = receivedCount > 0
        ? 'بانتظار قرارك'
        : 'بانتظار رد المورد';
    final actionValue = receivedCount > 0
        ? '$receivedCount عروض وصلت'
        : '$pendingCount طلبات معلقة';

    final frontFace = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.storefront_rounded,
                    color: _RoyalColors.goldDeep,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'الموردين',
                      style: TextStyle(
                        color: _RoyalColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Text(
                actionLabel,
                style: TextStyle(
                  color: _RoyalColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                actionValue,
                style: const TextStyle(
                  color: _RoyalColors.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _RoyalColors.burgundy.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _RoyalColors.burgundy.withValues(alpha: 0.2),
            ),
          ),
          child: const Text(
            'استعراض',
            style: TextStyle(
              color: _RoyalColors.burgundy,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
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
                  Icon(
                    Icons.storefront_rounded,
                    color: _RoyalColors.goldDeep,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Flexible(
                    child: Text(
                      'الموردين',
                      style: TextStyle(
                        color: _RoyalColors.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              const Text(
                'موردون مرتبطون بالخطة',
                style: TextStyle(
                  color: _RoyalColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$acceptedCount مورد مقبول',
                style: const TextStyle(
                  color: _RoyalColors.ink,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _RoyalColors.ivory,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _RoyalColors.muted.withValues(alpha: 0.1),
            ),
          ),
          child: const Text(
            'تصفح',
            style: TextStyle(
              color: _RoyalColors.muted,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );

    return _BasePanoramicCard(
      onTap: onTap,
      child: (hasAction && acceptedCount > 0)
          ? _AutoFlipCard(front: frontFace, back: backFace)
          : (hasAction ? frontFace : backFace),
    );
  }
}

class _PanoramicPriorityCard extends StatelessWidget {
  const _PanoramicPriorityCard({
    required this.topItem,
    required this.onTapItem,
  });
  final DashboardImportantItem topItem;
  final ValueChanged<DashboardImportantItem> onTapItem;

  @override
  Widget build(BuildContext context) {
    final isUrgent = topItem.tone == 'danger';

    return _BasePanoramicCard(
      onTap: () => onTapItem(topItem),
      color: isUrgent
          ? _RoyalColors.burgundy.withValues(alpha: 0.04)
          : Colors.white,
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
                      isUrgent
                          ? Icons.priority_high_rounded
                          : Icons.flash_on_rounded,
                      color: isUrgent
                          ? _RoyalColors.burgundy
                          : _RoyalColors.goldDeep,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isUrgent ? 'تنبيه هام' : 'الأهم اليوم',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isUrgent
                              ? _RoyalColors.burgundy
                              : _RoyalColors.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                const Text(
                  'إجراء مطلوب',
                  style: TextStyle(
                    color: _RoyalColors.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  topItem.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _RoyalColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_left_rounded,
            color: _RoyalColors.muted,
            size: 32,
          ),
        ],
      ),
    );
  }
}

class _DashboardSectionCard extends StatelessWidget {
  const _DashboardSectionCard({
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0x99191919),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: _RoyalColors.goldDeep, size: 20),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _RoyalColors.ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          if (_hasText(subtitle)) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!.trim(),
              style: const TextStyle(
                color: _RoyalColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
                letterSpacing: 0,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    )));

    if (onTap == null) return content;
    return AarastPressable(
      onTap: onTap!,
      borderRadius: BorderRadius.circular(22),
      child: content,
    );
  }
}

class _ImportantNowCard extends StatelessWidget {
  const _ImportantNowCard({
    required this.summary,
    required this.onOpenImportantItem,
  });

  final DashboardSummary summary;
  final ValueChanged<DashboardImportantItem> onOpenImportantItem;

  @override
  Widget build(BuildContext context) {
    final items = _priorityItems(summary).take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Text(
            'مهام النانو السريعة',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (items.isEmpty)
          const _EmptySectionText(text: 'كل شيء هادئ الآن.')
        else
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              clipBehavior: Clip.none,
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final item = items[index];
                final isUrgent = item.tone == 'danger';
                return AarastPressable(
                  onTap: () => onOpenImportantItem(item),
                  borderRadius: BorderRadius.circular(16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        width: 100,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isUrgent ? const Color(0x33FF2A55) : const Color(0x3300FF66),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isUrgent ? const Color(0x66FF2A55) : const Color(0x6600FF66),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _iconForImportantItem(item),
                              color: isUrgent ? const Color(0xFFFF2A55) : const Color(0xFF00FF66),
                              size: 20,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              item.title,
                              maxLines: 2,
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                height: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _MoneySummaryCard extends StatelessWidget {
  const _MoneySummaryCard({
    required this.summary,
    required this.onOpenMoney,
    this.onAddExpense,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenMoney;
  final VoidCallback? onAddExpense;

  @override
  Widget build(BuildContext context) {
    if (!summary.canViewMoney) {
      return _DashboardSectionCard(
        title: 'المال',
        icon: Icons.lock_outline_rounded,
        onTap: onOpenMoney,
        child: const _EmptySectionText(
          text: 'البيانات المالية خاصة ولا تظهر لهذا الدور.',
        ),
      );
    }

    return _DashboardSectionCard(
      title: 'ملخص المال',
      subtitle: summary.nextInstallmentDue == null
          ? null
          : 'القسط القادم: ${_formatMoney(summary.nextInstallmentDue!.amount)}',
      icon: Icons.account_balance_wallet_rounded,
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  children: [
                    _CompactMoneyRow(
                      label: 'الميزانية',
                      value: summary.totalBudgetForDisplay,
                    ),
                    const SizedBox(height: 10),
                    _CompactMoneyRow(
                      label: 'المصروف',
                      value: summary.spentTotalForDisplay,
                    ),
                    const SizedBox(height: 10),
                    _CompactMoneyRow(
                      label: 'المتبقي',
                      value: summary.remainingBudgetForDisplay,
                      isHighlight: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _AnimatedDonutChart(
                budgetStr: summary.budgetTotal,
                spentStr: summary.spentTotal,
                remainingStr: summary.remainingBudget,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SmallCommandButton(
                  label: 'عرض التفاصيل',
                  icon: Icons.arrow_back_rounded,
                  onTap: onOpenMoney,
                ),
              ),
              if (onAddExpense != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: _SmallCommandButton(
                    label: 'إضافة مصروف',
                    icon: Icons.add_rounded,
                    onTap: onAddExpense!,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactMoneyRow extends StatelessWidget {
  const _CompactMoneyRow({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  final String label;
  final String? value;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _AnimatedMoneyText(
              value: value ?? '0',
              style: TextStyle(
                color: isHighlight ? const Color(0xFF00FF66) : Colors.white,
                fontSize: isHighlight ? 16 : 14,
                fontWeight: FontWeight.w900,
                shadows: isHighlight
                    ? [const Shadow(color: Color(0x6600FF66), blurRadius: 10)]
                    : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickOverviewGrid extends StatelessWidget {
  const _QuickOverviewGrid({
    required this.summary,
    required this.onOpenTasks,
    required this.onOpenGuests,
    required this.onOpenProviders,
    required this.onOpenMoney,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenGuests;
  final VoidCallback onOpenProviders;
  final VoidCallback onOpenMoney;

  @override
  Widget build(BuildContext context) {
    final providerValue = summary.receivedQuotes > 0
        ? summary.receivedQuotes
        : summary.quoteRequestsCount;
    final tiles = [
      _OverviewTile(
        title: 'المهام',
        value: '${summary.completedTasks}/${summary.totalTasks}',
        subtitle: summary.overdueTasks > 0
            ? '${summary.overdueTasks} متأخرة'
            : '${summary.todayTasks} اليوم',
        icon: Icons.checklist_rounded,
        onTap: onOpenTasks,
      ),
      _OverviewTile(
        title: 'الضيوف',
        value: '${summary.guestCount}',
        subtitle: summary.incompleteGuestsCount > 0
            ? '${summary.incompleteGuestsCount} ناقص'
            : '${summary.confirmedGuests} مؤكد',
        icon: Icons.group_outlined,
        onTap: onOpenGuests,
      ),
      _OverviewTile(
        title: 'العروض',
        value: '$providerValue',
        subtitle: summary.pendingQuoteRequests > 0
            ? '${summary.pendingQuoteRequests} قيد المتابعة'
            : '${summary.acceptedProviders} مقبول',
        icon: Icons.request_quote_outlined,
        onTap: onOpenProviders,
      ),
      _OverviewTile(
        title: 'الديون والأقساط',
        value: _formatMoney(summary.debtTotalForDisplay),
        subtitle: summary.nextInstallmentDue != null
            ? 'يوجد قسط قادم'
            : 'لا توجد أقساط',
        icon: Icons.account_balance_rounded,
        onTap: onOpenMoney,
      ),
      if (summary.acceptedProviders > 0)
        _OverviewTile(
          title: 'الموردون',
          value: '${summary.acceptedProviders}',
          subtitle: 'مقبولون في الخطة',
          icon: Icons.storefront_rounded,
          onTap: onOpenProviders,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Icon(
                Icons.dashboard_customize_rounded,
                color: Colors.white.withValues(alpha: 0.6),
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'نظرة سريعة',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 106,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: tiles.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) => tiles[index],
          ),
        ),
      ],
    );
  }
}

class _SharingUpdatesRow extends StatelessWidget {
  const _SharingUpdatesRow({
    required this.summary,
    required this.onOpenParticipants,
    required this.onOpenImportantItem,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenParticipants;
  final ValueChanged<DashboardImportantItem> onOpenImportantItem;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sharing = _MiniDashboardCard(
          title: 'مشاركة الخطة',
          icon: Icons.share_rounded,
          subtitle: _sharingSubtitle(summary),
          onTap: onOpenParticipants,
          child: _MiniCardText(_dashboardRoleLabel(summary.currentUserRole)),
        );
        final updates = _MiniDashboardCard(
          title: 'آخر التحديثات',
          icon: Icons.history_rounded,
          subtitle: _latestUpdatesSubtitle(summary),
          child: _LatestUpdatesMiniList(
            items: summary.recentActivity.take(2).toList(),
            onOpenImportantItem: onOpenImportantItem,
          ),
        );
        if (constraints.maxWidth < 340) {
          return Column(
            children: [sharing, const SizedBox(height: 10), updates],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: sharing),
            const SizedBox(width: 10),
            Expanded(child: updates),
          ],
        );
      },
    );
  }
}

class _MiniDashboardCard extends StatelessWidget {
  const _MiniDashboardCard({
    required this.title,
    required this.icon,
    required this.subtitle,
    required this.child,
    this.onTap,
  });

  final String title;
  final IconData icon;
  final String subtitle;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          constraints: const BoxConstraints(minHeight: 142),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0x99191919),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: _RoyalColors.goldDeep, size: 18),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _RoyalColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _RoyalColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.35,
              letterSpacing: 0,
            ),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    )));
    if (onTap == null) return content;
    return AarastPressable(
      onTap: onTap!,
      borderRadius: BorderRadius.circular(20),
      child: content,
    );
  }
}

class _MiniCardText extends StatelessWidget {
  const _MiniCardText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: _RoyalColors.burgundy,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        letterSpacing: 0,
      ),
    );
  }
}

class _LatestUpdatesMiniList extends StatelessWidget {
  const _LatestUpdatesMiniList({
    required this.items,
    required this.onOpenImportantItem,
  });

  final List<DashboardImportantItem> items;
  final ValueChanged<DashboardImportantItem> onOpenImportantItem;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _MiniCardText('لا توجد تحديثات بعد');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          AarastPressable(
            onTap: () => onOpenImportantItem(item),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    _iconForImportantItem(item),
                    color: _toneColor(item.tone),
                    size: 16,
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _RoyalColors.ink,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({
    required this.summary,
    required this.onOpenImportantItem,
  });

  final DashboardSummary summary;
  final ValueChanged<DashboardImportantItem> onOpenImportantItem;

  @override
  Widget build(BuildContext context) {
    final activity = summary.recentActivity.take(3).toList();
    final hasMore = summary.recentActivity.length > activity.length;
    return _DashboardSectionCard(
      title: 'آخر التحديثات',
      icon: Icons.history_rounded,
      child: activity.isEmpty
          ? const _EmptySectionText(
              text:
                  'لا توجد تحديثات بعد. أضف ضيفاً أو مهمة أو مصروفاً ليظهر هنا.',
            )
          : Column(
              children: [
                for (final item in activity)
                  _CompactLineItem(
                    icon: _iconForImportantItem(item),
                    title: item.title,
                    subtitle: item.subtitle,
                    tone: item.tone,
                    onTap: () => onOpenImportantItem(item),
                  ),
                if (hasMore)
                  const _EmptySectionText(text: 'عرض الكل من القسم المناسب'),
              ],
            ),
    );
  }
}

class _SharingPermissionsCard extends StatelessWidget {
  const _SharingPermissionsCard({
    required this.summary,
    required this.onOpenParticipants,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenParticipants;

  @override
  Widget build(BuildContext context) {
    return _DashboardSectionCard(
      title: 'المشاركة والصلاحيات',
      subtitle: summary.isLocalOnly
          ? 'سجل الدخول لمشاركة الخطة وحفظ الصلاحيات.'
          : '${summary.participantCount} مشارك • ${summary.pendingInvites} دعوات معلقة',
      icon: Icons.share_rounded,
      onTap: onOpenParticipants,
      child: _CompactLineItem(
        icon: Icons.verified_user_outlined,
        title: _dashboardRoleLabel(summary.currentUserRole),
        subtitle: summary.isLocalOnly
            ? 'مشاركة الخطة تحتاج حساباً'
            : 'إدارة المشاركين والصلاحيات',
        tone: 'info',
        onTap: onOpenParticipants,
      ),
    );
  }
}

class _SyncStatusCard extends StatelessWidget {
  const _SyncStatusCard({required this.summary});

  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return _DashboardSectionCard(
      title: 'حالة الحفظ',
      icon: summary.isLocalOnly
          ? Icons.phone_iphone_rounded
          : Icons.cloud_done_rounded,
      child: Text(
        summary.isLocalOnly
            ? 'الخطة محفوظة محلياً على هذا الجهاز. سجل الدخول للمزامنة والمشاركة.'
            : 'الخطة مرتبطة بالحساب وتعرض آخر ملخص متاح من الخادم.',
        style: const TextStyle(
          color: _RoyalColors.muted,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1.45,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _SmartWarningsCard extends StatelessWidget {
  const _SmartWarningsCard({
    required this.summary,
    required this.onOpenPlan,
    required this.onOpenMoney,
    required this.onOpenTasks,
    required this.onOpenGuests,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenPlan;
  final VoidCallback onOpenMoney;
  final VoidCallback onOpenTasks;
  final VoidCallback onOpenGuests;

  @override
  Widget build(BuildContext context) {
    final warnings = _smartWarnings(summary).take(4).toList();
    return _DashboardSectionCard(
      title: 'تنبيهات ذكية',
      icon: Icons.warning_amber_rounded,
      child: Column(
        children: [
          for (final warning in warnings)
            _CompactLineItem(
              icon: warning.severity == 'DANGER'
                  ? Icons.priority_high_rounded
                  : Icons.info_outline_rounded,
              title: _warningDashboardCopy(warning),
              subtitle: warning.count == null
                  ? 'راجع الخطة'
                  : '${warning.count} عنصر',
              tone: warning.severity == 'DANGER' ? 'danger' : 'warning',
              onTap: () => _openWarning(
                warning,
                onOpenPlan: onOpenPlan,
                onOpenMoney: onOpenMoney,
                onOpenTasks: onOpenTasks,
                onOpenGuests: onOpenGuests,
              ),
            ),
        ],
      ),
    );
  }
}

class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: _RoyalColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0,
              ),
            ),
          ),
          _AnimatedMoneyText(
            value: value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
              letterSpacing: 0,
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTile extends StatelessWidget {
  const _OverviewTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 145,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Icon(icon, color: _RoyalColors.goldDeep, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactLineItem extends StatelessWidget {
  const _CompactLineItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tone,
    required this.onTap,
    // ignore: unused_element_parameter
    this.actionLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String tone;
  final VoidCallback onTap;
  final String? actionLabel;

  @override
  Widget build(BuildContext context) {
    final color = _toneColor(tone);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AarastPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.fade,
                    style: const TextStyle(
                      color: _RoyalColors.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _RoyalColors.muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                ],
              ),
            ),
            if (_hasText(actionLabel))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  actionLabel!.trim(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
              )
            else
              const Icon(Icons.chevron_left_rounded, color: _RoyalColors.muted),
          ],
        ),
      ),
    );
  }
}

class _EmptySectionText extends StatelessWidget {
  const _EmptySectionText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _RoyalColors.muted,
        fontSize: 13,
        fontWeight: FontWeight.w700,
        height: 1.45,
        letterSpacing: 0,
      ),
    );
  }
}

class _SmallCommandButton extends StatelessWidget {
  const _SmallCommandButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AarastPressable(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _RoyalColors.burgundy,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 17),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarningPill extends StatelessWidget {
  const _WarningPill({required this.text, required this.danger});

  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? _RoyalColors.burgundy : _RoyalColors.goldDeep;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        maxLines: 2,
        overflow: TextOverflow.fade,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.badgeCount = 0,
    super.key,
  });

  final IconData icon;
  final VoidCallback onTap;
  final int badgeCount;

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
            if (badgeCount > 0)
              Positioned(
                top: 7,
                right: 6,
                child: Container(
                  constraints: const BoxConstraints(
                    minWidth: 18,
                    minHeight: 18,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: _RoyalColors.burgundy,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    badgeCount > 99 ? '99+' : '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0,
                    ),
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
      opacity: Tween<double>(
        begin: 0.4,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut)),
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

  static const ivory = AppTheme.dCard;
  static const burgundy = AppTheme.deepBurgundy;
  static const burgundyDark = AppTheme.dMaroonDeep;
  static const burgundyLight = AppTheme.dMaroonBright;
  static const gold = AppTheme.warmGold;
  static const goldDeep = AppTheme.dGoldDeep;
  static const ink = AppTheme.dInk;
  static const muted = AppTheme.dMuted;
}

String _greetingFor(String name) {
  final hour = DateTime.now().hour;
  final timeGreeting = hour < 12 ? 'صباح الخير' : 'مساء الخير';
  if (name.trim().isEmpty) return timeGreeting;
  return '$timeGreeting، $name';
}

bool _hasText(String? value) {
  return value != null && value.trim().isNotEmpty;
}

String _formatDate(DateTime date) {
  return formatArabicDate(date);
}

String? _shortLocation(DashboardSummary summary) {
  final fullLabel = summary.location?['fullLabel']?.toString().trim();
  if (_hasText(fullLabel)) {
    final parts = fullLabel!
        .split(RegExp(r'\s*-\s*'))
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.length >= 2) return '${parts[0]} - ${parts[1]}';
    return fullLabel;
  }
  final city = summary.city?.trim();
  if (!_hasText(city)) return null;
  final parts = city!
      .split(RegExp(r'\s*-\s*'))
      .where((part) => part.trim().isNotEmpty)
      .toList();
  if (parts.length >= 2) return '${parts[0]} - ${parts[1]}';
  return city;
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
  final cleaned = amount?.replaceAll(',', '').trim();
  if (cleaned == null || cleaned.isEmpty) return '0 ر.ي';
  final value = num.tryParse(cleaned);
  if (value == null) return '0 ر.ي';
  if (value.abs() >= 1000000) {
    return '${_trimDecimal(value / 1000000)}م ر.ي';
  }
  return '${_formatWholeNumber(value)} ر.ي';
}

String _trimDecimal(num value) {
  return value.toStringAsFixed(1).replaceAll('.0', '');
}

String _formatWholeNumber(num value) {
  final rounded = value.round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < rounded.length; i++) {
    final remaining = rounded.length - i;
    buffer.write(rounded[i]);
    if (remaining > 1 && remaining % 3 == 1) buffer.write(',');
  }
  return buffer.toString();
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

IconData _iconForImportantItem(DashboardImportantItem item) {
  if (item.type.contains('TASK')) return Icons.checklist_rounded;
  if (item.type.contains('GUEST')) return Icons.group_outlined;
  if (item.type.contains('QUOTE') || item.type.contains('PROVIDER')) {
    return Icons.storefront_rounded;
  }
  if (item.type.contains('INSTALLMENT') ||
      item.type.contains('BUDGET') ||
      item.type.contains('MONEY') ||
      item.type.contains('DEBT')) {
    return Icons.account_balance_wallet_rounded;
  }
  return Icons.info_outline_rounded;
}

Color _toneColor(String tone) {
  return switch (tone) {
    'danger' => _RoyalColors.burgundy,
    'warning' => _RoyalColors.goldDeep,
    'success' => const Color(0xFF2E7D57),
    _ => _RoyalColors.goldDeep,
  };
}

String _warningDashboardCopy(DashboardFinancialWarning warning) {
  return switch (warning.type) {
    'INCOMPLETE_GUESTS' => 'ضيوف بدون أرقام تواصل',
    'TASK_OVERDUE' => 'مهام متأخرة تحتاج مراجعة',
    'INSTALLMENT_DUE_SOON' || 'INSTALLMENT_OVERDUE' => 'قسط قريب يحتاج متابعة',
    'MISSING_BUDGET' => 'الميزانية تحتاج تحديد',
    'MISSING_LOCATION' => 'موقع الزفاف يحتاج تحديد',
    'BUDGET_EXCEEDED' => 'الميزانية تجاوزت الحد',
    _ => warning.message,
  };
}

List<DashboardFinancialWarning> _smartWarnings(DashboardSummary summary) {
  final warnings = <DashboardFinancialWarning>[...summary.financialWarnings];
  if (!_hasText(summary.city)) {
    warnings.add(
      const DashboardFinancialWarning(
        type: 'MISSING_LOCATION',
        severity: 'WARNING',
        message: 'موقع الزفاف غير مكتمل.',
      ),
    );
  }
  if (!_hasText(summary.totalBudgetForDisplay)) {
    warnings.add(
      const DashboardFinancialWarning(
        type: 'MISSING_BUDGET',
        severity: 'WARNING',
        message: 'الميزانية غير محددة بعد.',
      ),
    );
  }
  if (summary.incompleteGuestsCount > 0 &&
      warnings.every((warning) => warning.type != 'INCOMPLETE_GUESTS')) {
    warnings.add(
      DashboardFinancialWarning(
        type: 'INCOMPLETE_GUESTS',
        severity: 'WARNING',
        message: 'يوجد ضيوف ببيانات تواصل ناقصة.',
        count: summary.incompleteGuestsCount,
      ),
    );
  }
  if (summary.overdueTasks > 0 &&
      warnings.every((warning) => warning.type != 'TASK_OVERDUE')) {
    warnings.add(
      DashboardFinancialWarning(
        type: 'TASK_OVERDUE',
        severity: 'WARNING',
        message: 'يوجد مهام متأخرة.',
        count: summary.overdueTasks,
      ),
    );
  }
  return warnings.where((warning) => _hasText(warning.message)).toList();
}

void _openWarning(
  DashboardFinancialWarning warning, {
  required VoidCallback onOpenPlan,
  required VoidCallback onOpenMoney,
  required VoidCallback onOpenTasks,
  required VoidCallback onOpenGuests,
}) {
  if (warning.type.contains('GUEST')) {
    onOpenGuests();
    return;
  }
  if (warning.type.contains('TASK')) {
    onOpenTasks();
    return;
  }
  if (warning.type.contains('BUDGET') || warning.type.contains('INSTALLMENT')) {
    onOpenMoney();
    return;
  }
  onOpenPlan();
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
          subtitle: summary.overdueTasks > 0
              ? '${summary.overdueTasks} متأخرة • ${summary.todayTasks} اليوم'
              : '${summary.todayTasks} اليوم • ${summary.completedTasks} مكتملة',
          icon: Icons.checklist_rounded,
          onTap: onOpenTasks,
        ),
        const SizedBox(height: 12),
        _OperationalCard(
          title: 'الضيوف',
          subtitle:
              '${summary.guestCount} إجمالي • ${summary.confirmedGuests} مؤكد • ${summary.pendingGuests} معلق',
          icon: Icons.group_outlined,
          onTap: onOpenGuests,
        ),
        const SizedBox(height: 12),
        _OperationalCard(
          title: 'المشاركة في الخطة',
          subtitle:
              '${summary.participantCount} مشارك • ${summary.pendingInvites} دعوات معلقة • ${_dashboardRoleLabel(summary.currentUserRole)}',
          icon: Icons.share_rounded,
          onTap: onOpenParticipants,
        ),
      ],
    );
  }
}

String _dashboardRoleLabel(String? role) {
  return switch (role) {
    'OWNER' => 'صاحب الخطة',
    'GROOM' => 'العريس',
    'BRIDE' => 'العروس',
    'FAMILY' => 'العائلة',
    'HELPER' => 'مساعد',
    'VIEWER' => 'مشاهد',
    'GUEST' || 'GUEST_LOCAL' => 'مسودة على الجهاز',
    _ => role ?? 'مشارك',
  };
}

String _sharingSubtitle(DashboardSummary summary) {
  if (summary.isLocalOnly) return 'تسجيل الدخول مطلوب للمشاركة';
  if (summary.participantCount <= 1 && summary.pendingInvites == 0) {
    return 'لم تُشارك بعد';
  }
  if (summary.pendingInvites > 0) {
    return '${summary.participantCount} مشارك • ${summary.pendingInvites} دعوات';
  }
  return '${summary.participantCount} مشارك';
}

String _latestUpdatesSubtitle(DashboardSummary summary) {
  if (summary.recentActivity.isEmpty) return 'لا يوجد نشاط حقيقي بعد';
  final count = summary.recentActivity.length.clamp(0, 2).toInt();
  return count == 1 ? 'تحديث واحد' : '$count تحديثات';
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
                border: Border.all(
                  color: _RoyalColors.goldDeep.withValues(alpha: 0.15),
                ),
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
        return SizedBox(
          width: 90,
          height: 90,
          child: CustomPaint(
            size: const Size.square(90),
            painter: _DonutChartPainter(
              spentRatio: isTest ? ratio : value,
              spentColor: const Color(0xFF00FF66), // Neon Green for hologram
              backgroundColor: Colors.white.withValues(alpha: 0.05),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(value * 100).toInt()}%',
                    style: const TextStyle(
                      color: Color(0xFF00FF66),
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Color(0x6600FF66), blurRadius: 10)],
                    ),
                  ),
                  const Text(
                    'مُستهلك',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
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
    final radius = math.min(size.width / 2, size.height / 2) - 3;
    const strokeWidth = 6.0;

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
      final sweepAngle = 2 * math.pi * spentRatio;
      final startAngle = -math.pi / 2;

      final glowPaint = Paint()
        ..color = spentColor.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

      final spentPaint = Paint()
        ..shader = SweepGradient(
          startAngle: 0.0,
          endAngle: 2 * math.pi,
          colors: [
            spentColor.withValues(alpha: 0.2),
            spentColor,
          ],
          transform: GradientRotation(startAngle),
        ).createShader(Rect.fromCircle(center: center, radius: radius))
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

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
  const _AutoFlipCard({required this.front, required this.back});

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

class _AnimatedMoneyText extends StatelessWidget {
  const _AnimatedMoneyText({required this.value, required this.style});
  final String value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final cleaned = value.replaceAll(',', '').replaceAll(' ر.ي', '').trim();
    final amount = double.tryParse(cleaned) ?? 0.0;

    if (amount.isNaN || amount.isInfinite || amount == 0.0) {
      return Text(value, style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: amount),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutExpo,
      builder: (context, val, _) {
        return Text(_formatMoney(val.toStringAsFixed(0)), style: style);
      },
    );
  }
}

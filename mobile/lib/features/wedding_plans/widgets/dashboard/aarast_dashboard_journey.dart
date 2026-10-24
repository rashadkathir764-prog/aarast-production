part of 'aarast_dashboard_view.dart';

// The home in the journey look (prototype b02, x01). Every number shown is a
// server field; nothing is worked out on the phone (C2).

/// «أهلًا محمد», the plan and its city, the bell and the account.
class _JourneyHomeHeader extends StatelessWidget {
  const _JourneyHomeHeader({
    required this.userName,
    required this.summary,
    required this.onNotifications,
    required this.onProfile,
    this.married = false,
  });

  final String userName;
  final DashboardSummary summary;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  /// b07: once the day has passed the greeting congratulates.
  final bool married;

  @override
  Widget build(BuildContext context) {
    final name = userName.trim().split(RegExp(r'\s+')).first;
    final line = [
      summary.title.trim(),
      if ((summary.city ?? '').trim().isNotEmpty) summary.city!.trim(),
    ].join(' · ');
    final unread = summary.unreadNotificationsCount;
    return Row(
      key: const ValueKey('aarast-dashboard-header'),
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  married
                      ? (name.isEmpty ? 'ألف مبروك' : 'ألف مبروك يا $name')
                      : (name.isEmpty ? 'أهلًا فيك' : 'أهلًا $name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: JourneyType.of(
                    JourneyType.display,
                    weight: JourneyType.bold,
                  ),
                ),
              ),
              if (line.isNotEmpty)
                Text(
                  line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Stack(
          clipBehavior: Clip.none,
          children: [
            JourneyRoundButton(
              icon: LucideIcons.bell,
              tooltip: unread > 0 ? 'التنبيهات، $unread جديدة' : 'التنبيهات',
              onPressed: onNotifications,
            ),
            if (unread > 0)
              const PositionedDirectional(
                top: 9,
                end: 10,
                child: SizedBox.square(
                  dimension: 9,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AarastV3Color.danger,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
        Semantics(
          button: true,
          label: 'حسابي',
          onTap: onProfile,
          excludeSemantics: true,
          child: AarastPressable(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(22),
            child: JourneyAvatar(
              letter: name.isEmpty ? 'ع' : name.characters.first,
              color: AarastV3Color.saffron,
              size: 44,
            ),
          ),
        ),
      ],
    );
  }
}

/// The countdown (b02), or «الموعد لسا ما ثبت» (x01).
class _JourneyHomeHero extends StatelessWidget {
  const _JourneyHomeHero({
    required this.summary,
    required this.stage,
    required this.onTap,
    required this.showHijri,
  });

  /// g02: the Hijri date next to the Gregorian one.
  final bool showHijri;

  final DashboardSummary summary;
  final WeddingPlanStageState stage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = summary.weddingDate;
    final days = summary.daysRemaining ?? stage.daysUntilWedding;
    final hijri = date == null || !showHijri
        ? null
        : HijriDate.fromGregorian(date);
    final dateLine = date == null
        ? null
        : [formatArabicWeekdayDayMonth(date), ?hijri?.dayAndMonth].join(' · ');

    final String countLine;
    if (date == null || days == null) {
      countLine = '';
    } else if (days > 0) {
      countLine = days == 1
          ? 'يوم واحد على عرسك'
          : days == 2
          ? 'يومين على عرسك'
          : 'يوم على عرسك';
    } else if (days == 0) {
      countLine = 'اليوم عرسك';
    } else {
      countLine = 'ألف مبروك';
    }

    return Semantics(
      button: true,
      label: date == null
          ? 'الموعد لسا ما ثبت. ثبّت الموعد'
          : '${days != null && days > 0 ? '$days ' : ''}$countLine، $dateLine',
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        key: const ValueKey('aarast-dashboard-plan-moment'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: JourneyBox(
          color: AarastV3Color.primary,
          radius: 24,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          child: date == null
              ? _noDate()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (days != null && days > 2) ...[
                          Text(
                            '$days',
                            style: JourneyType.of(
                              JourneyType.count,
                              weight: JourneyType.bold,
                              color: AarastV3Color.onPrimary,
                              height: 1,
                            ),
                          ),
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                countLine,
                                style: JourneyType.of(
                                  JourneyType.title,
                                  weight: JourneyType.bold,
                                  color: AarastV3Color.onPrimary,
                                ),
                              ),
                              Text(
                                dateLine!,
                                style: JourneyType.of(
                                  JourneyType.small,
                                  color: AarastV3Color.onPrimaryMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // The stage sits with its path, so a long stage name
                    // never crowds the count on a narrow phone.
                    Row(
                      children: [
                        JourneyTag(
                          label: stage.compactLabel,
                          color: AarastV3Color.ink,
                          soft: AarastV3Color.saffron,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: _StagePath(stage: stage.stage)),
                      ],
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _noDate() {
    return Row(
      children: [
        const JourneyIconTile(
          icon: LucideIcons.calendarPlus,
          color: AarastV3Color.onPrimary,
          soft: AarastV3Color.primaryDark,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الموعد لسا ما ثبت',
                style: JourneyType.of(
                  JourneyType.title,
                  weight: JourneyType.bold,
                  color: AarastV3Color.onPrimary,
                ),
              ),
              Text(
                'ثبّته ونرتب لك المهام والدفعات عليه',
                style: JourneyType.of(
                  JourneyType.small,
                  color: AarastV3Color.onPrimaryMuted,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          LucideIcons.chevronLeft,
          color: AarastV3Color.onPrimary,
          size: 20,
        ),
      ],
    );
  }
}

/// The five stages as a quiet line; the current one is saffron.
class _StagePath extends StatelessWidget {
  const _StagePath({required this.stage});

  final WeddingPlanStage stage;

  static const _order = [
    WeddingPlanStage.foundation,
    WeddingPlanStage.planning,
    WeddingPlanStage.finalMonth,
    WeddingPlanStage.finalWeek,
    WeddingPlanStage.weddingDay,
  ];

  @override
  Widget build(BuildContext context) {
    final current = stage == WeddingPlanStage.wrapUp
        ? _order.length - 1
        : _order.indexOf(stage);
    return ExcludeSemantics(
      child: Row(
        children: [
          for (var index = 0; index < _order.length; index++) ...[
            if (index > 0) const SizedBox(width: 6),
            Expanded(
              child: Container(
                height: 5,
                decoration: BoxDecoration(
                  color: index == current
                      ? AarastV3Color.saffron
                      : index < current
                      ? AarastV3Color.onPrimary
                      : AarastV3Color.primaryDark,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// «الخطوة الجاية»: one honest next step. A due payment is named with its
/// amount and day, and opens recording that payment.
class _JourneyNextStep extends StatelessWidget {
  const _JourneyNextStep({
    required this.focus,
    required this.payment,
    required this.currency,
    required this.now,
    required this.onOpen,
  });

  final AarastDashboardFocus focus;
  final DashboardNextPaymentSchedule? payment;
  final String currency;
  final DateTime now;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final due = payment;
    final String eyebrow;
    final String title;
    final String reason;
    final String action;
    final IconData icon;
    if (due != null) {
      final days = DateUtils.dateOnly(
        due.dueDate,
      ).difference(DateUtils.dateOnly(now)).inDays;
      final when = days > 1
          ? 'بعد ${arabicCount(days, one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم')}'
          : days == 1
          ? 'بكرة'
          : days == 0
          ? 'اليوم'
          : 'متأخرة ${arabicCount(-days, one: 'يوم', two: 'يومين', few: 'أيام', many: 'يوم')}';
      eyebrow = 'الخطوة الجاية · $when';
      title =
          '${due.title}: ${formatDashboardAmount(dashboardAmount(due.amount) ?? 0)} ${_currencyLabel(currency)}';
      reason = 'موعدها ${formatArabicWeekdayDayMonth(due.dueDate)}';
      action = 'سجّل الدفعة';
      icon = LucideIcons.calendarClock;
    } else {
      eyebrow = 'الخطوة الجاية';
      title = focus.title;
      reason = focus.reason;
      action = focus.actionLabel;
      icon = focus.icon;
    }
    final urgent = focus.tone == AarastDashboardFocusTone.urgent;
    final accent = urgent
        ? AarastV3Color.brandAccentStrong
        : AarastV3Color.primary;
    final soft = urgent
        ? AarastV3Color.brandAccentSoft
        : AarastV3Color.primarySoft;
    return JourneyBox(
      key: ValueKey('aarast-dashboard-next-step-${focus.target.name}'),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              JourneyIconTile(icon: icon, color: accent, soft: soft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow,
                      style: JourneyType.of(
                        JourneyType.small,
                        weight: JourneyType.bold,
                        color: accent,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: JourneyType.of(
                        JourneyType.title,
                        weight: JourneyType.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      reason,
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: JourneyButton(label: action, onPressed: onOpen),
          ),
        ],
      ),
    );
  }
}

String _currencyLabel(String currency) {
  return switch (currency.toUpperCase()) {
    'YER' => 'ر.ي',
    'SAR' => 'ر.س',
    'USD' => r'$',
    _ => currency,
  };
}


/// b07: what is left to pay once the day has passed: agreements still
/// unpaid plus loans still owed (C12), and what was paid of all of them.
class DashboardAfterWedding {
  const DashboardAfterWedding({
    required this.left,
    required this.paid,
    required this.total,
  });

  final num left;
  final num paid;
  final num total;
}

/// b07's hero: «1.9 مليون باقي عليك», the share paid and «سددت … من …».
/// «تخلص منها في يونيو» is left out: no payoff date is planned anywhere.
class _AfterWeddingHero extends StatelessWidget {
  const _AfterWeddingHero({
    required this.debt,
    required this.currency,
    required this.onTap,
  });

  final DashboardAfterWedding debt;
  final String currency;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final left = compactMoneyParts(debt.left, currencyCode: currency);
    final paid = compactMoneyParts(debt.paid, currencyCode: currency);
    final total = compactMoneyParts(debt.total, currencyCode: currency);
    final share = debt.total <= 0 ? 0.0 : (debt.paid / debt.total).clamp(0, 1);
    final filled = (share * 5).round();
    return AarastPressable(
      key: const ValueKey('aarast-dashboard-after-hero'),
      onTap: onTap,
      semanticLabel:
          '${left.semanticText} باقي عليك. سددت ${paid.semanticText} من ${total.semanticText}',
      borderRadius: BorderRadius.circular(24),
      child: JourneyBox(
        color: AarastV3Color.primary,
        radius: 24,
        padding: EdgeInsets.zero,
        child: Stack(
          children: [
            const Positioned.fill(
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: JourneyQamariyaPainter(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        left.number,
                        style: JourneyType.of(
                          JourneyType.count,
                          weight: JourneyType.bold,
                          color: AarastV3Color.onPrimary,
                          height: 1,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${left.millionUnit ?? left.currency} باقي عليك',
                          style: JourneyType.of(
                            JourneyType.title,
                            weight: JourneyType.bold,
                            color: AarastV3Color.onPrimary,
                          ),
                        ),
                      ),
                      const JourneyTag(
                        label: 'بعد العرس',
                        color: AarastV3Color.ink,
                        soft: AarastV3Color.saffron,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      for (var piece = 0; piece < 5; piece++) ...[
                        if (piece > 0) const SizedBox(width: 6),
                        Expanded(
                          child: Container(
                            height: 6,
                            decoration: BoxDecoration(
                              color: piece < filled
                                  ? AarastV3Color.saffron
                                  : AarastV3Color.paper,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'سددت ${paid.plainText} من ${total.plainText}',
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.onPrimaryMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// b07 «قيّم مزودينك», opening g04.
class _RateProvidersCard extends StatelessWidget {
  const _RateProvidersCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      key: const ValueKey('aarast-dashboard-rate-providers'),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const JourneyIconTile(
            icon: LucideIcons.star,
            color: AarastV3Color.brandAccentStrong,
            soft: AarastV3Color.brandAccentSoft,
            size: 44,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'قيّم مزودينك',
                  style: JourneyType.of(
                    JourneyType.bodyLarge,
                    weight: JourneyType.bold,
                  ),
                ),
                Text(
                  'تقييمك يساعد العرسان الجايين',
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          JourneyButton(
            label: 'قيّم',
            background: AarastV3Color.brandAccentStrong,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

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
    this.greeting,
  });

  final String userName;
  final DashboardSummary summary;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  /// b07: once the day has passed the greeting congratulates.
  final bool married;

  /// b05: «مبروك يا عريس» on the day; null otherwise (RA-MO-24).
  final String? greeting;

  @override
  Widget build(BuildContext context) {
    final name = userName.trim().split(RegExp(r'\s+')).first;
    final greeting = this.greeting;
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
                  greeting ??
                      (married
                          ? (name.isEmpty ? 'ألف مبروك' : 'ألف مبروك يا $name')
                          : (name.isEmpty ? 'أهلًا فيك' : 'أهلًا $name')),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: JourneyType.of(
                    JourneyType.pageTitle,
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
        const SizedBox(width: AarastV3Space.x2),
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
                  dimension: AarastV3Space.x2,
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
        const SizedBox(width: AarastV3Space.x2),
        Semantics(
          button: true,
          label: 'حسابي',
          onTap: onProfile,
          excludeSemantics: true,
          child: AarastPressable(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(AarastV3Radius.feature),
            // The 40 avatar in a 48 target, like the round buttons beside it.
            child: SizedBox.square(
              dimension: AarastV3Space.x12,
              child: Center(
                child: JourneyAvatar(
                  letter: name.isEmpty ? '' : name.characters.first,
                  color: context.accent.primarySoft,
                  size: AarastV3Size.mark,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The countdown (b01, b02), or «الموعد لسا ما ثبت» (x01).
class _JourneyHomeHero extends StatelessWidget {
  const _JourneyHomeHero({
    required this.summary,
    required this.stage,
    required this.startingOut,
    required this.onTap,
    required this.showHijri,
  });

  /// g02: the Hijri date next to the Gregorian one.
  final bool showHijri;

  final DashboardSummary summary;
  final WeddingPlanStageState stage;

  /// The first steps lead the home (b01), so the moment is «البداية».
  final bool startingOut;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final date = summary.weddingDate;
    // RA-MO-154: the days are counted from the date today (D11, as the
    // server counts), not taken from the summary: an old copy of it, days
    // without the network, held an old count beside today's moment.
    final days = date == null ? summary.daysRemaining : stage.daysUntilWedding;
    final hijri = date == null || !showHijri
        ? null
        : HijriDate.fromGregorian(date);
    final dateLine = date == null
        ? null
        : [formatArabicWeekdayDayMonth(date), ?hijri?.dayAndMonth].join(' · ');

    final count = homeCountdownWords(date == null ? null : days);
    final countLine = count.drawn;

    return Semantics(
      button: true,
      label: date == null
          ? context.say(
              'الموعد لسا ما ثبت. ثبّت الموعد',
              'الموعد لسا ما ثبت. ثبّتي الموعد',
            )
          : '${count.spoken}، $dateLine',
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        key: const ValueKey('aarast-dashboard-plan-moment'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AarastV3Radius.feature),
        child: date == null
            ? JourneyBox(
                color: context.accent.primary,
                radius: AarastV3Radius.feature,
                padding: const EdgeInsets.all(AarastV3Space.x4),
                child: _noDate(context),
              )
            : _countdown(
                context,
                days: days,
                countLine: countLine,
                dateLine: dateLine!,
              ),
      ),
    );
  }

  /// b01, b02: the count, its line and the moment's tag on one row, the
  /// five moments under them, on the plan's colour with the qamariya
  /// window and the gypsum frieze.
  Widget _countdown(
    BuildContext context, {
    required int? days,
    required String countLine,
    required String dateLine,
  }) {
    final moment = _homeMoment(stage.stage, startingOut: startingOut);
    // Critique ر4: the five bars had no names. The moment's tag opens them,
    // with what moves the plan from one to the next.
    final tag = Semantics(
      button: true,
      label: 'مرحلتك ${_homeMoments[moment]}. شوف المراحل',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showMoments(context, moment),
        child: Padding(
          padding: const EdgeInsets.all(AarastV3Space.x1),
          child: Container(
            key: const ValueKey('aarast-dashboard-moment-tag'),
            padding: AarastV3Density.tagInsets,
            decoration: BoxDecoration(
              color: AarastV3Color.saffron,
              borderRadius: BorderRadius.circular(AarastV3Radius.card),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Within the hero's share for its tag, a long moment
                // («أسبوع العرس») wraps rather than leave the pill.
                Flexible(
                  child: Text(
                    _homeMoments[moment],
                    style: JourneyType.of(
                      JourneyType.small,
                      weight: JourneyType.bold,
                    ),
                  ),
                ),
                const SizedBox(width: AarastV3Space.x1),
                const Icon(LucideIcons.info, size: AarastV3Icon.sm),
              ],
            ),
          ),
        ),
      ),
    );
    // b01, b02 on the kit's JourneyPlanHero (Rashad 2026-11-17): the tasks,
    // the guests and the money's summary wear the same hero, from one place.
    return JourneyPlanHero(
      key: const ValueKey('aarast-dashboard-countdown'),
      figure: days != null && days > 2 ? '$days' : null,
      title: countLine,
      subtitle: dateLine,
      tag: tag,
      footer: _StagePath(current: moment),
    );
  }

  Widget _noDate(BuildContext context) {
    return Row(
      children: [
        JourneyIconTile(
          icon: LucideIcons.calendarPlus,
          color: AarastV3Color.onPrimary,
          soft: context.accent.primaryDark,
        ),
        const SizedBox(width: AarastV3Space.x3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'الموعد لسا ما ثبت',
                style: JourneyType.of(
                  JourneyType.lead,
                  weight: JourneyType.bold,
                  color: AarastV3Color.onPrimary,
                ),
              ),
              Text(
                context.say(
                  'ثبّته ونرتب لك المهام والدفعات عليه',
                  'ثبّتيه ونرتب لك المهام والدفعات عليه',
                ),
                style: JourneyType.of(
                  JourneyType.small,
                  color: context.accent.onPrimaryMuted,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          LucideIcons.chevronLeft,
          color: AarastV3Color.onPrimary,
          size: AarastV3Icon.md,
        ),
      ],
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
    this.loansLeft = 0,
  });

  final num left;
  final num paid;
  final num total;
  final num loansLeft; // D86: the loans within [left] («مع السلف»).
}

/// b07's hero: «1.9 مليون باقي عليك», the share paid and «سددت … من …».
/// «تخلص منها في يونيو» is left out: no payoff date is planned anywhere.
class _AfterWeddingHero extends StatelessWidget {
  const _AfterWeddingHero({
    required this.debt,
    required this.currency,
    required this.onTap,
    this.hidden = false,
  });

  final DashboardAfterWedding debt;
  final String currency;
  final VoidCallback onTap;

  /// G17: «أخفِ المبالغ» is on.
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    // Critique م2: left, paid and the total are read together and add up.
    final left = sumSafeMoneyParts(debt.left, currencyCode: currency);
    final paid = sumSafeMoneyParts(debt.paid, currencyCode: currency);
    final total = sumSafeMoneyParts(debt.total, currencyCode: currency);
    final share = debt.total <= 0 ? 0.0 : (debt.paid / debt.total).clamp(0, 1);
    final filled = (share * 5).round();
    return AarastPressable(
      key: const ValueKey('aarast-dashboard-after-hero'),
      onTap: onTap,
      semanticLabel: hidden
          ? 'باقي عليك. المبالغ مخفية'
          : '${left.semanticText} باقي عليك. ${context.say('سددت', 'سدّدتِ')} ${paid.semanticText} من ${total.semanticText}',
      borderRadius: BorderRadius.circular(AarastV3Radius.feature),
      child: JourneyBox(
        color: context.accent.primary,
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
              padding: const EdgeInsets.all(AarastV3Space.x4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LayoutBuilder(
                    builder: (context, row) => Row(
                      children: [
                        // Under a million the figure is written in full
                        // («500,000»): at the count's size it pushed the row
                        // past a narrow phone (RA-MO-138). It keeps to under
                        // half the row and shrinks to fit.
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: row.maxWidth * 0.45,
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: AlignmentDirectional.centerStart,
                            child: Text(
                              hidden ? '••••' : left.number,
                              maxLines: 1,
                              style: JourneyType.of(
                                JourneyType.count,
                                weight: JourneyType.bold,
                                color: AarastV3Color.onPrimary,
                                height: AarastV3Line.numeral,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AarastV3Space.x2),
                        Expanded(
                          child: Text(
                            hidden
                                ? 'باقي عليك'
                                : '${left.millionUnit ?? left.currency} باقي عليك${debt.loansLeft > 0 ? ' مع السلف' : ''}',
                            style: JourneyType.of(
                              JourneyType.lead,
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
                  ),
                  const SizedBox(height: AarastV3Space.x3),
                  Row(
                    children: [
                      for (var piece = 0; piece < 5; piece++) ...[
                        if (piece > 0) const SizedBox(width: AarastV3Space.x1),
                        Expanded(
                          child: Container(
                            height: AarastV3Size.bar,
                            decoration: BoxDecoration(
                              color: piece < filled
                                  ? AarastV3Color.saffron
                                  : AarastV3Color.paper,
                              borderRadius: BorderRadius.circular(
                                AarastV3Radius.xs,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: AarastV3Space.x3),
                  Text(
                    hidden
                        ? 'المبالغ مخفية'
                        : '${context.say('سددت', 'سدّدتِ')} ${paid.plainText} من ${total.plainText}',
                    style: JourneyType.of(
                      JourneyType.small,
                      color: context.accent.onPrimaryMuted,
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
      padding: const EdgeInsets.all(AarastV3Space.x4),
      child: Row(
        children: [
          const JourneyIconTile(
            icon: LucideIcons.star,
            color: AarastV3Color.brandAccentStrong,
            soft: AarastV3Color.brandAccentSoft,
            size: AarastV3Size.mark,
          ),
          const SizedBox(width: AarastV3Space.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.say('قيّم مزودينك', 'قيّمي مزودينك'),
                  style: JourneyType.of(
                    JourneyType.lead,
                    weight: JourneyType.bold,
                  ),
                ),
                Text(
                  context.say(
                    'تقييمك يساعد العرسان الجايين',
                    'تقييمك يساعد العرايس الجايات',
                  ),
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AarastV3Space.x2),
          JourneyButton(
            label: context.say('قيّم', 'قيّمي'),
            background: AarastV3Color.brandAccentStrong,
            onPressed: onTap,
          ),
        ],
      ),
    );
  }
}

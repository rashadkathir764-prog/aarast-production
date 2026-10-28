part of 'aarast_dashboard_view.dart';

// D66: the rafd on the home, the plan owner's only. The day (b05) records
// it; after the day (b07) the givers are thanked.

/// What the home shows of the rafd book: the gifts recorded, their total,
/// and how many still wait for their thanks.
class DashboardRafd {
  const DashboardRafd({
    required this.count,
    required this.total,
    required this.toThank,
    required this.waiting,
  });

  final int count;
  final num total;
  final int toThank;

  /// Written on this phone, not sent yet.
  final int waiting;
}

/// b05 «سجّل رفد · يشتغل بدون نت» with «47 رفد · 1.2 مليون»; the bride's
/// «سجّلي هدية». The card records; its figures open the book (e09).
class _RafdCard extends StatelessWidget {
  const _RafdCard({
    required this.rafd,
    required this.onRecord,
    required this.onOpenBook,
  });

  final DashboardRafd rafd;
  final VoidCallback onRecord;
  final VoidCallback onOpenBook;

  @override
  Widget build(BuildContext context) {
    final gift = context.planWord('رفد', 'هدية');
    final money = compactMoneyParts(rafd.total, currencyCode: 'YER');
    final line = rafd.waiting > 0
        ? 'يشتغل بدون نت · ${rafd.waiting} ينتظر النت'
        : 'يشتغل بدون نت';
    return JourneyBox(
      key: const ValueKey('aarast-dashboard-rafd'),
      color: AarastV3Color.saffron,
      radius: 24,
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          Expanded(
            child: AarastPressable(
              key: const ValueKey('aarast-dashboard-rafd-record'),
              onTap: onRecord,
              semanticLabel: '${context.say('سجّل', 'سجّلي')} $gift، $line',
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 8, 18),
                child: Row(
                  children: [
                    JourneyIconTile(
                      icon: LucideIcons.gem,
                      color: AarastV3Color.ink,
                      soft: AarastV3Color.paper.withValues(alpha: 0.6),
                      size: 54,
                      radius: 18,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${context.say('سجّل', 'سجّلي')} $gift',
                            style: JourneyType.of(
                              JourneyType.display,
                              weight: JourneyType.bold,
                            ),
                          ),
                          Text(
                            line,
                            style: JourneyType.of(
                              JourneyType.small,
                              color: AarastV3Color.inkSoft,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (rafd.count > 0)
            AarastPressable(
              key: const ValueKey('aarast-dashboard-rafd-book'),
              onTap: onOpenBook,
              semanticLabel: context.planWord('دفتر الرفد', 'دفتر الهدايا'),
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(8, 18, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${rafd.count} $gift',
                      style: JourneyType.of(
                        JourneyType.body,
                        weight: JourneyType.bold,
                      ),
                    ),
                    Text(
                      money.millionUnit == null
                          ? money.number
                          : '${money.number} ${money.millionUnit}',
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.inkSoft,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// b07 «اشكر اللي رفدوك · 112 شخص» with «اشكرهم», opening the book (e09)
/// where they are thanked one by one (e10).
class _RafdThanksCard extends StatelessWidget {
  const _RafdThanksCard({required this.rafd, required this.onOpen});

  final DashboardRafd rafd;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final bride = context.journeyProfile.isBride;
    return JourneyBox(
      key: const ValueKey('aarast-dashboard-rafd-thanks'),
      color: AarastV3Color.brandAccentSoft,
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const JourneyIconTile(
            icon: LucideIcons.heartHandshake,
            color: AarastV3Color.brandAccentStrong,
            soft: AarastV3Color.paper,
            size: 50,
            radius: 16,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bride
                      ? context.say('اشكر اللي أهدوك', 'اشكري اللي أهدوك')
                      : context.say('اشكر اللي رفدوك', 'اشكري اللي رفدوك'),
                  style: JourneyType.of(
                    JourneyType.title,
                    weight: JourneyType.bold,
                  ),
                ),
                Text(
                  bride ? '${rafd.toThank} ضيفة' : '${rafd.toThank} شخص',
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                ),
              ],
            ),
          ),
          JourneyButton(
            key: const ValueKey('aarast-dashboard-rafd-thank'),
            label: bride
                ? context.say('اشكرهن', 'اشكريهن')
                : context.say('اشكرهم', 'اشكريهم'),
            background: AarastV3Color.brandAccentStrong,
            onPressed: onOpen,
          ),
        ],
      ),
    );
  }
}

part of 'aarast_dashboard_view.dart';

// The mahr on the home (a06, C1): b01's second step and b02's agreement
// card. Every number is the server's (the money section's `mahr`); the card
// leaves the home once the mahr is complete (y08: «نخفي بطاقة المهر من
// الرئيسية، وتلقاها في المال»).

enum MahrHomeSide { pays, receives }

/// The plan's mahr as the home reads it: [recorded] is false when the plan
/// (a groom's or a bride's) has no mahr yet, so b01's step stays to take.
class DashboardHomeMahr {
  const DashboardHomeMahr({
    required this.side,
    required this.recorded,
    this.total = 0,
    this.settled = 0,
    this.nextDueAt,
    this.complete = false,
  });

  /// A groom's or a bride's plan without its mahr yet.
  const DashboardHomeMahr.notRecorded(this.side)
    : recorded = false,
      total = 0,
      settled = 0,
      nextDueAt = null,
      complete = false;

  final MahrHomeSide side;
  final bool recorded;
  final double total;

  /// Handed over (the groom) or received (the bride).
  final double settled;
  final DateTime? nextDueAt;
  final bool complete;
}

/// «3 مليون», «500,000»: an amount in a home line, without the currency.
String mahrHomeWords(double amount) {
  final parts = compactMoneyParts(amount, currencyCode: 'YER');
  final unit = parts.millionUnit;
  return unit == null ? parts.number : '${parts.number} $unit';
}

/// «2» of «سلّمت 2 من 3 مليون»: the number alone.
String mahrHomeNumber(double amount) =>
    compactMoneyParts(amount, currencyCode: 'YER').number;

/// b02 «الاتفاق مع أهل العروسة · سلّمت 2 من 3 مليون · الباقي 15 نوفمبر»,
/// or the bride's «الاتفاق مع العريس · استلمتِ 2 من 3 مليون».
class _MahrAgreementCard extends StatelessWidget {
  const _MahrAgreementCard({required this.mahr, required this.onTap});

  final DashboardHomeMahr mahr;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pays = mahr.side == MahrHomeSide.pays;
    final due = mahr.nextDueAt;
    final line = [
      '${pays ? context.say('سلّمت', 'سلّمتِ') : context.say('استلمت', 'استلمتِ')} '
          '${mahrHomeNumber(mahr.settled)} من ${mahrHomeWords(mahr.total)}',
      if (due != null) 'الباقي ${formatArabicDayMonth(due)}',
    ].join(' · ');
    final label = pays ? 'الاتفاق مع أهل العروسة' : 'الاتفاق مع العريس';
    final ratio = mahr.total <= 0
        ? 0.0
        : (mahr.settled / mahr.total).clamp(0.0, 1.0).toDouble();
    return Semantics(
      button: true,
      label: '$label، $line',
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: JourneyBox(
          key: const ValueKey('aarast-dashboard-mahr-card'),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              JourneyIconTile(
                icon: LucideIcons.heartHandshake,
                color: context.accent.primary,
                soft: context.accent.primarySoft,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                    Text(
                      line,
                      style: JourneyType.of(
                        JourneyType.body,
                        weight: JourneyType.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 56,
                child: JourneyBar(
                  value: ratio,
                  color: context.accent.primary,
                  height: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

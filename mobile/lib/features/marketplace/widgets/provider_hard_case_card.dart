import 'package:flutter/material.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/money_formatters.dart';
import '../models/marketplace_models.dart';
import '../models/provider_board.dart';
import 'provider_board_view.dart' show providerServiceIcon;

/// B-05: a provider's decline reason in the customer's words.
String? providerDeclineReasonWords(String? reason) => switch (reason) {
  'BUSY_THAT_DAY' => 'مشغولين ذاك اليوم',
  'OUT_OF_AREA' => 'المكان خارج منطقتهم',
  'NOT_MY_SERVICE' => 'ما يقدّمون هذي الخدمة',
  'OTHER' => 'لسبب ثاني',
  _ => null,
};

/// x09: a request that went wrong and still leaves its service open.
enum ProviderHardCaseKind {
  /// The provider declined before sending any offer.
  declined,

  /// The provider opened the request a day or more ago and did not answer.
  seenNoReply,

  /// The provider took his offer back (B-03); the request waits for him.
  withdrawn,

  /// Seven days passed without an answer (B-04).
  expired,
}

typedef ProviderHardCase = ({
  ProviderHardCaseKind kind,
  QuoteRequest quote,
  ProviderBoardRow row,

  /// For a withdrawn offer: another request of the same service with an
  /// offer still open («افتح العرض الثاني»).
  QuoteRequest? other,
});

/// The board's hard cases, one per request: a decline or a request that
/// ended unanswered while the service has no other request going, a request
/// opened a day ago with no offer on its service yet, and an offer the
/// provider took back. A booked service shows none. «ذكّره» and the
/// suspended-provider banner are not part of x09 here (no data behind them).
List<ProviderHardCase> providerHardCases(
  List<ProviderBoardRow> rows,
  DateTime now,
) {
  final cases = <ProviderHardCase>[];
  for (final row in rows) {
    if (row.booked || row.outside) continue;
    final going = row.quotes.any(
      (quote) => const {
        'SENT',
        'VIEWED',
        'RESPONDED',
        'ACCEPTED',
      }.contains(quote.status),
    );
    final offered = row.quotes.any(
      (quote) => quote.status == 'RESPONDED' || quote.status == 'ACCEPTED',
    );
    for (final quote in row.quotes) {
      if (quote.withdrawnOffer != null) {
        final other = row.quotes
            .where((candidate) => candidate.pendingOffer != null)
            .firstOrNull;
        cases.add((
          kind: ProviderHardCaseKind.withdrawn,
          quote: quote,
          row: row,
          other: other,
        ));
      } else if (quote.status == 'REJECTED' &&
          // He declined: no offer of his was turned down by the customer.
          !quote.offers.any((offer) => offer.status == 'REJECTED') &&
          !going) {
        cases.add((
          kind: ProviderHardCaseKind.declined,
          quote: quote,
          row: row,
          other: null,
        ));
      } else if (quote.isExpiredUnanswered && !going) {
        cases.add((
          kind: ProviderHardCaseKind.expired,
          quote: quote,
          row: row,
          other: null,
        ));
      } else if (quote.status == 'VIEWED' && !offered) {
        final opened = quote.updatedAt;
        if (opened != null && now.difference(opened).inHours >= 24) {
          cases.add((
            kind: ProviderHardCaseKind.seenNoReply,
            quote: quote,
            row: row,
            other: null,
          ));
        }
      }
    }
  }
  return cases;
}

class ProviderHardCaseCard extends StatelessWidget {
  const ProviderHardCaseCard({
    required this.hardCase,
    required this.now,
    required this.onFindOthers,
    this.onAnotherDay,
    this.onOpenOther,
    this.onAsk,
    super.key,
  });

  final ProviderHardCase hardCase;
  final DateTime now;
  final VoidCallback onFindOthers;

  /// «اطلب يوم ثاني»: a new request to the same provider.
  final VoidCallback? onAnotherDay;

  /// «افتح العرض الثاني»: the other open offer of the same service.
  final VoidCallback? onOpenOther;

  /// «اسألهم ليش»: the request's chat.
  final VoidCallback? onAsk;

  @override
  Widget build(BuildContext context) {
    final quote = hardCase.quote;
    final service = hardCase.row.providerCategoryName ?? hardCase.row.title;
    final (tag, tagColor, tagSoft) = switch (hardCase.kind) {
      ProviderHardCaseKind.declined => (
        'اعتذر',
        AarastV3Color.danger,
        AarastV3Color.dangerSoft,
      ),
      ProviderHardCaseKind.seenNoReply => (
        'شاف وما رد',
        AarastV3Color.amber,
        AarastV3Color.amberSoft,
      ),
      ProviderHardCaseKind.withdrawn => (
        'سحب عرضه',
        AarastV3Color.textMuted,
        AarastV3Color.canvas,
      ),
      ProviderHardCaseKind.expired => (
        'انتهى بدون رد',
        AarastV3Color.textMuted,
        AarastV3Color.canvas,
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: JourneyBox(
        key: ValueKey('provider-hard-case-${quote.id}'),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                JourneyIconTile(
                  icon: providerServiceIcon(service),
                  color: context.accent.primary,
                  soft: context.accent.primarySoft,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    quote.provider?.businessName ?? service,
                    style: JourneyType.of(
                      JourneyType.bodyLarge,
                      weight: JourneyType.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                JourneyTag(label: tag, color: tagColor, soft: tagSoft),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              _line(),
              style: JourneyType.of(
                JourneyType.body,
                color: AarastV3Color.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: _actions(context)),
          ],
        ),
      ),
    );
  }

  String _line() {
    final quote = hardCase.quote;
    switch (hardCase.kind) {
      case ProviderHardCaseKind.declined:
        final when = quote.rejectedAt;
        final base = when == null
            ? 'اعتذروا عن طلبك'
            : 'اعتذروا عن طلبك ${_dayWord(when, now)}';
        // B-05: the provider's reason, when he gave one.
        final why = providerDeclineReasonWords(quote.declineReason);
        return why == null ? '$base.' : '$base: $why.';
      case ProviderHardCaseKind.seenNoReply:
        return 'فتح طلبك ${_dayWord(quote.updatedAt!, now)}، وما رد بعد.';
      case ProviderHardCaseKind.withdrawn:
        // x09: «عرض 480 ألف ما عاد متاح. باقي عندك عرض ضوء صنعاء 550 ألف.»
        final withdrawn = quote.withdrawnOffer!;
        final amount = _money(withdrawn.amount, withdrawn.currency);
        final gone = amount == null
            ? 'عرضهم ما عاد متاح.'
            : 'عرض $amount ما عاد متاح.';
        final other = hardCase.other;
        final otherOffer = other?.pendingOffer;
        if (other == null || otherOffer == null) return gone;
        final rest = [
          'باقي عندك عرض',
          ?other.provider?.businessName,
          ?_money(otherOffer.amount, otherOffer.currency),
        ].join(' ');
        return '$gone $rest.';
      case ProviderHardCaseKind.expired:
        return 'ما ردوا خلال 7 أيام، وانتهى الطلب.';
    }
  }

  List<Widget> _actions(BuildContext context) {
    final quote = hardCase.quote;
    final findOthers = context.say('اطلب من غيره', 'اطلبي من غيره');
    switch (hardCase.kind) {
      case ProviderHardCaseKind.declined:
        return [
          JourneyButton(
            key: ValueKey('provider-hard-case-others-${quote.id}'),
            label: context.say('شوف البدائل', 'شوفي البدائل'),
            background: context.accent.primary,
            onPressed: onFindOthers,
          ),
          if (onAnotherDay != null)
            JourneyButton.quiet(
              key: ValueKey('provider-hard-case-day-${quote.id}'),
              label: context.say('اطلب يوم ثاني', 'اطلبي يوم ثاني'),
              onPressed: onAnotherDay,
            ),
        ];
      case ProviderHardCaseKind.seenNoReply:
        return [
          JourneyButton.quiet(
            key: ValueKey('provider-hard-case-others-${quote.id}'),
            label: findOthers,
            onPressed: onFindOthers,
          ),
        ];
      case ProviderHardCaseKind.withdrawn:
        return [
          if (hardCase.other != null && onOpenOther != null)
            JourneyButton(
              key: ValueKey('provider-hard-case-other-${quote.id}'),
              label: context.say('افتح العرض الثاني', 'افتحي العرض الثاني'),
              background: context.accent.primary,
              onPressed: onOpenOther,
            ),
          if (onAsk != null)
            JourneyButton.quiet(
              key: ValueKey('provider-hard-case-ask-${quote.id}'),
              label: context.say('اسألهم ليش', 'اسأليهم ليش'),
              onPressed: onAsk,
            ),
        ];
      case ProviderHardCaseKind.expired:
        return [
          JourneyButton(
            key: ValueKey('provider-hard-case-others-${quote.id}'),
            label: findOthers,
            background: context.accent.primary,
            onPressed: onFindOthers,
          ),
        ];
    }
  }
}

/// «480,000 ر.ي»; null when the amount is hidden or unreadable.
String? _money(String? amount, String? currency) {
  final value = num.tryParse(amount?.replaceAll(',', '').trim() ?? '');
  if (value == null) return null;
  return formatCompactMoney(value, currencyCode: currency ?? 'YER');
}

/// «أمس», «اليوم», «قبل يومين» … «15 أكتوبر».
String _dayWord(DateTime at, DateTime now) {
  final local = at.toLocal();
  final days = DateTime.utc(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime.utc(local.year, local.month, local.day)).inDays;
  if (days <= 0) return 'اليوم';
  if (days == 1) return 'أمس';
  if (days == 2) return 'قبل يومين';
  if (days <= 10) return 'قبل $days أيام';
  return formatArabicDayMonth(local);
}

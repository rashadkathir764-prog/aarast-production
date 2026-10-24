import 'package:flutter/material.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../models/marketplace_models.dart';
import '../models/provider_board.dart';
import 'provider_board_view.dart' show providerServiceIcon;

/// x09: a request that went wrong and still leaves its service open.
enum ProviderHardCaseKind {
  /// The provider declined before sending any offer.
  declined,

  /// The provider opened the request a day or more ago and did not answer.
  seenNoReply,
}

typedef ProviderHardCase = ({
  ProviderHardCaseKind kind,
  QuoteRequest quote,
  ProviderBoardRow row,
});

/// The board's hard cases, one per request: a decline while the service has
/// no other request going, and a request opened a day ago with no offer on
/// its service yet. A booked service shows none. «ذكّره», «سحب عرضه» and the
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
      if (quote.status == 'REJECTED' && quote.offers.isEmpty && !going) {
        cases.add((
          kind: ProviderHardCaseKind.declined,
          quote: quote,
          row: row,
        ));
      } else if (quote.status == 'VIEWED' && !offered) {
        final opened = quote.updatedAt;
        if (opened != null && now.difference(opened).inHours >= 24) {
          cases.add((
            kind: ProviderHardCaseKind.seenNoReply,
            quote: quote,
            row: row,
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
    super.key,
  });

  final ProviderHardCase hardCase;
  final DateTime now;
  final VoidCallback onFindOthers;

  /// «اطلب يوم ثاني»: a new request to the same provider.
  final VoidCallback? onAnotherDay;

  @override
  Widget build(BuildContext context) {
    final quote = hardCase.quote;
    final declined = hardCase.kind == ProviderHardCaseKind.declined;
    final service = hardCase.row.providerCategoryName ?? hardCase.row.title;
    final when = declined ? quote.rejectedAt : quote.updatedAt;
    final line = declined
        ? (when == null
              ? 'اعتذروا عن طلبك.'
              : 'اعتذروا عن طلبك ${_dayWord(when, now)}.')
        : 'فتح طلبك ${_dayWord(when!, now)}، وما رد بعد.';
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
                  color: AarastV3Color.cobalt,
                  soft: AarastV3Color.cobaltSoft,
                  size: 44,
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
                declined
                    ? const JourneyTag(
                        label: 'اعتذر',
                        color: AarastV3Color.danger,
                        soft: AarastV3Color.dangerSoft,
                      )
                    : const JourneyTag(
                        label: 'شاف وما رد',
                        color: AarastV3Color.amber,
                        soft: AarastV3Color.amberSoft,
                      ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              line,
              style: JourneyType.of(
                JourneyType.body,
                color: AarastV3Color.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (declined)
                  JourneyButton(
                    key: ValueKey('provider-hard-case-others-${quote.id}'),
                    label: 'شوف البدائل',
                    background: AarastV3Color.cobalt,
                    onPressed: onFindOthers,
                  )
                else
                  JourneyButton.quiet(
                    key: ValueKey('provider-hard-case-others-${quote.id}'),
                    label: 'اطلب من غيره',
                    onPressed: onFindOthers,
                  ),
                if (declined && onAnotherDay != null)
                  JourneyButton.quiet(
                    key: ValueKey('provider-hard-case-day-${quote.id}'),
                    label: 'اطلب يوم ثاني',
                    onPressed: onAnotherDay,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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

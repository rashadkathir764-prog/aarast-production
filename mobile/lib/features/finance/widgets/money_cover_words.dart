import 'package:flutter/widgets.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../models/money_plan.dart';
import '../models/wedding_cost.dart' show moneyValue;

// D103, D105: the money's verdict and the estimates' «if», said the same
// wherever the money is read (RA-MO-53).

/// The verdict: its sentence, what it rests on, and whether it is good news.
typedef MoneyCoverWords = ({bool ok, String main, String sub});

/// The promised money with a date that the account counted (D103), named
/// with its day: «باقي المهر (30 نوفمبر)».
String _countedPledges(MoneyCoverage coverage) => [
  for (final pledge in coverage.pledgesCounted)
    '${pledge.sourceName}${pledge.expectedAt == null ? '' : ' (${formatArabicDayMonth(pledge.expectedAt!)})'}',
].join(' و');

/// D105's «if» under the verdict: the estimates still expected, agreed at
/// their figures, and what would be left. Its figure counts the promised
/// money that has a date (D103), as a shortfall does; where the verdict
/// spoke of the money in hand alone («يكفي ... ويبقى»), it says so, so the
/// two sentences add up for the reader.
String moneyIfEstimatesWords(
  BuildContext context,
  MoneyCoverage coverage,
  String Function(Object? value) money,
) {
  final after = moneyValue(coverage.endAfterEstimates);
  final inHandOnly =
      coverage.verdict == MoneyCoverageVerdict.covered ||
      coverage.verdict == MoneyCoverageVerdict.nothingDue;
  final pledges = inHandOnly ? _countedPledges(coverage) : '';
  final result = after >= 0
      ? 'يبقى معك ${money(after)}'
      : 'ينقصك ${money(-after)}';
  final basis = pledges.isEmpty
      ? ''
      : after >= 0
      ? ' لو وصل $pledges في موعده'
      : ' حتى لو وصل $pledges في موعده';
  return '${context.say('ولو اتفقت', 'ولو اتفقتِ')} على البنود الباقية '
      'بتقديراتك (${money(coverage.estimatesLeft)})، $result$basis.';
}

/// D103's one verdict, in the money tab's words: the sentence, a second
/// line with what it rests on, and whether it is good news. One sentence for
/// «الملخص», «من وين» and the home's money card (D103: the same verdict
/// everywhere); [money] writes a figure the caller's way («أخفِ المبالغ»
/// included).
MoneyCoverWords moneyCoverWords(
  BuildContext context,
  MoneyCoverage coverage,
  String Function(Object? value) money,
) {
  final tail = <String>[
    for (final pledge in coverage.pledgesIgnored)
      'وعد ${pledge.sourceName} (${money(pledge.amount)}) '
          '${pledge.leftOut == MoneyPledgeLeftOut.late ? 'تأخر' : 'ما له موعد'}، فما حسبناه.',
    if (moneyValue(coverage.undated) > 0)
      '${money(coverage.undated)} عليك بدون موعد، حسبناها في الآخر.',
  ];
  final loan = coverage.hasLoan ? ' وسداد السلفة' : '';
  final until = coverage.lastDate == null
      ? ''
      : ' لين ${formatArabicDayMonth(coverage.lastDate!)}';
  String when(MoneyCoverageShort short) => short.date == null
      ? 'في الآخر'
      : 'يوم ${formatArabicDayMonth(short.date!)}';
  // D103: what is missing is the deepest the money falls (what pays
  // everything on its day, the home's and the assistant's figure), said
  // from the day it first falls short.
  String shortWords(MoneyCoverageRun run) {
    final first = run.firstShort!;
    final deepest = run.deepest ?? first;
    if (deepest.id == first.id) {
      return '${money(first.amount)} ${when(first)} (${first.title})';
    }
    return '${money(deepest.amount)}، يبدأ ${when(first)} (${first.title})';
  }

  switch (coverage.verdict) {
    case MoneyCoverageVerdict.nothingDue:
      return (
        ok: true,
        main:
            'ما عليك شي باقي${moneyValue(coverage.cash) > 0 ? '، ومعك ${money(coverage.cash)}' : ''}',
        sub: '',
      );
    case MoneyCoverageVerdict.covered:
      return (
        ok: true,
        main:
            'معك ${money(coverage.cash)} يكفي دفعاتك$loan بمواعيدها$until، ويبقى ${money(coverage.withoutPledges.end)}',
        sub: tail.join(' '),
      );
    case MoneyCoverageVerdict.coveredIfPledges:
      final names = _countedPledges(coverage);
      final without = coverage.withoutPledges;
      return (
        ok: true,
        main: 'يكفي بشرط يوصل موعود $names في موعده',
        sub: [
          if (without.firstShort != null) 'بدونه ينقصك ${shortWords(without)}.',
          ...tail,
        ].join(' '),
      );
    case MoneyCoverageVerdict.short:
      final run = coverage.withPledges;
      final short = run.firstShort!;
      final promised = coverage.pledgesCounted.fold<num>(
        0,
        (sum, pledge) => sum + moneyValue(pledge.amount),
      );
      final late = [
        for (final pledge in coverage.pledgesCounted)
          if (pledge.expectedAt != null &&
              short.date != null &&
              pledge.expectedAt!.isAfter(short.date!))
            '${pledge.sourceName} يوصل ${formatArabicDayMonth(pledge.expectedAt!)}',
      ];
      final totalCovers =
          moneyValue(coverage.cash) + promised >= moneyValue(coverage.total);
      return (
        ok: false,
        main: 'ينقصك ${shortWords(run)}',
        sub: [
          if (totalCovers && late.isNotEmpty)
            'المجموع يكفي، لكن موعود ${late.join(' و')}، بعد الموعد.'
          else
            'معك ${money(coverage.cash)}.',
          ...tail,
        ].join(' '),
      );
  }
}

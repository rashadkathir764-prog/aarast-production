// The money's headline (docs/project/MONEY_TERMS.md): what the home's money
// card and the money tab's summary both say, read from the one server
// picture (C2). Each figure names the field it comes from; nothing here adds
// or subtracts what the server did not, so the two screens cannot disagree.

import 'money_summary.dart';
import 'wedding_cost.dart' show moneyValue;

/// Whether the money covers what is on the owner (MONEY_TERMS «الحكم»).
enum MoneyHeadlineVerdict {
  /// No money sources recorded, or the reader is not the owner: no verdict.
  unknown,

  /// Nothing left on the owner.
  nothingDue,

  /// The money in hand pays everything on its day, promised money apart.
  covered,

  /// Only if the promised money arrives on its day; never said as «covered».
  coveredIfPledges,

  /// Short even with the promised money, by [MoneyHeadline.shortBy].
  short,
}

/// Where the plan stands against its budget (MONEY_TERMS «الميزانية»).
enum MoneyHeadlineBudget {
  /// No budget set.
  none,

  /// A budget, no agreement recorded yet.
  noAgreements,

  /// Within the budget by the expected cost.
  within,

  /// Over the budget by the expected cost, by [MoneyHeadline.overBy].
  over,
}

class MoneyHeadline {
  const MoneyHeadline({
    required this.lead,
    required this.leadIsOwners,
    required this.mahrPart,
    required this.agreementsPart,
    required this.mahrInsideBudget,
    required this.verdict,
    required this.shortBy,
    required this.paid,
    required this.agreed,
    required this.budget,
    required this.budgetTotal,
    required this.committedInBudget,
    required this.overBy,
  });

  /// What is left to pay: on the owner (`outstanding.owner`) for the owner,
  /// on the whole wedding (`outstanding.total`) for anyone else.
  final num lead;
  final bool leadIsOwners;

  /// Of [lead], the mahr (`outstanding.ownerMahr`); zero when none, and
  /// always zero for a reader who is not the owner.
  final num mahrPart;

  /// Of [lead], the owner's agreements apart from the mahr.
  final num agreementsPart;

  /// D114: the groom counts the mahr inside the budget.
  final bool mahrInsideBudget;

  final MoneyHeadlineVerdict verdict;

  /// The shortfall (`coverage.withPledges.deepest`) when [verdict] is short.
  final num? shortBy;

  /// The bar's one meaning: paid (`costs.paid`) of agreed (`costs.total`).
  final num paid;
  final num agreed;

  /// 0..1; zero without agreements.
  double get paidShare =>
      agreed <= 0 ? 0 : (paid / agreed).clamp(0, 1).toDouble();

  final MoneyHeadlineBudget budget;

  /// `budget.total`, null without a budget.
  final num? budgetTotal;

  /// What is agreed and counted against the budget (`budget.confirmedCost`).
  final num committedInBudget;

  /// By how much the expected cost passes the budget (`expected.budgetLeft`
  /// below zero), when [budget] is over.
  final num? overBy;
}

/// The headline of [summary] for a reader who [readerIsOwner] or not.
MoneyHeadline moneyHeadline(
  MoneySummary summary, {
  required bool readerIsOwner,
}) {
  final outstanding = summary.outstanding;
  final lead = moneyValue(
    readerIsOwner
        ? (outstanding?.owner ?? summary.costs.outstanding)
        : (outstanding?.total ?? summary.costs.outstanding),
  );
  final mahrPart = readerIsOwner ? moneyValue(outstanding?.ownerMahr) : 0;
  final coverage = readerIsOwner ? summary.coverage : null;
  final verdict = switch (coverage?.verdict) {
    null => MoneyHeadlineVerdict.unknown,
    MoneyCoverageVerdict.nothingDue => MoneyHeadlineVerdict.nothingDue,
    MoneyCoverageVerdict.covered => MoneyHeadlineVerdict.covered,
    MoneyCoverageVerdict.coveredIfPledges =>
      MoneyHeadlineVerdict.coveredIfPledges,
    MoneyCoverageVerdict.short => MoneyHeadlineVerdict.short,
  };
  final shortest = coverage == null
      ? null
      : (coverage.withPledges.deepest ?? coverage.withPledges.firstShort);
  final budgetTotal = summary.budget.total == null
      ? null
      : moneyValue(summary.budget.total);
  // D105: over the budget by the expected cost, as every screen says it.
  final left = summary.expected?.budgetLeft ?? summary.budget.remaining;
  final MoneyHeadlineBudget budget;
  if (budgetTotal == null) {
    budget = MoneyHeadlineBudget.none;
  } else if (summary.costs.count == 0) {
    budget = MoneyHeadlineBudget.noAgreements;
  } else if (left != null && moneyValue(left) < 0) {
    budget = MoneyHeadlineBudget.over;
  } else {
    budget = MoneyHeadlineBudget.within;
  }
  return MoneyHeadline(
    lead: lead,
    leadIsOwners: readerIsOwner,
    mahrPart: mahrPart,
    agreementsPart: readerIsOwner ? lead - mahrPart : lead,
    mahrInsideBudget: summary.budget.includesMahr,
    verdict: verdict,
    shortBy: verdict == MoneyHeadlineVerdict.short && shortest != null
        ? moneyValue(shortest.amount)
        : null,
    paid: moneyValue(summary.costs.paid),
    agreed: moneyValue(summary.costs.total),
    budget: budget,
    budgetTotal: budgetTotal,
    committedInBudget: moneyValue(summary.budget.confirmedCost),
    overBy: budget == MoneyHeadlineBudget.over ? -moneyValue(left) : null,
  );
}

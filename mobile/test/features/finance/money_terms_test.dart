import 'package:aarast_mobile/features/finance/models/money_headline.dart';
import 'package:aarast_mobile/features/finance/models/money_summary.dart';
import 'package:flutter_test/flutter_test.dart';

// docs/project/MONEY_TERMS.md: each figure the home's money card and the
// money tab's summary say comes from one server field, read by one function
// (moneyHeadline), so the two screens cannot say two different things.
void main() {
  Map<String, dynamic> body({
    String? budget = '8000000',
    bool includesMahr = false,
    String confirmedInBudget = '4250000',
    String agreed = '6250000',
    String paid = '2600000',
    int count = 5,
    String outstandingTotal = '3650000',
    String outstandingOwner = '3350000',
    String ownerMahr = '1500000',
    String? budgetLeft = '1200000',
    Map<String, dynamic>? coverage,
  }) => {
    'planId': 'plan-1',
    'currency': 'YER',
    'budget': {
      'total': budget,
      'includesMahr': includesMahr,
      'allocated': '0',
      'confirmedCost': confirmedInBudget,
      'paid': '0',
      'paidByOwner': '0',
      'paidByOthers': '0',
      'outstanding': '0',
      'count': count,
      'remaining': budget == null ? null : '3750000',
    },
    'costs': {
      'total': agreed,
      'paid': paid,
      'paidByOwner': paid,
      'paidByOthers': '0',
      'outstanding': outstandingTotal,
      'count': count,
    },
    'outstanding': {
      'total': outstandingTotal,
      'owner': outstandingOwner,
      'ownerMahr': ownerMahr,
      'others': '300000',
    },
    'expected': {
      'wedding': {
        'agreed': '0',
        'estimateLeft': '0',
        'expected': '0',
        'unknownCount': 0,
      },
      'mahr': {
        'agreed': '0',
        'estimateLeft': '0',
        'expected': '0',
        'unknownCount': 0,
      },
      'total': agreed,
      'budgetLeft': budgetLeft,
    },
    'coverage': ?coverage,
  };

  Map<String, dynamic> coverage(String verdict, {String? deepest}) => {
    'verdict': verdict,
    'cash': '2900000',
    'total': '3350000',
    'withoutPledges': <String, dynamic>{},
    'withPledges': {
      if (deepest != null)
        'deepest': {'amount': deepest, 'title': 'دفعة القاعة', 'id': 'c-1'},
    },
  };

  MoneyHeadline headline(Map<String, dynamic> json, {bool owner = true}) =>
      moneyHeadline(MoneySummary.fromJson(json), readerIsOwner: owner);

  test('the lead is what is left on the owner, the mahr a part of it', () {
    final h = headline(body());
    expect(h.lead, 3350000);
    expect(h.leadIsOwners, isTrue);
    expect(h.mahrPart, 1500000);
    expect(h.agreementsPart, 1850000);
    expect(h.mahrInsideBudget, isFalse);
  });

  test("a reader who is not the owner reads the whole wedding's left, "
      'no mahr part and no verdict', () {
    final h = headline(body(coverage: coverage('COVERED')), owner: false);
    expect(h.lead, 3650000);
    expect(h.mahrPart, 0);
    expect(h.verdict, MoneyHeadlineVerdict.unknown);
  });

  test('the bar is paid of agreed, nothing else', () {
    final h = headline(body());
    expect(h.paid, 2600000);
    expect(h.agreed, 6250000);
    expect(h.paidShare, closeTo(2600000 / 6250000, 1e-9));
    expect(headline(body(agreed: '0', paid: '0', count: 0)).paidShare, 0);
  });

  test('the verdict is the server\'s, and «only if the promised money '
      'comes» is never plain «covered»', () {
    expect(headline(body()).verdict, MoneyHeadlineVerdict.unknown);
    expect(
      headline(body(coverage: coverage('COVERED'))).verdict,
      MoneyHeadlineVerdict.covered,
    );
    expect(
      headline(body(coverage: coverage('COVERED_IF_PLEDGES'))).verdict,
      MoneyHeadlineVerdict.coveredIfPledges,
    );
    expect(
      headline(body(coverage: coverage('NOTHING_DUE'))).verdict,
      MoneyHeadlineVerdict.nothingDue,
    );
    final short = headline(
      body(coverage: coverage('SHORT', deepest: '450000')),
    );
    expect(short.verdict, MoneyHeadlineVerdict.short);
    expect(short.shortBy, 450000);
  });

  test('the budget: none, no agreements, within, or over by the expected '
      'cost', () {
    expect(headline(body(budget: null)).budget, MoneyHeadlineBudget.none);
    expect(headline(body(count: 0)).budget, MoneyHeadlineBudget.noAgreements);
    final within = headline(body());
    expect(within.budget, MoneyHeadlineBudget.within);
    expect(within.budgetTotal, 8000000);
    expect(within.committedInBudget, 4250000);
    expect(within.overBy, isNull);
    final over = headline(body(budgetLeft: '-800000'));
    expect(over.budget, MoneyHeadlineBudget.over);
    expect(over.overBy, 800000);
  });

  test('D114: the mahr counted inside the budget is said so', () {
    expect(headline(body(includesMahr: true)).mahrInsideBudget, isTrue);
  });

  test("the loans he returns are the owner's own line, never in the lead", () {
    final json = body()
      ..['funding'] = {
        'total': '3000000',
        'received': '3000000',
        'pledged': '0',
        'spent': '0',
        'availableCash': '2000000',
        'loanTotal': '1000000',
        'loanRepaid': '0',
        'loanOutstanding': '1000000',
        'overdueLoanRepayments': 0,
        'overduePledges': 0,
        'sourcesCount': 2,
      };
    final owner = headline(json);
    expect(owner.lead, 3350000, reason: 'the loans are not added to it');
  });
}

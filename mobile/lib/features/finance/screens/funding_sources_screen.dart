import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/funding_source.dart';
import '../models/wedding_cost.dart' show moneyValue;
import '../providers/finance_provider.dart';
import '../providers/funding_provider.dart';
import '../widgets/funding_sheets.dart';
import '../widgets/funding_widgets.dart';
import '../widgets/money_widgets.dart' show shownMoney;

/// «من وين»: where the wedding money comes from (savings, family support,
/// rafd and nuqut, pledges, loans with their repayments). The plan owner's
/// private money picture; tracking only.
class FundingSourcesScreen extends StatefulWidget {
  const FundingSourcesScreen({
    required this.weddingPlanId,
    this.openSourceId,
    super.key,
  });

  final String weddingPlanId;

  /// A source tapped elsewhere («من وين» on the money tab): it opens as its
  /// own row would, once the sources are read.
  final String? openSourceId;

  @override
  State<FundingSourcesScreen> createState() => _FundingSourcesScreenState();
}

class _FundingSourcesScreenState extends State<FundingSourcesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  bool _openedRequested = false;

  Future<void> _load() async {
    if (!mounted) return;
    // D86: the money picture (currency, «معك») is this plan's, read first
    // when the screen opens from a link before the money tab did.
    final finance = context.read<FinanceProvider?>();
    if (finance != null && finance.loadedPlanId != widget.weddingPlanId) {
      await finance.loadMoney(widget.weddingPlanId);
      if (!mounted) return;
    }
    final funding = context.read<FundingProvider>();
    await funding.load(widget.weddingPlanId);
    final id = widget.openSourceId;
    if (!mounted || id == null || _openedRequested) return;
    _openedRequested = true;
    final source = funding.sourceById(id);
    if (source != null) await _openSource(source);
  }

  /// What tapping a source does: a loan its repayments, a promise its
  /// arrival, anything else its form.
  Future<void> _openSource(FundingSource source) async {
    if (source.isLoan) {
      await _showLoan(source.id);
    } else if (source.isPledged) {
      await _checkPledge(source);
    } else {
      await _openSourceSheet(source: source);
    }
  }

  String get _currency {
    final finance = context.read<FinanceProvider?>();
    return finance?.loadedPlanId == widget.weddingPlanId
        ? finance!.summary.currency
        : 'YER';
  }

  String _plain(Object? value) => shownMoney(
    context,
    compactMoneyParts(moneyValue(value), currencyCode: _currency).plainText,
  );

  @override
  Widget build(BuildContext context) {
    final funding = context.watch<FundingProvider>();
    final sources = funding.loadedPlanId == widget.weddingPlanId
        ? funding.sources
        : const <FundingSource>[];
    num sum(
      Iterable<FundingSource> items,
      Object? Function(FundingSource) of,
    ) => items.fold<num>(0, (total, item) => total + moneyValue(of(item)));
    final received = sum(
      sources.where((item) => !item.isPledged),
      (item) => item.amount,
    );
    final pledged = sum(
      sources.where((item) => item.isPledged),
      (item) => item.amount,
    );
    // G33: a promised loan is owed only once it arrived.
    final owed = sum(
      sources.where((item) => item.isLoan && !item.isPledged),
      (item) => item.loanLeft,
    );

    final Widget list;
    if (funding.isLoading && sources.isEmpty) {
      list = const JourneyListState(
        phase: JourneyListPhase.loading,
        section: JourneySection.money,
      );
    } else if (sources.isEmpty) {
      list = JourneyListState(
        phase: funding.loadErrorMessage == null
            ? JourneyListPhase.empty
            : JourneyListPhase.error,
        section: JourneySection.money,
        emptyIcon: LucideIcons.piggyBank,
        emptyTitle: context.say(
          'ما سجلت من وين بتجيب الفلوس',
          'ما سجلتِ من وين بتجيبين الفلوس',
        ),
        onRetry: _load,
      );
    } else {
      list = JourneyBox(
        padding: EdgeInsets.zero,
        child: JourneyList(
          children: [
            for (final source in sources)
              JourneyListRow(
                key: ValueKey('funding-row-${source.id}'),
                icon: fundingKindIcon(source.kind),
                color: source.isPledged
                    ? AarastV3Color.lilac
                    : context.accent.primary,
                soft: source.isPledged
                    ? AarastV3Color.lilacSoft
                    : context.accent.primarySoft,
                title: source.sourceName,
                subtitle: source.isLoan
                    ? 'سلفة · باقي ${_plain(source.loanLeft)}'
                    : FundingKind.label(source.kind, context.journeyProfile),
                trailing: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _plain(source.amount),
                      style: JourneyType.of(
                        JourneyType.body,
                        weight: JourneyType.bold,
                      ),
                    ),
                    const SizedBox(height: AarastV3Space.x1),
                    fundingStateTag(source),
                  ],
                ),
                onTap: () => _openSource(source),
              ),
          ],
        ),
      );
    }

    return AarastScreenFrame(
      maxWidth: 600,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AarastV3Space.x4,
              AarastV3Space.x2,
              AarastV3Space.x2,
              0,
            ),
            child: JourneySubHeader(
              title: 'من وين',
              subtitle: context.say(
                'من وين بتجيب فلوس عرسك',
                'من وين بتجيبين فلوس عرسك',
              ),
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRouter.money(widget.weddingPlanId)),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: context.accent.primary,
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: AarastV3Density.pageInsets,
                children: [
                  if ((funding.loadErrorMessage != null || funding.isStale) &&
                      sources.isNotEmpty) ...[
                    JourneyListNotice(
                      offline: funding.loadErrorMessage == null,
                      keepsChanges: true,
                      onRetry: _load,
                    ),
                    const SizedBox(height: AarastV3Space.x3),
                  ],
                  if (sources.isNotEmpty) ...[
                    JourneyBox(
                      key: const ValueKey('funding-totals'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AarastV3Space.x4,
                        vertical: AarastV3Space.x2,
                      ),
                      child: Column(
                        children: [
                          _TotalRow(label: 'وصلك', value: _plain(received)),
                          _TotalRow(label: 'موعود لك', value: _plain(pledged)),
                          if (owed > 0)
                            _TotalRow(
                              label: 'باقي عليك من السلف',
                              value: _plain(owed),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AarastV3Space.x2),
                    const JourneySectionTitle('المصادر'),
                  ],
                  list,
                ],
              ),
            ),
          ),
          Padding(
            padding: AarastV3Density.actionInsets,
            child: JourneyButton(
              key: const ValueKey('funding-add'),
              label: context.say('أضف مصدر', 'أضيفي مصدر'),
              icon: LucideIcons.plus,
              expand: true,
              large: true,
              onPressed: funding.isSaving ? null : () => _openSourceSheet(),
            ),
          ),
        ],
      ),
    );
  }

  /// G16: removing a source asks first, and says what goes with it. A loan
  /// with a paid repayment is refused by the server; say so before asking.
  Future<bool> _confirmDelete(FundingSource source) async {
    final paid = source.repayments.where((item) => item.isPaid).length;
    if (paid > 0) {
      AarastToast.showError(
        context,
        context.say(
          'السلفة عليها سداد مدفوع. رجّع الدفعات «غير مدفوعة» أول.',
          'السلفة عليها سداد مدفوع. رجّعي الدفعات «غير مدفوعة» أول.',
        ),
      );
      return false;
    }
    final planned = source.repayments.where((item) => !item.isCancelled).length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AarastDialog(
        title: Text(
          context.say(
            'تشيل «${source.sourceName}»؟',
            'تشيلين «${source.sourceName}»؟',
          ),
        ),
        content: Text(
          planned > 0
              ? 'المصدر ينشال ومعه $planned من مواعيد السداد.'
              : 'المصدر ينشال من «من وين».',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('رجوع'),
          ),
          FilledButton(
            key: const ValueKey('funding-delete-confirm'),
            style: FilledButton.styleFrom(
              backgroundColor: AarastV3Color.danger,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.say('شيله', 'شيليه')),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  /// D108: the people the plan already names, each once, as first written:
  /// the family's lines, then who pays agreements for the owner.
  List<String> _knownPeople() {
    final finance = context.read<FinanceProvider?>();
    if (finance == null) return const [];
    final seen = <String>{};
    final names = <String>[];
    void add(String? name) {
      final trimmed = name?.trim().replaceAll(RegExp(r'\s+'), ' ') ?? '';
      if (trimmed.isEmpty || !seen.add(trimmed.toLowerCase())) return;
      names.add(trimmed);
    }

    for (final person in finance.summary.family ?? const []) {
      add(person.name);
    }
    for (final cost in finance.costs) {
      if (cost.payer == 'FAMILY' || cost.payer == 'OTHER') add(cost.payerName);
    }
    return names.take(6).toList(growable: false);
  }

  Future<void> _openSourceSheet({FundingSource? source}) async {
    final funding = context.read<FundingProvider>();
    // The sheet saves, and closes only once saved: a failure keeps what was
    // typed in it and says why.
    final result = await showJourneySheet<FundingFormResult>(
      context: context,
      builder: (_) => FundingSourceFormSheet(
        source: source,
        currency: _currency,
        knownPeople: _knownPeople(),
        onSave: (result) async {
          final saved = source == null
              ? await funding.create(
                  weddingPlanId: widget.weddingPlanId,
                  kind: result.kind,
                  sourceName: result.sourceName,
                  amount: result.amount,
                  status: result.status,
                  sourcePhone: result.sourcePhone,
                  note: result.note,
                  expectedAt: result.expectedAt,
                )
              : await funding.update(
                  source,
                  kind: result.kind,
                  sourceName: result.sourceName,
                  amount: result.amount,
                  status: result.status,
                  sourcePhone: result.sourcePhone,
                  note: result.note,
                  expectedAt: result.expectedAt,
                  // D108: «من مين؟» names who it is from.
                  person: FundingKind.namesPerson(result.kind)
                      ? result.sourceName
                      : null,
                );
          return saved
              ? null
              : (funding.errorMessage ?? 'ما قدرنا نحفظ التغيير');
        },
      ),
    );
    if (result == null || !mounted) return;
    final bool ok;
    if (result.delete && source != null) {
      if (!await _confirmDelete(source)) return;
      if (!mounted) return;
      ok = await funding.delete(source);
    } else {
      // Saved by the sheet.
      ok = true;
      if (source == null && result.repayments.isNotEmpty) {
        await _addRepayments(funding.sources.last.id, result.repayments);
        return;
      }
    }
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(
        context,
        result.delete ? 'انشال المصدر' : 'انحفظ',
      );
      unawaited(_refreshMoneySummary());
    } else {
      AarastToast.showError(
        context,
        funding.errorMessage ?? 'ما قدرنا نحفظ التغيير',
      );
    }
  }

  /// A new loan's repayments, one call each; a failure keeps the loan and
  /// says what is missing.
  Future<void> _addRepayments(
    String loanId,
    List<({String amount, DateTime dueDate})> repayments,
  ) async {
    final funding = context.read<FundingProvider>();
    var missed = 0;
    for (final repayment in repayments) {
      final loan = funding.sourceById(loanId);
      if (loan == null) break;
      final ok = await funding.addRepayment(
        loan,
        amount: repayment.amount,
        dueDate: repayment.dueDate,
      );
      if (!ok) missed++;
    }
    if (!mounted) return;
    if (missed > 0) {
      AarastToast.showWarning(
        context,
        'انحفظت السلفة، بس $missed من دفعات السداد ما انحفظت. ${context.say('أضفها', 'أضيفيها')} منها.',
      );
    } else {
      AarastToast.showSuccess(context, 'انحفظت السلفة ودفعاتها');
    }
    unawaited(_refreshMoneySummary());
  }

  /// x08: promised money that arrived moves to «وصلك»; money that will not
  /// come is removed.
  Future<void> _checkPledge(FundingSource source) async {
    final finance = context.read<FinanceProvider?>();
    final cash = finance?.loadedPlanId == widget.weddingPlanId
        ? finance?.summary.funding?.availableCash
        : null;
    final answer = await showJourneySheet<PledgeAnswer>(
      context: context,
      builder: (_) => PledgeCheckSheet(
        source: source,
        currency: _currency,
        availableCash: cash,
      ),
    );
    if (answer == null || !mounted) return;
    final funding = context.read<FundingProvider>();
    final bool ok;
    switch (answer) {
      case PledgeAnswer.notYet:
        return;
      case PledgeAnswer.edit:
        await _openSourceSheet(source: source);
        return;
      case PledgeAnswer.arrived:
        ok = await funding.update(
          source,
          kind: source.kind,
          sourceName: source.sourceName,
          amount: source.amount,
          status: FundingStatus.received,
          sourcePhone: source.sourcePhone,
          note: source.note,
          expectedAt: source.expectedAt,
        );
      case PledgeAnswer.notComing:
        // D112 (Q-26): the rest of the mahr stays owed and loses its day
        // (it then counts in no day's cover). Deleting it shrank the mahr
        // to what had been received and the app celebrated it as complete
        // (RA-MO-165).
        ok = source.isMahr
            ? await funding.update(
                source,
                kind: source.kind,
                sourceName: source.sourceName,
                amount: source.amount,
                status: FundingStatus.pledged,
                sourcePhone: source.sourcePhone,
                note: source.note,
                expectedAt: null,
              )
            : await funding.delete(source);
    }
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(
        context,
        answer == PledgeAnswer.arrived
            ? 'صارت معك'
            : source.isMahr
            ? 'بقي من مهرك، بدون موعد'
            : 'انشالت من الموعود',
      );
      unawaited(_refreshMoneySummary());
    } else {
      AarastToast.showError(
        context,
        funding.errorMessage ?? 'ما قدرنا نحفظ التغيير',
      );
    }
  }

  /// The loan sheet rebuilds from the provider, so each saved repayment shows.
  Future<void> _showLoan(String loanId) {
    final funding = context.read<FundingProvider>();
    final currency = _currency;
    return showJourneySheet<void>(
      context: context,
      builder: (sheetContext) => ListenableBuilder(
        listenable: funding,
        builder: (_, _) {
          final loan = funding.sourceById(loanId);
          if (loan == null) return const SizedBox.shrink();
          return LoanRepaymentsSheet(
            loan: loan,
            currency: currency,
            saving: funding.isSaving,
            errorMessage: funding.errorMessage,
            onAdd: (amount, dueDate) async {
              final ok = await funding.addRepayment(
                loan,
                amount: amount,
                dueDate: dueDate,
              );
              if (ok) unawaited(_refreshMoneySummary());
              return ok;
            },
            onTogglePaid: (repayment, paid) async {
              if (await funding.setRepaymentPaid(loan, repayment, paid: paid)) {
                unawaited(_refreshMoneySummary());
              }
            },
            onDelete: (repayment) async {
              if (await funding.deleteRepayment(loan, repayment)) {
                unawaited(_refreshMoneySummary());
              }
            },
            onEdit: () {
              Navigator.pop(sheetContext);
              unawaited(_openSourceSheet(source: loan));
            },
          );
        },
      ),
    );
  }

  /// Keeps the money overview's funding in step with what was saved.
  Future<void> _refreshMoneySummary() async {
    final finance = context.read<FinanceProvider?>();
    if (finance?.loadedPlanId != widget.weddingPlanId) return;
    await finance!.loadMoney(widget.weddingPlanId);
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: JourneyType.of(
                JourneyType.body,
                color: AarastV3Color.textMuted,
              ),
            ),
          ),
          Text(
            value,
            style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
          ),
        ],
      ),
    );
  }
}

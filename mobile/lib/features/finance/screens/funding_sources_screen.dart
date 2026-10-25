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

/// «من وين»: where the wedding money comes from (savings, family support,
/// rafd and nuqut, pledges, loans with their repayments). The plan owner's
/// private money picture; tracking only.
class FundingSourcesScreen extends StatefulWidget {
  const FundingSourcesScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<FundingSourcesScreen> createState() => _FundingSourcesScreenState();
}

class _FundingSourcesScreenState extends State<FundingSourcesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(_load()));
  }

  Future<void> _load() async {
    if (!mounted) return;
    await context.read<FundingProvider>().load(widget.weddingPlanId);
  }

  String get _currency {
    final finance = context.read<FinanceProvider?>();
    return finance?.loadedPlanId == widget.weddingPlanId
        ? finance!.summary.currency
        : 'YER';
  }

  String _plain(Object? value) =>
      compactMoneyParts(moneyValue(value), currencyCode: _currency).plainText;

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
    final owed = sum(
      sources.where((item) => item.isLoan),
      (item) => item.outstandingAmount ?? item.amount,
    );

    final Widget list;
    if (funding.isLoading && sources.isEmpty) {
      list = const JourneyListState(
        phase: JourneyListPhase.loading,
        section: JourneySection.money,
      );
    } else if (sources.isEmpty) {
      list = JourneyListState(
        phase: funding.errorMessage == null
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
                    ? 'سلفة · باقي ${_plain(source.outstandingAmount ?? source.amount)}'
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
                    const SizedBox(height: 4),
                    fundingStateTag(source),
                  ],
                ),
                onTap: () => source.isLoan
                    ? _showLoan(source.id)
                    : source.isPledged
                    ? _checkPledge(source)
                    : _openSourceSheet(source: source),
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
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
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
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  if (funding.errorMessage != null && sources.isNotEmpty) ...[
                    JourneyListNotice(offline: false, onRetry: _load),
                    const SizedBox(height: 12),
                  ],
                  if (sources.isNotEmpty) ...[
                    JourneyBox(
                      key: const ValueKey('funding-totals'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
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
                    const SizedBox(height: 8),
                    const JourneySectionTitle('المصادر'),
                  ],
                  list,
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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

  Future<void> _openSourceSheet({FundingSource? source}) async {
    final result = await showJourneySheet<FundingFormResult>(
      context: context,
      builder: (_) =>
          FundingSourceFormSheet(source: source, currency: _currency),
    );
    if (result == null || !mounted) return;
    final funding = context.read<FundingProvider>();
    final bool ok;
    if (result.delete && source != null) {
      ok = await funding.delete(source);
    } else if (source == null) {
      ok = await funding.create(
        weddingPlanId: widget.weddingPlanId,
        kind: result.kind,
        sourceName: result.sourceName,
        amount: result.amount,
        status: result.status,
        sourcePhone: result.sourcePhone,
        note: result.note,
        expectedAt: result.expectedAt,
      );
      if (ok && result.repayments.isNotEmpty) {
        await _addRepayments(funding.sources.last.id, result.repayments);
        return;
      }
    } else {
      ok = await funding.update(
        source,
        kind: result.kind,
        sourceName: result.sourceName,
        amount: result.amount,
        status: result.status,
        sourcePhone: result.sourcePhone,
        note: result.note,
        expectedAt: result.expectedAt,
      );
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
        ok = await funding.delete(source);
    }
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(
        context,
        answer == PledgeAnswer.arrived ? 'صارت معك' : 'انشالت من الموعود',
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
      padding: const EdgeInsets.symmetric(vertical: 7),
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

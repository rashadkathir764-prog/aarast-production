import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/funding_source.dart';
import '../models/wedding_cost.dart' show moneyValue;
import '../providers/finance_provider.dart';
import '../providers/funding_provider.dart';
import '../widgets/funding_widgets.dart';
import '../widgets/money_widgets.dart';

/// Where the wedding money comes from: savings, family support, rifd and
/// nuqut, pledges and loans with their repayments. The plan owner's private
/// money picture; tracking only.
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

  @override
  Widget build(BuildContext context) {
    final funding = context.watch<FundingProvider>();
    final sources = funding.loadedPlanId == widget.weddingPlanId
        ? funding.sources
        : const <FundingSource>[];
    final currency = _currency;
    return AarastScreenFrame(
      maxWidth: 560,
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('funding-add'),
        onPressed: funding.isSaving ? null : () => _openSourceSheet(),
        icon: const Icon(LucideIcons.plus),
        label: const Text('إضافة مصدر'),
      ),
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 120),
          children: [
            AarastPageHeader(
              title: 'مصادر التمويل',
              subtitle: 'من أين يأتي مال العرس، وكم بقي للسداد.',
              showBack: true,
              onBack: () => context.canPop()
                  ? context.pop()
                  : context.go(AppRouter.money(widget.weddingPlanId)),
            ),
            const SizedBox(height: 14),
            if (funding.errorMessage != null) ...[
              MoneyMessageBanner(message: funding.errorMessage!, error: true),
              const SizedBox(height: 12),
            ],
            _FundingTotals(sources: sources, currency: currency),
            const SizedBox(height: 14),
            if (funding.isLoading && sources.isEmpty)
              const AarastLoadingState(rows: 3, height: 64)
            else if (sources.isEmpty)
              const AarastEmptyState(
                icon: LucideIcons.wallet,
                title: 'لم تُسجّل مصادر بعد',
                message:
                    'أضف مدخراتك ودعم الأهل والرفد والسلف لتعرف كم يغطي مالك من تكاليف العرس.',
              )
            else
              AarastV3ContinuousSurface(
                children: [
                  for (final source in sources)
                    AarastV3ListRow(
                      key: ValueKey('funding-row-${source.id}'),
                      title: source.sourceName,
                      subtitle: source.isLoan
                          ? '${FundingKind.label(source.kind)} · ${source.repayments.length} دفعات سداد'
                          : source.isPledged
                          ? '${FundingKind.label(source.kind)} · وعد'
                          : FundingKind.label(source.kind),
                      leading: Icon(_kindIcon(source.kind)),
                      action: MoneyAmountText(
                        amount: source.isLoan
                            ? source.outstandingAmount
                            : source.amount,
                        currency: currency,
                      ),
                      onTap: () => source.isLoan
                          ? _showLoan(source.id)
                          : _openSourceSheet(source: source),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openSourceSheet({FundingSource? source}) async {
    final result = await showAarastBottomSheet<FundingFormResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => FundingSourceFormSheet(source: source),
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
      );
    } else {
      ok = await funding.update(
        source,
        kind: result.kind,
        sourceName: result.sourceName,
        amount: result.amount,
        status: result.status,
        sourcePhone: result.sourcePhone,
        note: result.note,
      );
    }
    if (!mounted) return;
    if (ok) {
      AarastToast.showSuccess(
        context,
        result.delete ? 'حُذف المصدر.' : 'تم الحفظ.',
      );
      unawaited(_refreshMoneySummary());
    } else {
      AarastToast.showError(
        context,
        funding.errorMessage ?? 'تعذر حفظ التغيير.',
      );
    }
  }

  /// The loan sheet rebuilds from the provider, so each saved repayment shows.
  Future<void> _showLoan(String loanId) {
    final funding = context.read<FundingProvider>();
    final currency = _currency;
    return showAarastBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
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

  /// Keeps the money overview's funding card in step with what was saved.
  Future<void> _refreshMoneySummary() async {
    final finance = context.read<FinanceProvider?>();
    if (finance?.loadedPlanId != widget.weddingPlanId) return;
    await finance!.loadMoney(widget.weddingPlanId);
  }

  IconData _kindIcon(String kind) => switch (kind) {
    FundingKind.savings => LucideIcons.piggyBank,
    FundingKind.familySupport => LucideIcons.users,
    FundingKind.gift => LucideIcons.gift,
    FundingKind.loan => LucideIcons.banknote,
    _ => LucideIcons.wallet,
  };
}

/// Received, pledged and loans still owed, computed from the listed sources.
class _FundingTotals extends StatelessWidget {
  const _FundingTotals({required this.sources, required this.currency});

  final List<FundingSource> sources;
  final String currency;

  @override
  Widget build(BuildContext context) {
    var received = 0.0;
    var pledged = 0.0;
    var owed = 0.0;
    for (final source in sources) {
      if (source.isPledged) {
        pledged += moneyValue(source.amount);
      } else {
        received += moneyValue(source.amount);
      }
      if (source.isLoan) owed += moneyValue(source.outstandingAmount);
    }
    return AarastV3ContinuousSurface(
      children: [
        _TotalRow(label: 'استُلم', amount: received, currency: currency),
        _TotalRow(label: 'موعود به', amount: pledged, currency: currency),
        _TotalRow(
          label: 'سلف متبقية للسداد',
          amount: owed,
          currency: currency,
          color: owed > 0 ? AppTheme.danger : null,
        ),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    required this.label,
    required this.amount,
    required this.currency,
    this.color,
  });

  final String label;
  final double amount;
  final String currency;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AarastV3Type.body(context))),
          MoneyAmountText(amount: amount, currency: currency, color: color),
        ],
      ),
    );
  }
}

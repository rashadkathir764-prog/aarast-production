part of 'cost_payment_screens.dart';

// c11 «تفاصيل دفعة» and x14 «دفعة انعكست»: the amount, who it went to and
// when, its receipt, and «اعكس الدفعة». A reversed payment stays struck
// through with the reason. «من وين» and «سجّلها» are not drawn: a payment
// stores no funding source and no author.

class CostPaymentDetailsScreen extends StatefulWidget {
  const CostPaymentDetailsScreen({
    required this.weddingPlanId,
    this.costId,
    required this.paymentId,
    super.key,
  });

  final String weddingPlanId;
  final String? costId;
  final String paymentId;

  @override
  State<CostPaymentDetailsScreen> createState() =>
      _CostPaymentDetailsScreenState();
}

class _CostPaymentDetailsScreenState extends State<CostPaymentDetailsScreen> {
  bool _isLoadingDetails = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load({bool refreshMoney = false}) async {
    final provider = context.read<FinanceProvider>();
    if (refreshMoney || provider.loadedPlanId != widget.weddingPlanId) {
      await provider.loadMoney(widget.weddingPlanId);
    }
    final costId =
        widget.costId ?? provider.paymentById(widget.paymentId)?.costId;
    if (mounted && provider.canViewMoney && costId != null) {
      await provider.loadCostDetails(costId);
    }
    if (mounted) setState(() => _isLoadingDetails = false);
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(AppRouter.money(widget.weddingPlanId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final payment = provider.paymentById(widget.paymentId);
    final costId = widget.costId ?? payment?.costId;
    final cost = costId == null ? null : provider.costById(costId);
    final currency = provider.summary.currency;

    final Widget body;
    if (_isLoadingDetails && payment == null) {
      body = const JourneyListState(
        phase: JourneyListPhase.loading,
        section: JourneySection.money,
      );
    } else if (provider.errorMessage != null && payment == null) {
      body = JourneyListState(
        phase: JourneyListPhase.error,
        section: JourneySection.money,
        onRetry: () => _load(refreshMoney: true),
      );
    } else if (payment == null) {
      body = JourneyListState(
        phase: JourneyListPhase.empty,
        section: JourneySection.money,
        emptyIcon: LucideIcons.banknote,
        emptyTitle: 'هذي الدفعة ما عاد موجودة',
        emptyAction: 'ارجع',
        onEmptyAction: _goBack,
      );
    } else {
      body = _details(provider, payment, cost, currency);
    }

    final title = cost?.title ?? payment?.costTitle;
    return AarastScreenFrame(
      maxWidth: 600,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: JourneySubHeader(
              title: title == null ? 'تفاصيل الدفعة' : 'دفعة $title',
              subtitle: payment == null
                  ? null
                  : _paymentLabel(provider, payment),
              onBack: _goBack,
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AarastV3Color.primary,
              onRefresh: () => _load(refreshMoney: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: [body],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// «الدفعة الأولى», counted like the agreement's timeline: payments that
  /// still count, oldest first.
  String _paymentLabel(FinanceProvider provider, CostPayment payment) {
    if (payment.isReversal) return 'قيد عكس';
    if (payment.isReversed) return 'انعكست';
    final counted =
        provider
            .paymentsForCost(payment.costId)
            .where((entry) => !entry.isReversal && !entry.isReversed)
            .toList()
          ..sort((a, b) => a.paidAt.compareTo(b.paidAt));
    final index = counted.indexWhere((entry) => entry.id == payment.id);
    return index < 0 ? 'دفعة' : 'الدفعة ${arabicOrdinal(index)}';
  }

  Widget _details(
    FinanceProvider provider,
    CostPayment payment,
    WeddingCost? cost,
    String currency,
  ) {
    final reversal = payment.reversedById == null
        ? null
        : provider.paymentById(payment.reversedById!);
    final canReverse =
        provider.canManageMoney &&
        cost != null &&
        payment.reversible &&
        !payment.isReversal &&
        !payment.isReversed;
    final hasReceipt =
        cost != null &&
        !payment.isReversal &&
        !payment.id.startsWith('local-') &&
        !FinanceLocalDataSource.isLocalGuestPlanId(widget.weddingPlanId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (provider.errorMessage != null) ...[
          JourneyListNotice(
            offline: false,
            onRetry: () => _load(refreshMoney: true),
          ),
          const SizedBox(height: 12),
        ],
        _PaymentAmountCard(payment: payment, currency: currency),
        const SizedBox(height: 12),
        JourneyBox(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (cost != null)
                _PaymentFact(
                  label: 'لمين',
                  value: cost.partyLabel ?? cost.title,
                  onTap: () => context.push(
                    AppRouter.moneyCostDetails(widget.weddingPlanId, cost.id),
                  ),
                ),
              _PaymentFact(
                label: 'متى',
                value: formatArabicWeekdayDayMonth(payment.paidAt),
              ),
              if ((payment.method ?? '').trim().isNotEmpty)
                _PaymentFact(label: 'كيف', value: payment.method!.trim()),
              if (payment.isReversed && reversal != null) ...[
                if ((reversal.note ?? '').trim().isNotEmpty)
                  _PaymentFact(label: 'ليش', value: reversal.note!.trim()),
                _PaymentFact(
                  label: 'انعكست',
                  value: formatArabicWeekdayDayMonth(
                    reversal.createdAt ?? reversal.paidAt,
                  ),
                ),
              ] else if ((payment.note ?? '').trim().isNotEmpty)
                _PaymentFact(
                  label: payment.isReversal ? 'ليش' : 'ملاحظة',
                  value: payment.note!.trim(),
                ),
            ],
          ),
        ),
        if (payment.isReversed || payment.isReversal) ...[
          const SizedBox(height: 12),
          const JourneyNote(
            text:
                'الدفعة ما تنمسح، تبقى مشطوبة عشان السجل يبقى صادق ومشاركينك يعرفون ايش صار.',
            icon: LucideIcons.fileText,
            color: AarastV3Color.textMuted,
            soft: AarastV3Color.paper,
          ),
        ],
        if (payment.isReversed && provider.canManageMoney) ...[
          const SizedBox(height: 12),
          JourneyBox(
            key: const ValueKey('payment-record-elsewhere'),
            color: AarastV3Color.primarySoft,
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                const Icon(LucideIcons.receipt, color: AarastV3Color.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'تسجّلها على اتفاق ثاني؟',
                    style: JourneyType.of(
                      JourneyType.body,
                      weight: JourneyType.bold,
                      color: AarastV3Color.primaryDark,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                JourneyButton(
                  label: 'البنود',
                  onPressed: () =>
                      context.go(AppRouter.money(widget.weddingPlanId)),
                ),
              ],
            ),
          ),
        ],
        // V1 checklist 4.4: the payment's own receipt. Receipts live on the
        // server, so not for a guest's local plan or a payment still waiting
        // to sync.
        if (hasReceipt) ...[
          const SizedBox(height: 18),
          CostReceiptsSection(
            key: ValueKey('payment-receipts-${payment.id}'),
            costId: cost.id,
            costPaymentId: payment.id,
            canManage: provider.canManageMoney,
          ),
        ],
        const SizedBox(height: 14),
        if (canReverse)
          Center(
            child: JourneyTextAction(
              key: const ValueKey('payment-reverse'),
              label: 'سجلتها بالغلط؟ اعكس الدفعة',
              color: AarastV3Color.danger,
              onPressed: provider.isSubmitting
                  ? null
                  : () => _reverse(payment, cost),
            ),
          )
        else if (!provider.canManageMoney)
          const JourneyNote(
            text: 'هذي الدفعة للعرض فقط. التعديل لمدير المال.',
            icon: LucideIcons.eye,
          ),
      ],
    );
  }

  Future<void> _reverse(CostPayment payment, WeddingCost cost) async {
    final reason = await showJourneySheet<String>(
      context: context,
      builder: (_) => const _ReverseSheet(),
    );
    if (reason == null || !mounted) return;
    final ok = await context.read<FinanceProvider>().reversePayment(
      payment: payment,
      cost: cost,
      reason: reason,
    );
    if (!mounted || !ok) return;
    AarastToast.showSuccess(
      context,
      context.read<FinanceProvider>().savedMessage('انعكست الدفعة'),
    );
    await _load(refreshMoney: true);
  }
}

/// The amount: green with «دُفعت», or struck through once reversed.
class _PaymentAmountCard extends StatelessWidget {
  const _PaymentAmountCard({required this.payment, required this.currency});

  final CostPayment payment;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final hidden = context.select<FinanceProvider?, bool>(
      (provider) => provider?.amountsHidden ?? false,
    );
    final value = moneyValue(payment.amount).abs().round();
    final amount = hidden
        ? '••••'
        : '${formatMoneyInputValue(value)} ${currencyLabelAr(currency)}';
    final struck = payment.isReversed || payment.isReversal;

    if (struck) {
      return JourneyBox(
        key: const ValueKey('payment-amount-card'),
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: AlignmentDirectional.centerStart,
                    child: Text(
                      amount,
                      style:
                          JourneyType.of(
                            JourneyType.display,
                            weight: JourneyType.bold,
                            color: AarastV3Color.textFaint,
                          ).copyWith(
                            decoration: TextDecoration.lineThrough,
                            decorationColor: AarastV3Color.textFaint,
                          ),
                    ),
                  ),
                  Text(
                    payment.isReversal
                        ? 'يلغي دفعة سابقة'
                        : 'ما تنحسب في أي رقم',
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            JourneyTag(
              label: payment.isReversal ? 'قيد عكس' : 'انعكست',
              color: AarastV3Color.danger,
              soft: AarastV3Color.dangerSoft,
            ),
          ],
        ),
      );
    }

    return JourneyBox(
      key: const ValueKey('payment-amount-card'),
      color: AarastV3Color.mintSoft,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const JourneyIconTile(
            icon: LucideIcons.checkCircle2,
            color: AarastV3Color.onPrimary,
            soft: AarastV3Color.mint,
            size: 50,
            radius: 16,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    amount,
                    style: JourneyType.of(
                      JourneyType.display,
                      weight: JourneyType.bold,
                    ),
                  ),
                ),
                Text(
                  hidden
                      ? 'دُفعت'
                      : '${amountInWords(value, currency: currencyLabelAr(currency))} · دُفعت',
                  style: JourneyType.of(
                    JourneyType.small,
                    weight: JourneyType.bold,
                    color: AarastV3Color.mint,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentFact extends StatelessWidget {
  const _PaymentFact({required this.label, required this.value, this.onTap});

  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: JourneyType.of(
                JourneyType.body,
                color: AarastV3Color.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
            ),
          ),
          if (onTap != null)
            const Icon(
              LucideIcons.chevronLeft,
              size: 18,
              color: AarastV3Color.textFaint,
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      label: '$label: $value',
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(onTap: onTap!, child: row),
    );
  }
}

/// x14: asks why before reversing; the reason is kept on the record.
class _ReverseSheet extends StatefulWidget {
  const _ReverseSheet();

  @override
  State<_ReverseSheet> createState() => _ReverseSheetState();
}

class _ReverseSheetState extends State<_ReverseSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _confirm() {
    final reason = _controller.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'اكتب ليش تعكسها');
      return;
    }
    Navigator.pop(context, reason);
  }

  @override
  Widget build(BuildContext context) {
    return JourneySheetBody(
      title: 'تعكس الدفعة؟',
      subtitle: 'ما تنمسح: تبقى مشطوبة في السجل، ويرجع مبلغها للباقي.',
      children: [
        JourneyTextField(
          key: const ValueKey('payment-reverse-reason'),
          label: 'ليش؟',
          hint: 'مثلًا: سجلتها على الاتفاق الغلط',
          controller: _controller,
          autofocus: true,
          maxLength: 1000,
          errorText: _error,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _confirm(),
        ),
        const SizedBox(height: 16),
        JourneyButton(
          key: const ValueKey('payment-reverse-confirm'),
          label: 'اعكس الدفعة',
          background: AarastV3Color.danger,
          expand: true,
          large: true,
          onPressed: _confirm,
        ),
      ],
    );
  }
}

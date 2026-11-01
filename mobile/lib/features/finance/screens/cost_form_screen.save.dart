part of 'cost_form_screen.dart';

// Saving c10: the agreement itself, then its payment dates one by one.

extension _CostFormSave on _CostFormScreenState {
  String? get _payerOrNull => _payer.isEmpty ? null : _payer;

  /// A name only goes with a payer it describes (family or other).
  String? get _payerNameOrNull {
    final name = _payerNameController.text.trim();
    return (_payer == 'FAMILY' || _payer == 'OTHER') && name.isNotEmpty
        ? name
        : null;
  }

  Future<void> _save(List<_PlannedLine> lines, DateTime? restDue) async {
    if (!_validate(lines)) return;
    final provider = context.read<FinanceProvider>();
    final category = (_categoryId == null
        ? null
        : provider.categoryById(_categoryId!));
    final typedTitle = _titleController.text.trim();
    final title = typedTitle.isNotEmpty
        ? typedTitle
        : _titleFallback(
                _partyKind,
                _providerName,
                _partyNameController.text,
                category,
              ) ??
              'اتفاق';
    final paidNow = lines
        .where((line) => line.paidNow)
        .fold<int>(0, (sum, line) => sum + line.amount);
    final providerId = _partyKind == _PartyKind.provider ? _providerId : null;
    final quoteOfferId = _partyKind == _PartyKind.provider
        ? _quoteOfferId
        : null;
    final partyName = _partyKind == _PartyKind.external
        ? _partyNameController.text.trim()
        : null;
    final partyPhone = _partyKind == _PartyKind.external
        ? _partyPhoneController.text.trim()
        : null;
    final cost = widget.cost;

    if (cost != null) {
      final ok = await provider.updateCost(
        cost: cost,
        budgetCategoryId: _categoryId!,
        title: title,
        totalAmount: '$_total',
        providerId: providerId,
        quoteOfferId: quoteOfferId,
        partyName: partyName,
        partyPhone: partyPhone,
        payer: _payerOrNull,
        payerName: _payerNameOrNull,
        agreementDate: _agreementDate,
        note: _noteController.text.trim(),
      );
      if (!mounted) return;
      if (!ok) {
        AarastToast.showError(
          context,
          provider.errorMessage ?? 'ما انحفظ الاتفاق',
        );
        return;
      }
      AarastFormSuccess.show(
        context,
        message: provider.savedMessage('انحفظ الاتفاق'),
      );
      context.popOrGo(AppRouter.money(widget.weddingPlanId), true);
      return;
    }

    final created = await provider.createCost(
      planId: widget.weddingPlanId,
      budgetCategoryId: _categoryId!,
      title: title,
      totalAmount: '$_total',
      initialPaymentAmount: paidNow > 0 ? '$paidNow' : null,
      providerId: providerId,
      quoteOfferId: quoteOfferId,
      partyName: partyName,
      partyPhone: partyPhone,
      payer: _payerOrNull,
      payerName: _payerNameOrNull,
      agreementDate: _agreementDate,
      note: _noteController.text.trim(),
      isPrivate: _isPrivate,
    );
    if (!mounted) return;
    if (created == null) {
      // The form stays as typed; the reason is the server's.
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'ما انحفظ الاتفاق',
      );
      return;
    }
    await _draft?.clear();
    // The payment dates follow one by one; a failure keeps the agreement
    // and says what is missing.
    var missed = 0;
    for (final line in lines.where((line) => !line.paidNow)) {
      final schedule = await provider.createSchedule(
        cost: created,
        amount: '${line.amount}',
        dueDate: line.dueDate!,
        note: line.label.split(' · ').first,
      );
      if (schedule == null) missed++;
    }
    if (!mounted) return;
    final router = GoRouter.of(context);
    if (missed > 0) {
      AarastToast.showWarning(
        context,
        'انحفظ الاتفاق، بس $missed من مواعيد الدفع ما انحفظت. ${context.say('أضفها', 'أضيفيها')} من تفاصيله.',
      );
    } else {
      AarastFormSuccess.show(
        context,
        message: provider.savedMessage('انحفظ الاتفاق'),
        nextLabel: context.say('افتح الاتفاق', 'افتحي الاتفاق'),
        onNext: () => router.push(
          AppRouter.moneyCostDetails(widget.weddingPlanId, created.id),
        ),
      );
    }
    context.popOrGo(AppRouter.money(widget.weddingPlanId), true);
  }
}

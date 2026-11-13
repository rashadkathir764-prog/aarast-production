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

  /// J1-08: one save window covers the agreement, the draft's removal and
  /// every payment date, so a second tap anywhere in it writes nothing.
  Future<void> _save(List<_PlannedLine> lines, DateTime? restDue) async {
    final provider = context.read<FinanceProvider>();
    if (provider.isSubmitting || !_validate(lines)) return;
    await provider.saveOnce(() => _write(provider, lines));
  }

  Future<void> _write(
    FinanceProvider provider,
    List<_PlannedLine> lines,
  ) async {
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
    // D105: what the agreement settles of its item's estimate; an expense
    // is a part by its own amount (the server's default).
    final coverPart = moneyValue(_coverPartController.text);
    final estimateCover = _expense ? null : (_coversPart ? 'PART' : 'WHOLE');
    final estimatePart = !_expense && _coversPart && coverPart > 0
        ? '${coverPart.round()}'
        : null;
    final savedWord = _expense ? 'انحفظ المصروف' : 'انحفظ الاتفاق';
    final failedWord = _expense ? 'ما انحفظ المصروف' : 'ما انحفظ الاتفاق';

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
        estimateCover: estimateCover,
        estimatePart: estimatePart,
      );
      if (!mounted) return;
      if (!ok) {
        AarastToast.showError(context, provider.errorMessage ?? failedWord);
        return;
      }
      AarastFormSuccess.show(
        context,
        message: provider.savedMessage(savedWord),
      );
      context.popOrGo(AppRouter.money(widget.weddingPlanId), true);
      return;
    }

    final created = await provider.createCost(
      planId: widget.weddingPlanId,
      budgetCategoryId: _categoryId!,
      title: title,
      totalAmount: '$_total',
      initialPaymentAmount: !_expense && paidNow > 0 ? '$paidNow' : null,
      providerId: providerId,
      quoteOfferId: quoteOfferId,
      partyName: partyName,
      partyPhone: partyPhone,
      payer: _payerOrNull,
      payerName: _payerNameOrNull,
      agreementDate: _agreementDate,
      note: _noteController.text.trim(),
      isPrivate: _isPrivate,
      isExpense: _expense,
      estimateCover: estimateCover,
      estimatePart: estimatePart,
    );
    if (!mounted) return;
    if (created == null) {
      // The form stays as typed; the reason is the server's.
      AarastToast.showError(context, provider.errorMessage ?? failedWord);
      return;
    }
    await _draft?.clear();
    // The payment dates follow, read back once (RA-MO-176); a failure keeps
    // the agreement and says what is missing.
    final dates = [
      for (final line in lines.where((line) => !line.paidNow))
        (
          amount: '${line.amount}',
          dueDate: line.dueDate!,
          note: line.label.split(' · ').first,
        ),
    ];
    final missed =
        dates.length -
        await provider.createSchedules(cost: created, dates: dates);
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
        message: provider.savedMessage(savedWord),
        nextLabel: context.say('افتح الاتفاق', 'افتحي الاتفاق'),
        onNext: () => router.push(
          AppRouter.moneyCostDetails(widget.weddingPlanId, created.id),
        ),
      );
    }
    context.popOrGo(AppRouter.money(widget.weddingPlanId), true);
  }
}

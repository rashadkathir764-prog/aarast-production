import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_binding.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/amount_words.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../data/cost_receipts_api.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import 'money_widgets.dart' show shownMoney;
import 'money_input_formatter.dart';
import 'receipt_flows.dart';

/// What the person filled in: [amount] is null when the amount is fixed
/// (paying a scheduled payment).
typedef PaymentEntry = ({
  String? amount,
  DateTime paidAt,
  String method,
  String note,
});

/// c06 «تسجيل دفعة»: how much (or the fixed scheduled amount), when, how,
/// a note, and the receipt photo saved with the payment. «من وين» is not
/// asked (a payment stores no funding source), nor «خاصة بي» (privacy
/// belongs to the agreement), nor another currency (the plan has one).
class PaymentEntryForm extends StatefulWidget {
  const PaymentEntryForm({
    required this.cost,
    required this.currency,
    required this.draftScope,
    required this.onSave,
    this.fixedAmount,
    this.fixedLine,
    this.fixedAction,
    super.key,
  });

  final WeddingCost cost;
  final String currency;
  final String draftScope;

  /// The scheduled amount, paid in full; null lets the person type it.
  final Object? fixedAmount;

  /// Under the fixed amount: «المتفق في موعد 10 سبتمبر».
  final String? fixedLine;

  /// «عدّل الموعد» under a fixed amount, to pay a different one.
  final VoidCallback? fixedAction;

  /// Saves the payment; null when it was not saved.
  final Future<CostPayment?> Function(PaymentEntry entry) onSave;

  @override
  State<PaymentEntryForm> createState() => _PaymentEntryFormState();
}

class _PaymentEntryFormState extends State<PaymentEntryForm> {
  static const _methods = ['نقدًا', 'تحويل'];

  final _amountController = TextEditingController();
  final _methodController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _paidAt = DateUtils.dateOnly(appNow());
  String? _amountError;
  XFile? _receipt;
  AarastFormDraftBinding? _draft;

  bool get _fixed => widget.fixedAmount != null;
  num get _remaining => moneyValue(widget.cost.remainingAmount);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _configureDraft();
    });
  }

  @override
  void dispose() {
    _draft?.dispose();
    _amountController.dispose();
    _methodController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _configureDraft() {
    _draft = AarastFormDraftBinding(
      store: context.read<AarastFormDraftStore?>(),
      scope: widget.draftScope,
      fields: {
        if (!_fixed) 'amount': _amountController,
        'method': _methodController,
        'note': _noteController,
      },
      readExtras: () => {'paidAt': _paidAt.toIso8601String()},
      restoreExtras: (data) {
        if (!mounted) return;
        final restored = DateTime.tryParse(data['paidAt']?.toString() ?? '');
        if (restored != null) setState(() => _paidAt = restored);
      },
      onStatusChanged: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_draft!.restore());
  }

  /// G17: the figures the form says follow «أخفِ المبالغ»; the field the
  /// user types in stays as typed.
  String _plain(num value) => shownMoney(
    context,
    compactMoneyParts(value, currencyCode: widget.currency).plainText,
  );

  int? get _typedAmount =>
      int.tryParse(_amountController.text.replaceAll(',', '').trim());

  String? _validate() {
    if (_fixed) return null;
    final amount = _typedAmount;
    if (amount == null || amount <= 0) {
      return context.say('اكتب كم دفعت', 'اكتبي كم دفعتِ');
    }
    if (amount > _remaining) {
      return '${context.ownerDid('أكثر من الباقي عليك', 'أكثر من الباقي عليك', groom: 'أكثر من الباقي عليه', bride: 'أكثر من الباقي عليها')} (${_plain(_remaining)})';
    }
    return null;
  }

  Future<void> _pickDate() async {
    releaseFieldFocus();
    final now = appNow();
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(now.year - 10),
      lastDate: DateUtils.dateOnly(now),
      locale: const Locale('ar'),
    );
    if (picked != null && mounted) {
      setState(() => _paidAt = picked);
      _draft?.changed();
    }
  }

  String _dateLabel() {
    final today = DateUtils.dateOnly(appNow());
    final days = today.difference(DateUtils.dateOnly(_paidAt)).inDays;
    if (days == 0) return 'اليوم';
    if (days == 1) return 'أمس';
    return formatArabicWeekdayDayMonth(_paidAt);
  }

  Future<void> _pickReceipt() async {
    final file = await pickReceiptImage(context);
    if (file != null && mounted) setState(() => _receipt = file);
  }

  Future<void> _save() async {
    final error = _validate();
    setState(() => _amountError = error);
    if (error != null) return;
    final payment = await widget.onSave((
      amount: _fixed ? null : '${_typedAmount!}',
      paidAt: _paidAt,
      method: _methodController.text.trim(),
      note: _noteController.text.trim(),
    ));
    if (!mounted) return;
    if (payment == null) {
      // What was typed stays, so trying again costs nothing.
      AarastToast.showError(
        context,
        context.read<FinanceProvider?>()?.errorMessage ??
            context.say(
              'ما انحفظت الدفعة. جرّب مرة ثانية.',
              'ما انحفظت الدفعة. جرّبي مرة ثانية.',
            ),
      );
      return;
    }
    await _draft?.clear();
    if (!mounted) return;
    final receipt = _receipt;
    if (receipt != null) await _saveReceipt(receipt, payment);
    if (mounted) {
      context.popOrGo(AppRouter.money(widget.cost.weddingPlanId), true);
    }
  }

  /// The receipt goes with the saved payment. A payment still waiting for
  /// the connection has no server id yet, so its receipt is added later.
  Future<void> _saveReceipt(XFile file, CostPayment payment) async {
    if (payment.id.startsWith('local-')) {
      AarastToast.showInfo(
        context,
        context.say(
          'الدفعة انحفظت. أضف الإيصال من تفاصيلها لما يرجع النت.',
          'الدفعة انحفظت. أضيفي الإيصال من تفاصيلها لما يرجع النت.',
        ),
      );
      return;
    }
    final CostReceiptsApi api;
    try {
      api = CostReceiptsApi(context.read<ApiClient>());
    } on ProviderNotFoundException {
      return;
    }
    await saveReceiptImage(
      context,
      api,
      file,
      costId: widget.cost.id,
      costPaymentId: payment.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    final submitting = context.select<FinanceProvider?, bool>(
      (provider) => provider?.isSubmitting ?? false,
    );
    final typed = _typedAmount;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: AarastV3Density.pageInsets,
            children: [
              if (_fixed)
                _FixedAmount(
                  amount: widget.fixedAmount,
                  currency: widget.currency,
                  line: widget.fixedLine,
                  onChange: widget.fixedAction,
                )
              else ...[
                JourneyTextField(
                  key: const Key('cost-payment-amount'),
                  label: 'المبلغ',
                  controller: _amountController,
                  large: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [MoneyInputFormatter()],
                  textInputAction: TextInputAction.done,
                  suffix: currencyLabelAr(widget.currency),
                  errorText: _amountError,
                  helper: typed == null || typed <= 0
                      ? null
                      : amountInWords(
                          typed,
                          currency: currencyLabelAr(widget.currency),
                        ),
                  onChanged: (_) => setState(() => _amountError = null),
                ),
                const SizedBox(height: AarastV3Space.x2),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    JourneyChip(
                      key: const ValueKey('payment-amount-remaining'),
                      label: 'الباقي كامل · ${_plain(_remaining)}',
                      selected: typed == _remaining.round(),
                      onTap: () {
                        _amountController.text = formatMoneyInputValue(
                          _remaining.round(),
                        );
                        setState(() => _amountError = null);
                        _draft?.changed();
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AarastV3Space.x4),
              JourneyPickerField(
                key: const ValueKey('payment-paid-at'),
                label: 'متى',
                value: _dateLabel(),
                icon: LucideIcons.calendarDays,
                onTap: _pickDate,
              ),
              const SizedBox(height: AarastV3Space.x4),
              Text(
                context.say('كيف دفعت؟', 'كيف دفعتِ؟'),
                style: JourneyType.of(
                  JourneyType.bodySmall,
                  weight: JourneyType.bold,
                  color: AarastV3Color.textMuted,
                ),
              ),
              const SizedBox(height: AarastV3Space.x2),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final method in _methods)
                    JourneyChip(
                      label: method,
                      selected: _methodController.text.trim() == method,
                      onTap: () {
                        final again = _methodController.text.trim() == method;
                        _methodController.text = again ? '' : method;
                        setState(() {});
                        _draft?.changed();
                      },
                    ),
                ],
              ),
              const SizedBox(height: AarastV3Space.x4),
              JourneyTextField(
                key: const ValueKey('payment-note'),
                label: 'ملاحظة',
                hint: 'مثلًا: العربون',
                controller: _noteController,
                maxLength: 1000,
              ),
              const SizedBox(height: AarastV3Space.x2),
              _ReceiptPick(
                file: _receipt,
                onPick: _pickReceipt,
                onClear: () => setState(() => _receipt = null),
              ),
              if (_draft != null) ...[
                const SizedBox(height: AarastV3Space.x2),
                AarastV3DraftStatusLine(status: _draft!.status),
              ],
            ],
          ),
        ),
        Padding(
          padding: AarastV3Density.actionInsets,
          child: JourneyButton(
            key: const ValueKey('payment-save'),
            label: 'حفظ الدفعة',
            expand: true,
            large: true,
            loading: submitting,
            onPressed: submitting ? null : _save,
          ),
        ),
      ],
    );
  }
}

class _FixedAmount extends StatelessWidget {
  const _FixedAmount({
    required this.amount,
    required this.currency,
    required this.line,
    required this.onChange,
  });

  final Object? amount;
  final String currency;
  final String? line;
  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    final value = moneyValue(amount).round();
    final hidden = context.select<FinanceProvider?, bool>(
      (provider) => provider?.amountsHidden ?? false,
    );
    return JourneyBox(
      key: const ValueKey('payment-fixed-amount'),
      color: context.accent.primarySoft,
      padding: const EdgeInsets.all(AarastV3Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              hidden
                  ? hiddenMoneyText
                  : '${formatMoneyInputValue(value)} ${currencyLabelAr(currency)}',
              style: JourneyType.of(
                JourneyType.display,
                weight: JourneyType.bold,
                color: context.accent.primaryDark,
              ),
            ),
          ),
          // The words would say the hidden amount.
          if (!hidden)
            Text(
              amountInWords(value, currency: currencyLabelAr(currency)),
              style: JourneyType.of(
                JourneyType.small,
                weight: JourneyType.bold,
                color: context.accent.primary,
              ),
            ),
          if (line != null) ...[
            const SizedBox(height: AarastV3Space.x1),
            Text(
              line!,
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
          ],
          if (onChange != null)
            JourneyTextAction(
              key: const ValueKey('payment-fixed-change'),
              label: context.say(
                'دفعت مبلغ ثاني؟ عدّل الموعد',
                'دفعتِ مبلغ ثاني؟ عدّلي الموعد',
              ),
              color: context.accent.primary,
              onPressed: onChange!,
            ),
        ],
      ),
    );
  }
}

/// «صوّر الإيصال»: a photo held until the payment is saved.
class _ReceiptPick extends StatelessWidget {
  const _ReceiptPick({
    required this.file,
    required this.onPick,
    required this.onClear,
  });

  final XFile? file;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (file == null) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: JourneyTextAction(
          key: const ValueKey('payment-receipt-pick'),
          label: context.say('صوّر الإيصال', 'صوّري الإيصال'),
          icon: LucideIcons.camera,
          color: context.accent.primary,
          onPressed: onPick,
        ),
      );
    }
    return Row(
      children: [
        const Icon(LucideIcons.checkCircle2, color: AarastV3Color.mint),
        const SizedBox(width: AarastV3Space.x2),
        Expanded(
          child: Text(
            'الإيصال جاهز، ينحفظ مع الدفعة',
            style: JourneyType.of(JourneyType.body, weight: JourneyType.bold),
          ),
        ),
        JourneyTextAction(
          label: context.say('شيله', 'شيليه'),
          color: AarastV3Color.danger,
          onPressed: onClear,
        ),
      ],
    );
  }
}

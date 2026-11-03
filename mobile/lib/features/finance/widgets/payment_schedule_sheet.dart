import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_binding.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/utils/app_clock.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/release_field_focus.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import 'money_input_formatter.dart';
import 'money_widgets.dart' show shownMoney;

/// One payment date of an agreement, in a journey sheet over c07 «جدول
/// الدفعات»: how much, which day and an optional note. c10 makes an
/// agreement's dates as it is saved; this sheet adds a date to one saved
/// «بعدين», and changes or removes a date that moved. Money is tracked here,
/// never moved. Returns true when the plan's money changed.
Future<bool> showPaymentScheduleSheet(
  BuildContext context, {
  required WeddingCost cost,
  required String currency,
  PaymentSchedule? schedule,
}) async {
  final changed = await showJourneySheet<bool>(
    context: context,
    builder: (_) => _PaymentScheduleSheet(
      cost: cost,
      currency: currency,
      schedule: schedule,
    ),
  );
  return changed ?? false;
}

class _PaymentScheduleSheet extends StatefulWidget {
  const _PaymentScheduleSheet({
    required this.cost,
    required this.currency,
    required this.schedule,
  });

  final WeddingCost cost;
  final String currency;
  final PaymentSchedule? schedule;

  @override
  State<_PaymentScheduleSheet> createState() => _PaymentScheduleSheetState();
}

class _PaymentScheduleSheetState extends State<_PaymentScheduleSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  DateTime? _dueDate;
  String? _amountError;
  String? _dateError;
  String? _error;
  AarastFormDraftBinding? _draft;

  bool get _editing => widget.schedule != null;
  num get _available => moneyValue(widget.cost.remainingAmount);

  @override
  void initState() {
    super.initState();
    final schedule = widget.schedule;
    if (schedule != null) {
      _amount.text = formatMoneyInputValue(schedule.amount);
      _note.text = schedule.note ?? '';
      _dueDate = DateUtils.dateOnly(schedule.dueDate);
    }
    _draft = AarastFormDraftBinding(
      store: context.read<AarastFormDraftStore?>(),
      scope:
          'payment-schedule:${widget.cost.weddingPlanId}:${widget.cost.id}:${schedule?.id ?? 'new'}',
      fields: {'amount': _amount, 'note': _note},
      readExtras: () => {'dueDate': _dueDate?.toIso8601String()},
      restoreExtras: (data) {
        if (!mounted) return;
        final restored = DateTime.tryParse(data['dueDate']?.toString() ?? '');
        if (restored != null) setState(() => _dueDate = restored);
      },
    );
    unawaited(_draft!.restore());
  }

  @override
  void dispose() {
    _draft?.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  String _plain(num value) => shownMoney(
    context,
    compactMoneyParts(value, currencyCode: widget.currency).plainText,
  );

  int? get _typedAmount =>
      int.tryParse(_amount.text.replaceAll(',', '').trim());

  Future<void> _pickDate() async {
    releaseFieldFocus();
    final now = appNow();
    final today = DateUtils.dateOnly(now);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? today,
      // A date that already passed can still be corrected, never added.
      firstDate: _editing ? DateTime(2020) : today,
      lastDate: DateTime(now.year + 10),
      locale: const Locale('ar'),
    );
    if (picked != null && mounted) {
      setState(() {
        _dueDate = picked;
        _dateError = null;
      });
      _draft?.changed();
    }
  }

  Future<void> _save() async {
    final amount = _typedAmount;
    setState(() {
      _error = null;
      _amountError = amount == null || amount <= 0
          ? context.say('اكتب كم المبلغ', 'اكتبي كم المبلغ')
          : amount > _available
          ? 'أكثر من الباقي عليك (${_plain(_available)})'
          : null;
      _dateError = _dueDate == null
          ? context.say('اختر يوم الدفعة', 'اختاري يوم الدفعة')
          : null;
    });
    if (_amountError != null || _dateError != null) return;

    final provider = context.read<FinanceProvider>();
    final schedule = widget.schedule;
    final note = _note.text.trim();
    final ok = schedule == null
        ? await provider.createSchedule(
                cost: widget.cost,
                amount: '$amount',
                dueDate: _dueDate!,
                note: note,
              ) !=
              null
        : await provider.updateSchedule(
            schedule: schedule,
            cost: widget.cost,
            amount: '$amount',
            dueDate: _dueDate!,
            note: note,
          );
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = provider.errorMessage ?? 'ما انحفظ الموعد.');
      return;
    }
    await _draft?.clear();
    if (!mounted) return;
    AarastToast.showSuccess(context, provider.savedMessage('انحفظ الموعد'));
    Navigator.of(context).pop(true);
  }

  Future<void> _remove() async {
    final schedule = widget.schedule!;
    final confirmed = await showJourneySheet<bool>(
      context: context,
      builder: (sheetContext) => JourneySheetBody(
        title:
            '${context.say('تشيل', 'تشيلين')} موعد ${formatArabicDayMonth(schedule.dueDate)}؟',
        subtitle: 'ينحذف من جدول الدفعات، والاتفاق يبقى مثل ما هو.',
        children: [
          JourneyButton(
            key: const ValueKey('payment-schedule-remove-confirm'),
            label: context.say('شيله', 'شيليه'),
            background: AarastV3Color.danger,
            expand: true,
            large: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: AarastV3Space.x2),
          JourneyButton.quiet(
            label: 'رجوع',
            expand: true,
            onPressed: () => Navigator.of(sheetContext).pop(false),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final provider = context.read<FinanceProvider>();
    final ok = await provider.deleteSchedule(
      schedule: schedule,
      cost: widget.cost,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _error = provider.errorMessage ?? 'ما انشال الموعد.');
      return;
    }
    await _draft?.clear();
    if (!mounted) return;
    AarastToast.showSuccess(context, provider.savedMessage('انشال الموعد'));
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final submitting = context.select<FinanceProvider?, bool>(
      (provider) => provider?.isSubmitting ?? false,
    );
    final due = _dueDate;
    return JourneySheetBody(
      title: _editing ? 'موعد الدفعة' : 'موعد دفع جديد',
      subtitle: [
        widget.cost.title,
        if (_available > 0) 'باقي عليك ${_plain(_available)}',
      ].join(' · '),
      bottom: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          JourneyButton(
            key: const ValueKey('schedule-save'),
            label: context.say('احفظ الموعد', 'احفظي الموعد'),
            expand: true,
            large: true,
            loading: submitting,
            onPressed: _save,
          ),
          if (_editing)
            Center(
              child: JourneyTextAction(
                key: const ValueKey('payment-schedule-remove'),
                label: context.say('شيل الموعد', 'شيلي الموعد'),
                color: AarastV3Color.danger,
                onPressed: submitting ? null : _remove,
              ),
            ),
        ],
      ),
      children: [
        JourneyTextField(
          key: const ValueKey('payment-schedule-amount'),
          label: 'المبلغ',
          controller: _amount,
          large: true,
          keyboardType: TextInputType.number,
          inputFormatters: [MoneyInputFormatter()],
          textInputAction: TextInputAction.done,
          suffix: currencyLabelAr(widget.currency),
          errorText: _amountError,
          onChanged: (_) {
            if (_amountError != null) setState(() => _amountError = null);
          },
        ),
        const SizedBox(height: AarastV3Space.x3),
        JourneyPickerField(
          key: const ValueKey('payment-schedule-date'),
          label: 'متى',
          icon: LucideIcons.calendarDays,
          value: due == null ? null : formatArabicWeekdayDayMonth(due),
          placeholder: context.say('اختر اليوم', 'اختاري اليوم'),
          onTap: _pickDate,
        ),
        if (_dateError case final error?) _ErrorLine(error),
        const SizedBox(height: AarastV3Space.x3),
        JourneyTextField(
          key: const ValueKey('payment-schedule-note'),
          label: 'كلمة عنها (اختياري)',
          hint: 'مثلًا: الدفعة الثانية',
          controller: _note,
          maxLength: 1000,
          textInputAction: TextInputAction.done,
        ),
        if (_error case final error?) ...[
          const SizedBox(height: AarastV3Space.x3),
          JourneyNote(
            text: error,
            icon: LucideIcons.alertCircle,
            color: AarastV3Color.danger,
            soft: AarastV3Color.dangerSoft,
          ),
        ],
      ],
    );
  }
}

class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AarastV3Space.x2,
        AarastV3Space.x1,
        AarastV3Space.x2,
        0,
      ),
      child: Row(
        children: [
          const Icon(
            LucideIcons.alertCircle,
            size: 16,
            color: AarastV3Color.danger,
          ),
          const SizedBox(width: AarastV3Space.x1),
          Expanded(
            child: Text(
              text,
              style: JourneyType.of(
                JourneyType.small,
                weight: JourneyType.bold,
                color: AarastV3Color.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

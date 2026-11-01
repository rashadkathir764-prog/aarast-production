import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/forms/aarast_form_draft_binding.dart';
import '../../../core/forms/aarast_form_draft_store.dart';
import '../../../core/forms/aarast_form_success.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/amount_words.dart';
import '../../../core/utils/currency_label.dart';
import '../../../core/utils/money_formatters.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/finance_write_access_block.dart';
import '../widgets/money_input_formatter.dart';
import '../widgets/money_widgets.dart' show shownMoney;

part 'money_budget_screen.rows.dart';

/// w19 «توزيع الميزانية» (gaps_b `vAllocate`): the wedding budget (the mahr
/// is outside it, C1) split over the items. A box says how much is given
/// out and what is left in reserve (`budget.unallocated`); each item shows
/// its share and its part of the budget. Pressing an item changes its share
/// in a small sheet, and pressing the box changes the budget itself.
class MoneyBudgetScreen extends StatefulWidget {
  const MoneyBudgetScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<MoneyBudgetScreen> createState() => _MoneyBudgetScreenState();
}

class _MoneyBudgetScreenState extends State<MoneyBudgetScreen> {
  final _totalController = TextEditingController();
  final _rows = <_CategoryDraft>[];
  String _currency = defaultCurrencyCode;
  bool _hydrated = false;
  String? _formError;
  AarastFormDraftBinding? _draft;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await context.read<FinanceProvider>().loadMoney(widget.weddingPlanId);
      if (mounted) _hydrate(context.read<FinanceProvider>());
    });
  }

  @override
  void dispose() {
    _draft?.dispose();
    _totalController.dispose();
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  String _plain(num value) => shownMoney(
    context,
    compactMoneyParts(value, currencyCode: _currency).plainText,
  );

  void _changed() {
    setState(() => _formError = null);
    _draft?.changed();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    if (!_hydrated &&
        !provider.isLoading &&
        provider.loadedPlanId == widget.weddingPlanId &&
        provider.hasLoadedMoney &&
        provider.errorMessage == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _hydrate(provider);
      });
    }
    final accessBlock = financeWriteAccessBlock(
      context: context,
      provider: provider,
      weddingPlanId: widget.weddingPlanId,
      ownerOnly: true,
    );
    if (accessBlock != null) return accessBlock;

    final total = moneyValue(_totalController.text);
    final allocated = _rows.fold<num>(
      0,
      (sum, row) => sum + moneyValue(row.amount.text),
    );
    final reserve = total - allocated;

    return AarastScreenFrame(
      maxWidth: 600,
      backgroundColor: AarastV3Color.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
            child: JourneySubHeader(
              title: 'توزيع الميزانية',
              subtitle: total > 0
                  ? '${_plain(total)} لعرسك · المهر لحاله'
                  : 'المهر لحاله، برا الميزانية',
              onBack: () => _close(false),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              children: [
                if (provider.errorMessage != null) ...[
                  JourneyListNotice(
                    offline: false,
                    onRetry: () => provider.loadMoney(widget.weddingPlanId),
                  ),
                  const SizedBox(height: 12),
                ],
                _ReserveBox(
                  allocated: _plain(allocated),
                  reserve: total <= 0
                      ? null
                      : reserve == 0
                      ? 'ما فيه'
                      : _plain(reserve.abs()),
                  over: total > 0 && reserve < 0,
                  onTap: _editTotal,
                ),
                const SizedBox(height: 12),
                if (_rows.isEmpty)
                  const JourneyListState(
                    phase: JourneyListPhase.empty,
                    section: JourneySection.money,
                    emptyIcon: LucideIcons.tags,
                    emptyTitle: 'ما فيه بنود بعد',
                  )
                else
                  JourneyList(
                    dividers: false,
                    children: [
                      for (final row in _rows)
                        _AllocationRow(
                          key: ValueKey(row.key),
                          row: row,
                          total: total,
                          currency: _currency,
                          onTap: () => _editShare(row),
                        ),
                    ],
                  ),
                const SizedBox(height: 10),
                if (_rows.isNotEmpty)
                  Text(
                    context.say(
                      'اضغط أي بند وغيّر رقمه، والاحتياط يتعدل لحاله.',
                      'اضغطي أي بند وغيّري رقمه، والاحتياط يتعدل لحاله.',
                    ),
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: JourneyTextAction(
                    key: const ValueKey('money-budget-add-category'),
                    label: context.say('أضف بند', 'أضيفي بند'),
                    icon: LucideIcons.plus,
                    color: context.accent.primary,
                    onPressed: _openCategoryCreate,
                  ),
                ),
                if (_formError != null) ...[
                  const SizedBox(height: 10),
                  JourneyNote(
                    key: const ValueKey('money-budget-error'),
                    text: _formError!,
                    icon: LucideIcons.alertTriangle,
                    color: AarastV3Color.danger,
                    soft: AarastV3Color.dangerSoft,
                  ),
                ],
                if (_draft != null) ...[
                  const SizedBox(height: 8),
                  AarastV3DraftStatusLine(status: _draft!.status),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: JourneyButton(
              key: const ValueKey('money-budget-save'),
              label: 'حفظ التوزيع',
              expand: true,
              large: true,
              loading: provider.isSubmitting,
              onPressed: provider.isSubmitting ? null : _save,
            ),
          ),
        ],
      ),
    );
  }

  /// «ميزانية عرسك» and its currency, in a sheet over the split.
  Future<void> _editTotal() {
    final currencyLocked =
        context.read<FinanceProvider>().summary.costs.count > 0;
    return showJourneySheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final total = moneyValue(_totalController.text);
          return JourneySheetBody(
            title: 'ميزانية عرسك',
            subtitle: 'المهر لحاله، برا الميزانية',
            children: [
              JourneyTextField(
                key: const ValueKey('money-budget-total'),
                label: 'كم تقريبًا؟',
                hint: 'مثلًا: 3,000,000',
                controller: _totalController,
                large: true,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [MoneyInputFormatter()],
                suffix: currencyLabelAr(_currency),
                helper: total > 0
                    ? amountInWords(
                        total.round(),
                        currency: currencyLabelAr(_currency),
                      )
                    : null,
                onChanged: (_) {
                  setSheetState(() {});
                  _changed();
                },
              ),
              const SizedBox(height: 12),
              if (currencyLocked)
                Text(
                  'العملة ${currencySpokenLabelAr(_currency)}، ثابتة بعد أول اتفاق',
                  key: const ValueKey('money-budget-currency-locked'),
                  style: JourneyType.of(
                    JourneyType.small,
                    color: AarastV3Color.textMuted,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (code, label) in weddingCurrencyOptions)
                      JourneyChip(
                        label: label,
                        selected: _currency == code,
                        onTap: () {
                          setSheetState(() {});
                          setState(() => _currency = code);
                          _draft?.changed();
                        },
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              JourneyButton(
                key: const ValueKey('money-budget-total-done'),
                label: 'تمام',
                expand: true,
                large: true,
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
            ],
          );
        },
      ),
    );
  }

  /// One item's share, typed in a small sheet; the reserve follows as it
  /// changes. The item's own page stays one press away.
  Future<void> _editShare(_CategoryDraft row) {
    return showJourneySheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final share = moneyValue(row.amount.text);
          return JourneySheetBody(
            title: row.name,
            subtitle: context.say(
              'كم تحط له من ميزانية عرسك؟',
              'كم تحطين له من ميزانية عرسك؟',
            ),
            children: [
              JourneyTextField(
                key: ValueKey('money-budget-share-${row.key}'),
                label: 'نصيبه',
                hint: 'بدون',
                controller: row.amount,
                large: true,
                autofocus: true,
                keyboardType: TextInputType.number,
                inputFormatters: [MoneyInputFormatter()],
                suffix: currencyLabelAr(_currency),
                helper: share > 0
                    ? amountInWords(
                        share.round(),
                        currency: currencyLabelAr(_currency),
                      )
                    : null,
                onChanged: (_) {
                  setSheetState(() {});
                  _changed();
                },
              ),
              const SizedBox(height: 16),
              JourneyButton(
                key: const ValueKey('money-budget-share-done'),
                label: 'تمام',
                expand: true,
                large: true,
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
              if (row.id != null) ...[
                const SizedBox(height: 6),
                Center(
                  child: JourneyTextAction(
                    key: ValueKey('money-budget-open-${row.id}'),
                    label: 'تفاصيل البند',
                    color: context.accent.primary,
                    onPressed: () {
                      Navigator.of(sheetContext).pop();
                      _openCategory(row);
                    },
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// Back to where the budget was opened from, or to the money tab when
  /// it was opened directly from a link.
  void _close(bool changed) =>
      context.popOrGo(AppRouter.money(widget.weddingPlanId), changed);

  void _hydrate(FinanceProvider provider) {
    if (_hydrated ||
        provider.loadedPlanId != widget.weddingPlanId ||
        !provider.hasLoadedMoney ||
        provider.errorMessage != null) {
      return;
    }
    _hydrated = true;
    _totalController.text = formatMoneyInputValue(
      provider.summary.budget.total,
    );
    _currency = provider.summary.currency;
    _replaceRows(provider);
    _configureDraft();
  }

  void _replaceRows(FinanceProvider provider) {
    for (final row in _rows) {
      row.dispose();
    }
    _rows
      ..clear()
      ..addAll(
        provider.budgetItems.map(
          (category) => _CategoryDraft(
            id: category.id,
            name: category.name,
            amount: category.allocatedAmount,
            confirmedCost: category.confirmedCost,
          ),
        ),
      );
    setState(() {});
  }

  Future<void> _openCategoryCreate() async {
    final createdId = await context.push<String?>(
      AppRouter.moneyCategoryCreate(widget.weddingPlanId),
    );
    if (createdId != null && mounted) await _refreshCategories();
  }

  Future<void> _openCategory(_CategoryDraft row) async {
    final id = row.id;
    if (id == null) return;
    final changed = await context.push<bool>(
      AppRouter.moneyCategoryDetails(widget.weddingPlanId, id),
    );
    if (changed == true && mounted) await _refreshCategories();
  }

  Future<void> _refreshCategories() async {
    final provider = context.read<FinanceProvider>();
    await provider.loadMoney(widget.weddingPlanId);
    if (!mounted || provider.errorMessage != null) return;
    _replaceRows(provider);
  }

  /// Each problem in plain words; null when the budget can be saved.
  String? _problem(String totalText, num total, num allocated) {
    if (totalText.isNotEmpty && total <= 0) {
      return context.say(
        'اكتب ميزانية أكبر من صفر',
        'اكتبي ميزانية أكبر من صفر',
      );
    }
    if (total <= 0 && _rows.isEmpty) {
      return context.say(
        'حدد ميزانية أو أضف بند قبل الحفظ',
        'حددي ميزانية أو أضيفي بند قبل الحفظ',
      );
    }
    final names = <String>{};
    for (final row in _rows) {
      if (!names.add(_normalizedCategoryName(row.name))) {
        return 'فيه بندين بنفس الاسم';
      }
    }
    if (total <= 0 && allocated > 0) {
      return context.say(
        'حدد ميزانية عرسك أول، بعدين وزّعها على البنود',
        'حددي ميزانية عرسك أول، بعدين وزّعيها على البنود',
      );
    }
    if (total > 0 && allocated > total) {
      return '${context.say('وزّعت', 'وزّعتِ')} ${_plain(allocated)}، وهذا أكثر من ميزانيتك بـ ${_plain(allocated - total)}';
    }
    return null;
  }

  Future<void> _save() async {
    final totalText = _totalController.text.replaceAll(',', '').trim();
    final total = moneyValue(totalText);
    final allocated = _rows.fold<num>(
      0,
      (sum, row) => sum + moneyValue(row.amount.text),
    );
    setState(() => _formError = _problem(totalText, total, allocated));
    if (_formError != null) return;
    final ok = await context.read<FinanceProvider>().saveBudget(
      planId: widget.weddingPlanId,
      totalBudget: totalText.isEmpty ? null : totalText,
      currency: _currency,
      categories: [
        for (final row in _rows)
          (
            id: row.id,
            name: row.name,
            allocatedAmount: row.amount.text.trim().isEmpty
                ? null
                : row.amount.text.replaceAll(',', '').trim(),
          ),
      ],
    );
    if (ok && mounted) {
      await _draft?.clear();
      if (!mounted) return;
      AarastFormSuccess.show(context, message: 'انحفظ التوزيع');
      _close(true);
    }
  }

  /// The total, the currency and every share are kept while unsaved.
  void _configureDraft() {
    if (_draft != null) return;
    _draft = AarastFormDraftBinding(
      store: context.read<AarastFormDraftStore?>(),
      scope: 'budget:${widget.weddingPlanId}',
      fields: {'total': _totalController},
      readExtras: () => {
        'currency': _currency,
        'shares': {
          for (final row in _rows)
            if (row.id != null) row.id!: row.amount.text,
        },
      },
      restoreExtras: (data) {
        if (!mounted) return;
        final currency = data['currency']?.toString();
        final shares = data['shares'];
        setState(() {
          if (currency != null &&
              weddingCurrencyOptions.any((option) => option.$1 == currency)) {
            _currency = currency;
          }
          if (shares is Map) {
            for (final row in _rows) {
              final text = shares[row.id];
              if (text is String) row.amount.text = text;
            }
          }
        });
      },
      onStatusChanged: () {
        if (mounted) setState(() {});
      },
    );
    unawaited(_draft!.restore());
  }
}

String _normalizedCategoryName(String value) {
  return value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}

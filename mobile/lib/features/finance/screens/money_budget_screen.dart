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
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/wedding_cost.dart';
import '../providers/finance_provider.dart';
import '../widgets/finance_write_access_block.dart';
import '../widgets/mahr_budget_choice.dart';
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

  /// D114: the groom's answer picked here; null until he picks one, so a
  /// save that did not touch it sends nothing.
  bool? _includesMahr;

  /// D114: the saved answer, and whether this plan is asked at all (the
  /// groom pays the mahr; a bride's plan receives it).
  bool _savedInside(FinanceProvider provider) =>
      provider.summary.budget.includesMahr;
  bool get _asked => context.journeyProfile.paysMahr;

  bool _inside(FinanceProvider provider) =>
      _asked && (_includesMahr ?? _savedInside(provider));

  /// What the mahr takes of the budget when it is inside: its expected
  /// cost, as the server holds the items' room (D114).
  num _mahrTaken(FinanceProvider provider) => _inside(provider)
      ? moneyValue(provider.summary.expected?.mahr.expected)
      : 0;

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
        provider.loadErrorMessage == null) {
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
    final inside = _inside(provider);
    final mahrTaken = _mahrTaken(provider);
    final reserve = total - mahrTaken - allocated;

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
              title: 'توزيع الميزانية',
              // D114: the mahr where the groom put it.
              subtitle: inside
                  ? (total > 0
                        ? '${_plain(total)} · فيها المهر'
                        : 'الميزانية فيها المهر')
                  : total > 0
                  ? '${_plain(total)} لعرسك · المهر لحاله'
                  : 'المهر لحاله، برا الميزانية',
              onBack: () => _close(false),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AarastV3Space.x4,
                0,
                AarastV3Space.x4,
                AarastV3Space.x6,
              ),
              children: [
                if (provider.loadErrorMessage != null) ...[
                  JourneyListNotice(
                    offline: false,
                    onRetry: () => provider.loadMoney(widget.weddingPlanId),
                  ),
                  const SizedBox(height: AarastV3Space.x3),
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
                if (mahrTaken > 0 && total > 0) ...[
                  const SizedBox(height: AarastV3Space.x2),
                  Text(
                    'المهر ${_plain(mahrTaken)} من الميزانية، والاحتياط بعده.',
                    key: const ValueKey('money-budget-mahr-note'),
                    style: JourneyType.of(
                      JourneyType.small,
                      color: AarastV3Color.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: AarastV3Space.x3),
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
                const SizedBox(height: AarastV3Space.x2),
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
                  const SizedBox(height: AarastV3Space.x2),
                  JourneyNote(
                    key: const ValueKey('money-budget-error'),
                    text: _formError!,
                    icon: LucideIcons.alertTriangle,
                    color: AarastV3Color.danger,
                    soft: AarastV3Color.dangerSoft,
                  ),
                ],
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

  /// «ميزانيتك» and its currency, in a sheet over the split; on a groom's
  /// plan, whether it holds the mahr (D114).
  Future<void> _editTotal() {
    final provider = context.read<FinanceProvider>();
    final currencyLocked = provider.summary.currencyFixed;
    final mahr = provider.summary.mahrCategory;
    // The choice is seen once before the sheet closes on a new total: with
    // the keyboard up on a small phone it sat under it. A sheet closed with
    // the total as it was, or with the choice already picked, closes at
    // once; a press spent on showing the choice says so.
    final choiceKey = GlobalKey();
    final totalBefore = moneyValue(_totalController.text);
    var choiceSeen = false;
    var choiceAsked = false;
    return showJourneySheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final total = moneyValue(_totalController.text);
          return JourneySheetBody(
            title: 'ميزانيتك',
            subtitle: _asked
                ? 'كم تقريبًا، وهل فيها المهر'
                : 'المهر لحاله، برا الميزانية',
            // Pinned under what scrolls: with the mahr's question the sheet
            // is taller than a 320 phone at 1.3, and «تمام» fell off it.
            bottom: JourneyButton(
              key: const ValueKey('money-budget-total-done'),
              label: 'تمام',
              expand: true,
              large: true,
              onPressed: () {
                if (_asked &&
                    !choiceSeen &&
                    _includesMahr == null &&
                    moneyValue(_totalController.text) != totalBefore) {
                  choiceSeen = true;
                  if (!mahrChoiceOnScreen(choiceKey)) {
                    setSheetState(() => choiceAsked = true);
                    revealMahrChoice(choiceKey);
                    return;
                  }
                }
                Navigator.of(sheetContext).pop();
              },
            ),
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
              const SizedBox(height: AarastV3Space.x3),
              if (currencyLocked)
                Text(
                  // RA-BE-23: an agreement or a source (the mahr) fixes it.
                  'العملة ${currencySpokenLabelAr(_currency)}، ثابتة بعد ما يتسجّل فيها مال',
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
              if (_asked) ...[
                const SizedBox(height: AarastV3Space.x4),
                MahrBudgetChoice(
                  key: choiceKey,
                  inside: _inside(provider),
                  budget: total,
                  mahr: moneyValue(mahr?.confirmedCost),
                  currency: _currency,
                  asksBeforeGoingOn: choiceAsked,
                  onChanged: (inside) {
                    setSheetState(() => choiceAsked = false);
                    setState(() => _includesMahr = inside);
                    _draft?.changed();
                  },
                ),
              ],
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
              const SizedBox(height: AarastV3Space.x4),
              JourneyButton(
                key: const ValueKey('money-budget-share-done'),
                label: 'تمام',
                expand: true,
                large: true,
                onPressed: () => Navigator.of(sheetContext).pop(),
              ),
              if (row.id != null) ...[
                const SizedBox(height: AarastV3Space.x1),
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
        provider.loadErrorMessage != null) {
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

  /// D86: what the person typed in the shares survives a visit to an item
  /// or a new one; only the rows change under it.
  Future<void> _refreshCategories() async {
    final provider = context.read<FinanceProvider>();
    final typed = {
      for (final row in _rows)
        if (row.id != null) row.id!: row.amount.text,
    };
    await provider.loadMoney(widget.weddingPlanId);
    if (!mounted || provider.loadErrorMessage != null) return;
    _replaceRows(provider);
    for (final row in _rows) {
      final kept = typed[row.id];
      if (kept != null && kept != row.amount.text) row.amount.text = kept;
    }
    setState(() {});
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
    // D114, as the server holds it: with the mahr inside, the items get
    // what is left after it; a split given no more than before still saves.
    final provider = context.read<FinanceProvider>();
    final room = total - _mahrTaken(provider);
    if (total > 0 &&
        allocated > room &&
        allocated > moneyValue(provider.summary.budget.allocated)) {
      return 'المهر ${_plain(_mahrTaken(provider))} من الميزانية، و${context.say('وزّعت', 'وزّعتِ')} ${_plain(allocated)}، أكثر من اللي يبقى بعده بـ ${_plain(allocated - room)}';
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
    final provider = context.read<FinanceProvider>();
    // D114: sent only when he changed it, so a server that does not know
    // the choice is never sent it for nothing.
    final includesMahr = _includesMahr;
    final ok = await provider.saveBudget(
      planId: widget.weddingPlanId,
      totalBudget: totalText.isEmpty ? null : totalText,
      currency: _currency,
      budgetIncludesMahr:
          _asked &&
              includesMahr != null &&
              includesMahr != _savedInside(provider)
          ? includesMahr
          : null,
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
    if (!mounted) return;
    if (!ok) {
      AarastToast.showError(
        context,
        provider.errorMessage ?? 'ما انحفظ التوزيع',
      );
      return;
    }
    await _draft?.clear();
    if (!mounted) return;
    AarastFormSuccess.show(context, message: 'انحفظ التوزيع');
    _close(true);
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
        'includesMahr': ?_includesMahr,
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
          if (data['includesMahr'] case final bool kept) _includesMahr = kept;
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

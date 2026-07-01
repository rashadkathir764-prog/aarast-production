import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../finance/widgets/yemeni_money_text.dart';
import '../../sharing/models/shared_member.dart';
import '../models/debt.dart';
import '../models/debt_summary.dart';
import '../models/installment.dart';
import '../providers/debt_installment_provider.dart';

class DebtInstallmentScreen extends StatefulWidget {
  const DebtInstallmentScreen({
    required this.weddingPlanId,
    this.sharedMember,
    super.key,
  });

  final String weddingPlanId;
  final SharedMember? sharedMember;

  @override
  State<DebtInstallmentScreen> createState() => _DebtInstallmentScreenState();
}

class _DebtInstallmentScreenState extends State<DebtInstallmentScreen> {
  final _searchController = TextEditingController();
  _DebtListFilter _selectedFilter = _DebtListFilter.all;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadDebts();
    });
  }

  @override
  void didUpdateWidget(covariant DebtInstallmentScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _loadDebts();
      });
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DebtInstallmentProvider>();
    final canManageFinancialRecords = _canManageFinancialRecords;

    return AarastScreenFrame(
      maxWidth: 520,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: _goBack,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  tooltip: 'رجوع',
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'الديون والأقساط',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.burgundyDeep,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'تابع ديون خطتك وأقساطها المستحقة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (canManageFinancialRecords)
                  IconButton(
                    onPressed: () => context.push(
                      AppRouter.createDebt(widget.weddingPlanId),
                      extra: widget.sharedMember,
                    ),
                    icon: const Icon(Icons.add_rounded),
                    tooltip: 'إضافة دين',
                    style: IconButton.styleFrom(
                      backgroundColor: AppTheme.burgundy,
                      foregroundColor: Colors.white,
                      side: BorderSide.none,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppTheme.burgundy,
              onRefresh: _loadDebts,
              child: _canReadDebts
                  ? _DebtInstallmentContent(
                      provider: provider,
                      weddingPlanId: widget.weddingPlanId,
                      canManageFinancialRecords: canManageFinancialRecords,
                      sharedMember: widget.sharedMember,
                      searchController: _searchController,
                      selectedFilter: _selectedFilter,
                      suppressErrors: false,
                      onFilterChanged: (filter) {
                        setState(() {
                          _selectedFilter = filter;
                        });
                      },
                    )
                  : const _DebtAccessDeniedState(),
            ),
          ),
        ],
      ),
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRouter.home);
  }

  bool get _canReadDebts =>
      widget.sharedMember == null || widget.sharedMember!.canReadDebts;

  bool get _canManageFinancialRecords =>
      widget.sharedMember == null ||
      widget.sharedMember!.canManageFinancialRecords;

  Future<void> _loadDebts() {
    if (!_canReadDebts) {
      return Future<void>.value();
    }
    return context.read<DebtInstallmentProvider>().loadDebts(
      widget.weddingPlanId,
    );
  }

  void _handleSearchChanged() {
    setState(() {});
  }
}

class _DebtInstallmentContent extends StatelessWidget {
  const _DebtInstallmentContent({
    required this.provider,
    required this.weddingPlanId,
    required this.canManageFinancialRecords,
    required this.sharedMember,
    required this.searchController,
    required this.selectedFilter,
    required this.onFilterChanged,
    this.suppressErrors = false,
  });

  final DebtInstallmentProvider provider;
  final String weddingPlanId;
  final bool canManageFinancialRecords;
  final SharedMember? sharedMember;
  final TextEditingController searchController;
  final _DebtListFilter selectedFilter;
  final ValueChanged<_DebtListFilter> onFilterChanged;
  final bool suppressErrors;

  @override
  Widget build(BuildContext context) {
    final debts = suppressErrors ? const <Debt>[] : provider.debts;
    final dueInstallments = suppressErrors
        ? const <Installment>[]
        : provider.dueInstallments;
    final summary = suppressErrors ? DebtSummary.empty() : provider.summary;

    if (!suppressErrors && provider.isLoading && debts.isEmpty) {
      return const _DebtLoadingState();
    }

    if (!suppressErrors && provider.errorMessage != null && debts.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 56, 20, 120),
        children: [
          AarastEmptyState(
            title: 'تعذر تحميل الديون',
            message: provider.errorMessage!,
            icon: Icons.error_outline_rounded,
            action: ElevatedButton.icon(
              onPressed: () => provider.loadDebts(weddingPlanId),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      );
    }

    final query = searchController.text.trim();
    final visibleDebts = debts.where((debt) {
      return _matchesSearch(debt, query, dueInstallments) &&
          _matchesFilter(debt, selectedFilter, dueInstallments);
    }).toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 124),
      children: [
        if (!suppressErrors && provider.errorMessage != null) ...[
          _InlineError(message: provider.errorMessage!),
          const SizedBox(height: 14),
        ],
        _DebtSearchRow(controller: searchController),
        const SizedBox(height: 12),
        _DebtSummaryGrid(summary: summary, dueInstallments: dueInstallments),
        const SizedBox(height: 12),
        _DebtFilterChips(
          selectedFilter: selectedFilter,
          onFilterChanged: onFilterChanged,
        ),
        const SizedBox(height: 12),
        if (debts.isEmpty)
          AarastEmptyState(
            title: 'لا توجد ديون بعد',
            message: 'أضف أول دين لتتبع الأقساط',
            icon: Icons.receipt_long_outlined,
            action: canManageFinancialRecords
                ? ElevatedButton.icon(
                    onPressed: () => context.push(
                      AppRouter.createDebt(weddingPlanId),
                      extra: sharedMember,
                    ),
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('إضافة دين جديد'),
                  )
                : null,
          )
        else if (visibleDebts.isEmpty)
          const AarastEmptyState(
            title: 'لا توجد نتائج مطابقة',
            message: 'جرّب تغيير كلمة البحث أو حالة التصفية',
            icon: Icons.search_off_rounded,
          )
        else
          for (final debt in visibleDebts) ...[
            _DebtCard(
              debt: debt,
              dueInstallments: dueInstallments,
              onTap: () {
                provider.selectDebt(debt);
                context.push(AppRouter.debtDetails(debt.id));
              },
            ),
            const SizedBox(height: 10),
          ],
        if (canManageFinancialRecords && debts.isNotEmpty) ...[
          const SizedBox(height: 4),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => context.push(
                AppRouter.createDebt(weddingPlanId),
                extra: sharedMember,
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة دين جديد'),
            ),
          ),
        ],
      ],
    );
  }
}

class _DebtSearchRow extends StatelessWidget {
  const _DebtSearchRow({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textAlign: TextAlign.right,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'ابحث عن شخص أو دين...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: controller.clear,
                      icon: const Icon(Icons.close_rounded),
                      tooltip: 'مسح البحث',
                    ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(
          onPressed: () {},
          icon: const Icon(Icons.tune_rounded),
          tooltip: 'تصفية',
        ),
      ],
    );
  }
}

class _DebtSummaryGrid extends StatelessWidget {
  const _DebtSummaryGrid({
    required this.summary,
    required this.dueInstallments,
  });

  final DebtSummary summary;
  final List<Installment> dueInstallments;

  @override
  Widget build(BuildContext context) {
    final nextInstallment = _nearestInstallment(dueInstallments);

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth < 340
            ? constraints.maxWidth
            : (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _SummaryTile(
              width: itemWidth,
              label: 'إجمالي الديون',
              moneyValue: _moneyValue(summary.totalDebt),
              color: AppTheme.burgundy,
              icon: Icons.account_balance_wallet_outlined,
            ),
            _SummaryTile(
              width: itemWidth,
              label: 'المدفوع',
              moneyValue: _moneyValue(summary.totalPaid),
              color: AppTheme.success,
              icon: Icons.check_circle_outline_rounded,
            ),
            _SummaryTile(
              width: itemWidth,
              label: 'المتبقي',
              moneyValue: _moneyValue(summary.remainingDebt),
              color: AppTheme.danger,
              icon: Icons.pending_actions_rounded,
            ),
            _SummaryTile(
              width: itemWidth,
              label: 'أقرب قسط',
              value: nextInstallment?.dueDate == null
                  ? '-'
                  : _shortDate(nextInstallment!.dueDate!),
              color: AppTheme.ink,
              icon: Icons.calendar_month_rounded,
              ltrValue: true,
            ),
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.width,
    required this.label,
    required this.color,
    required this.icon,
    this.value,
    this.moneyValue,
    this.ltrValue = false,
  });

  final double width;
  final String label;
  final String? value;
  final num? moneyValue;
  final Color color;
  final IconData icon;
  final bool ltrValue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AarastCard(
        padding: const EdgeInsets.all(12),
        radius: AppTheme.radiusMd,
        border: Border.all(color: AppTheme.border),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppTheme.radiusSm),
              ),
              child: Icon(icon, color: color, size: 19),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.muted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (moneyValue == null)
                    Text(
                      value ?? '',
                      textDirection: ltrValue ? TextDirection.ltr : null,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  else
                    YemeniMoneyText(
                      moneyValue!,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DebtFilterChips extends StatelessWidget {
  const _DebtFilterChips({
    required this.selectedFilter,
    required this.onFilterChanged,
  });

  final _DebtListFilter selectedFilter;
  final ValueChanged<_DebtListFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final filter in _DebtListFilter.values) ...[
            ChoiceChip(
              label: Text(_filterLabel(filter)),
              selected: selectedFilter == filter,
              onSelected: (_) => onFilterChanged(filter),
              showCheckmark: false,
              avatar: selectedFilter == filter
                  ? const Icon(Icons.check_rounded, size: 16)
                  : null,
              labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selectedFilter == filter
                    ? Colors.white
                    : AppTheme.muted,
                fontWeight: FontWeight.w900,
              ),
              selectedColor: AppTheme.burgundy,
              backgroundColor: AppTheme.surface,
              side: const BorderSide(color: AppTheme.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _DebtCard extends StatelessWidget {
  const _DebtCard({
    required this.debt,
    required this.dueInstallments,
    required this.onTap,
  });

  final Debt debt;
  final List<Installment> dueInstallments;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _debtUiStatus(debt, dueInstallments);
    final color = _debtUiStatusColor(status);
    final nextDate = _nextDebtDate(debt, dueInstallments);
    final remaining = _moneyValue(debt.remainingAmount);

    return AarastCard(
      padding: const EdgeInsets.all(14),
      radius: AppTheme.radiusLg,
      onTap: onTap,
      border: Border.all(color: AppTheme.border),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _DebtAvatar(name: debt.creditorName, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.creditorName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      debt.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AarastStatusPill(label: _debtUiStatusLabel(status), color: color),
              const SizedBox(width: 6),
              const Icon(
                Icons.chevron_left_rounded,
                color: AppTheme.muted,
                size: 22,
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = constraints.maxWidth < 320
                  ? constraints.maxWidth
                  : (constraints.maxWidth - 8) / 2;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DebtMiniMetric(
                    width: itemWidth,
                    label: 'إجمالي الدين',
                    moneyValue: _moneyValue(debt.totalAmount),
                    color: AppTheme.ink,
                  ),
                  _DebtMiniMetric(
                    width: itemWidth,
                    label: 'المدفوع',
                    moneyValue: _moneyValue(debt.paidAmount),
                    color: AppTheme.success,
                  ),
                  _DebtMiniMetric(
                    width: itemWidth,
                    label: 'المتبقي',
                    moneyValue: remaining,
                    color: remaining <= 0 ? AppTheme.success : AppTheme.danger,
                  ),
                  _DebtMiniMetric(
                    width: itemWidth,
                    label: 'أقرب قسط',
                    value: nextDate == null ? '-' : _shortDate(nextDate),
                    color: AppTheme.gold,
                    ltrValue: nextDate != null,
                  ),
                ],
              );
            },
          ),
          if (debt.hasNote) ...[
            const SizedBox(height: 10),
            Text(
              debt.note!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DebtAvatar extends StatelessWidget {
  const _DebtAvatar({required this.name, required this.color});

  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed.substring(0, 1);
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Text(
        initial,
        maxLines: 1,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DebtMiniMetric extends StatelessWidget {
  const _DebtMiniMetric({
    required this.width,
    required this.label,
    required this.color,
    this.value,
    this.moneyValue,
    this.ltrValue = false,
  });

  final double width;
  final String label;
  final String? value;
  final num? moneyValue;
  final Color color;
  final bool ltrValue;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.ivory,
          borderRadius: BorderRadius.circular(AppTheme.radiusSm),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            if (moneyValue == null)
              Text(
                value ?? '',
                textDirection: ltrValue ? TextDirection.ltr : null,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              )
            else
              YemeniMoneyText(
                moneyValue!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w900,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DebtLoadingState extends StatelessWidget {
  const _DebtLoadingState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 120),
      children: const [
        _SkeletonBox(height: 52),
        SizedBox(height: 12),
        _SkeletonBox(height: 154),
        SizedBox(height: 12),
        _SkeletonBox(height: 42),
        SizedBox(height: 12),
        _SkeletonBox(height: 150),
        SizedBox(height: 10),
        _SkeletonBox(height: 150),
      ],
    );
  }
}

class _DebtAccessDeniedState extends StatelessWidget {
  const _DebtAccessDeniedState();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 56, 20, 120),
      children: const [
        AarastEmptyState(
          title: 'الديون والأقساط خاصة',
          message: 'ليست لديك صلاحية عرض التفاصيل المالية.',
          icon: Icons.lock_outline_rounded,
        ),
      ],
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.border),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dangerSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dangerSoft),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _DebtListFilter { all, active, overdue, completed }

enum _DebtUiStatus { active, overdue, completed }

bool _matchesSearch(
  Debt debt,
  String query,
  List<Installment> dueInstallments,
) {
  if (query.isEmpty) return true;
  final normalizedQuery = _normalizeSearch(query);
  final status = _debtUiStatus(debt, dueInstallments);
  final fields = [
    debt.creditorName,
    debt.title,
    debt.note ?? '',
    debt.status,
    _debtUiStatusLabel(status),
  ];
  return fields.any(
    (field) => _normalizeSearch(field).contains(normalizedQuery),
  );
}

bool _matchesFilter(
  Debt debt,
  _DebtListFilter filter,
  List<Installment> dueInstallments,
) {
  final status = _debtUiStatus(debt, dueInstallments);
  return switch (filter) {
    _DebtListFilter.all => true,
    _DebtListFilter.active => status == _DebtUiStatus.active,
    _DebtListFilter.overdue => status == _DebtUiStatus.overdue,
    _DebtListFilter.completed => status == _DebtUiStatus.completed,
  };
}

_DebtUiStatus _debtUiStatus(Debt debt, List<Installment> dueInstallments) {
  if (debt.status == 'PAID' || _moneyValue(debt.remainingAmount) <= 0) {
    return _DebtUiStatus.completed;
  }
  if (_hasOverdueInstallment(debt.id, dueInstallments) ||
      _isPastDate(debt.dueDate)) {
    return _DebtUiStatus.overdue;
  }
  return _DebtUiStatus.active;
}

bool _hasOverdueInstallment(String debtId, List<Installment> installments) {
  return installments.any((installment) {
    return installment.debtId == debtId &&
        (installment.status == 'OVERDUE' || _isPastDate(installment.dueDate));
  });
}

bool _isPastDate(DateTime? date) {
  if (date == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  return day.isBefore(today);
}

DateTime? _nextDebtDate(Debt debt, List<Installment> dueInstallments) {
  final debtInstallments =
      dueInstallments
          .where((installment) {
            return installment.debtId == debt.id && installment.dueDate != null;
          })
          .map((installment) => installment.dueDate!)
          .toList()
        ..sort();
  if (debtInstallments.isNotEmpty) return debtInstallments.first;
  return debt.dueDate;
}

Installment? _nearestInstallment(List<Installment> installments) {
  final sorted =
      installments.where((installment) => installment.dueDate != null).toList()
        ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  return sorted.isEmpty ? null : sorted.first;
}

String _filterLabel(_DebtListFilter filter) {
  return switch (filter) {
    _DebtListFilter.all => 'الكل',
    _DebtListFilter.active => 'نشط',
    _DebtListFilter.overdue => 'متأخر',
    _DebtListFilter.completed => 'مكتمل',
  };
}

String _debtUiStatusLabel(_DebtUiStatus status) {
  return switch (status) {
    _DebtUiStatus.active => 'نشط',
    _DebtUiStatus.overdue => 'متأخر',
    _DebtUiStatus.completed => 'مكتمل',
  };
}

Color _debtUiStatusColor(_DebtUiStatus status) {
  return switch (status) {
    _DebtUiStatus.active => AppTheme.burgundy,
    _DebtUiStatus.overdue => AppTheme.danger,
    _DebtUiStatus.completed => AppTheme.success,
  };
}

num _moneyValue(String value) =>
    num.tryParse(value.replaceAll(',', '').trim()) ?? 0;

String _shortDate(DateTime date) {
  return formatArabicCompactDate(date);
}

String _normalizeSearch(String value) {
  return value
      .toLowerCase()
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(',', '')
      .trim();
}

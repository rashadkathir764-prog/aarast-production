import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../providers/finance_provider.dart';
import '../widgets/money_widgets.dart';

class CostsScreen extends StatefulWidget {
  const CostsScreen({
    required this.weddingPlanId,
    this.initialCategoryId,
    super.key,
  });

  final String weddingPlanId;
  final String? initialCategoryId;

  @override
  State<CostsScreen> createState() => _CostsScreenState();
}

class _CostsScreenState extends State<CostsScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String? _status;
  String? _categoryId;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.initialCategoryId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitial());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    return MoneySubpageScaffold(
      title: 'كل التكاليف',
      subtitle: 'ابحث أو صفِّ حسب الحالة والتصنيف.',
      showBack: true,
      onBack: () => context.pop(),
      actions: [
        if (provider.canManageMoney)
          IconButton(
            onPressed: _createCost,
            icon: const Icon(LucideIcons.plus),
            tooltip: 'إضافة تكلفة',
          ),
      ],
      child: RefreshIndicator(
        color: AppTheme.brand,
        onRefresh: _applyFilters,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            if (provider.hasLoadedMoney || provider.errorMessage == null) ...[
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'ابحث عن تكلفة أو جهة',
                  prefixIcon: const Icon(LucideIcons.search, size: 19),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                            _applyFilters();
                          },
                          icon: const Icon(LucideIcons.x, size: 18),
                          tooltip: 'مسح البحث',
                        ),
                ),
                onChanged: (_) {
                  setState(() {});
                  _debounce?.cancel();
                  _debounce = Timer(
                    const Duration(milliseconds: 350),
                    _applyFilters,
                  );
                },
                onSubmitted: (_) => _applyFilters(),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _FilterChip(
                      label: 'الكل',
                      selected: _status == null,
                      onTap: () => _setStatus(null),
                    ),
                    _FilterChip(
                      label: 'غير مدفوعة',
                      selected: _status == 'OPEN',
                      onTap: () => _setStatus('OPEN'),
                    ),
                    _FilterChip(
                      label: 'مكتملة',
                      selected: _status == 'PAID',
                      onTap: () => _setStatus('PAID'),
                    ),
                    _MoreFiltersButton(
                      count:
                          (_categoryId == null ? 0 : 1) +
                          (_status == 'PARTIALLY_PAID' || _status == 'CANCELLED'
                              ? 1
                              : 0),
                      onPressed: () => _showMoreFilters(provider),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (provider.hasLoadedMoney && provider.errorMessage != null) ...[
              MoneyMessageBanner(message: provider.errorMessage!, error: true),
              const SizedBox(height: 12),
            ],
            if (!provider.hasLoadedMoney && provider.isLoading)
              const AarastScreenLoading(label: 'جاري تحميل التكاليف')
            else if (!provider.hasLoadedMoney && provider.errorMessage != null)
              AarastErrorState(
                title: 'تعذر تحميل التكاليف',
                message: provider.errorMessage!,
                onRetry: _loadInitial,
              )
            else if (!provider.hasLoadedMoney)
              const AarastScreenLoading(label: 'جاري تحميل التكاليف')
            else if (provider.isLoadingMoreCosts && provider.costs.isEmpty)
              const AarastScreenLoading(label: 'جاري البحث في التكاليف')
            else if (provider.costs.isEmpty)
              const AarastEmptyState(
                icon: LucideIcons.searchX,
                title: 'لا توجد نتائج',
                message: 'غيّر البحث أو الفلاتر، أو أضف تكلفة جديدة.',
              )
            else
              DecoratedBox(
                decoration: const BoxDecoration(
                  border: Border.symmetric(
                    horizontal: BorderSide(color: AppTheme.borderStrong),
                  ),
                ),
                child: Column(
                  children: [
                    for (
                      var index = 0;
                      index < provider.costs.length;
                      index++
                    ) ...[
                      CostCard(
                        cost: provider.costs[index],
                        currency: provider.summary.currency,
                        categoryName: provider
                            .categoryById(
                              provider.costs[index].budgetCategoryId,
                            )
                            ?.name,
                        onTap: () => context.push(
                          AppRouter.moneyCostDetails(
                            widget.weddingPlanId,
                            provider.costs[index].id,
                          ),
                        ),
                      ),
                      if (index != provider.costs.length - 1)
                        const Divider(
                          height: 1,
                          indent: 50,
                          color: AppTheme.borderStrong,
                        ),
                    ],
                  ],
                ),
              ),
            if (provider.hasMoreCosts) ...[
              const SizedBox(height: 6),
              OutlinedButton.icon(
                onPressed: provider.isLoadingMoreCosts ? null : _loadMore,
                icon: provider.isLoadingMoreCosts
                    ? const AarastInlineSpinner()
                    : const Icon(LucideIcons.chevronsDown),
                label: const Text('تحميل المزيد'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _setStatus(String? value) {
    setState(() => _status = value);
    _applyFilters();
  }

  Future<void> _showMoreFilters(FinanceProvider provider) async {
    var status = _status;
    var categoryId = _categoryId;
    final result = await showAarastBottomSheet<_CostFilters>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AarastBottomSheetHandle(),
                Text(
                  'تصفية التكاليف',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: status,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'الحالة',
                    prefixIcon: Icon(LucideIcons.circleDot),
                  ),
                  items: const [
                    DropdownMenuItem<String?>(
                      value: null,
                      child: Text('كل الحالات'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'OPEN',
                      child: Text('غير مدفوعة'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'PARTIALLY_PAID',
                      child: Text('مدفوعة جزئيًا'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'PAID',
                      child: Text('مكتملة'),
                    ),
                    DropdownMenuItem<String?>(
                      value: 'CANCELLED',
                      child: Text('ملغاة'),
                    ),
                  ],
                  onChanged: (value) => setSheetState(() => status = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  initialValue: categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'التصنيف',
                    prefixIcon: Icon(LucideIcons.tags),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('كل التصنيفات'),
                    ),
                    for (final category in provider.categories)
                      DropdownMenuItem<String?>(
                        value: category.id,
                        child: Text(
                          category.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) => setSheetState(() => categoryId = value),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(
                          sheetContext,
                        ).pop(const _CostFilters()),
                        child: const Text('إعادة ضبط'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(sheetContext).pop(
                          _CostFilters(status: status, categoryId: categoryId),
                        ),
                        icon: const Icon(LucideIcons.slidersHorizontal),
                        label: const Text('تطبيق التصفية'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      _status = result.status;
      _categoryId = result.categoryId;
    });
    await _applyFilters();
  }

  Future<void> _applyFilters() {
    return context.read<FinanceProvider>().filterCosts(
      status: _status,
      categoryId: _categoryId,
      search: _searchController.text,
    );
  }

  Future<void> _loadInitial() async {
    final provider = context.read<FinanceProvider>();
    await provider.loadMoney(widget.weddingPlanId);
    if (!mounted ||
        !provider.hasLoadedMoney ||
        provider.errorMessage != null ||
        _categoryId == null) {
      return;
    }
    await _applyFilters();
  }

  Future<void> _loadMore() {
    return context.read<FinanceProvider>().loadMoreCosts(
      status: _status,
      categoryId: _categoryId,
      search: _searchController.text,
    );
  }

  Future<void> _createCost() async {
    final changed = await context.push<bool>(
      AppRouter.moneyCostCreate(widget.weddingPlanId, categoryId: _categoryId),
    );
    if (changed == true && mounted) await _applyFilters();
  }
}

class _CostFilters {
  const _CostFilters({this.status, this.categoryId});

  final String? status;
  final String? categoryId;
}

class _MoreFiltersButton extends StatelessWidget {
  const _MoreFiltersButton({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 13),
        ),
        icon: const Icon(LucideIcons.slidersHorizontal, size: 17),
        label: Text(count == 0 ? 'تصفية' : 'تصفية · $count'),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      ),
    );
  }
}

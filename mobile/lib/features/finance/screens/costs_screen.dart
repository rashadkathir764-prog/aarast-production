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
        color: AppTheme.burgundy,
        onRefresh: _applyFilters,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            if (provider.hasLoadedMoney || provider.errorMessage == null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        labelText: 'ابحث عن تكلفة أو جهة',
                        prefixIcon: const Icon(LucideIcons.search),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {});
                                  _applyFilters();
                                },
                                icon: const Icon(LucideIcons.x),
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
                            label: 'مفتوحة',
                            selected: _status == 'OPEN',
                            onTap: () => _setStatus('OPEN'),
                          ),
                          _FilterChip(
                            label: 'مدفوعة جزئيًا',
                            selected: _status == 'PARTIALLY_PAID',
                            onTap: () => _setStatus('PARTIALLY_PAID'),
                          ),
                          _FilterChip(
                            label: 'مكتملة',
                            selected: _status == 'PAID',
                            onTap: () => _setStatus('PAID'),
                          ),
                          _FilterChip(
                            label: 'ملغاة',
                            selected: _status == 'CANCELLED',
                            onTap: () => _setStatus('CANCELLED'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String?>(
                      initialValue: _categoryId,
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
                      onChanged: (value) {
                        setState(() => _categoryId = value);
                        _applyFilters();
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
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
              for (final cost in provider.costs) ...[
                CostCard(
                  cost: cost,
                  currency: provider.summary.currency,
                  categoryName: provider
                      .categoryById(cost.budgetCategoryId)
                      ?.name,
                  onTap: () => context.push(
                    AppRouter.moneyCostDetails(widget.weddingPlanId, cost.id),
                  ),
                ),
                const SizedBox(height: 10),
              ],
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

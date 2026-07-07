part of 'create_expense_screen.dart';

class _ExpenseHero extends StatelessWidget {
  const _ExpenseHero({required this.isEditMode});

  final bool isEditMode;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.ivory,
      border: Border.all(color: AppTheme.goldSoft),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              gradient: AppTheme.goldGradient,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: const Icon(
              LucideIcons.wallet,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEditMode ? 'راجع المصروف المدفوع' : 'سجّل مبلغًا خرج فعلاً',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.burgundyDeep,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isEditMode
                      ? 'التعديل هنا يغيّر سجل دفع فعلي فقط.'
                      : 'الحجوزات والباقي والأقساط تُدار من الالتزامات المالية، أما هنا فالمبلغ المدفوع فقط.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w700,
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

class _CategoryDateRow extends StatelessWidget {
  const _CategoryDateRow({
    required this.category,
    required this.expenseDate,
    required this.dateLabel,
    required this.onCategoryTap,
    required this.onDateTap,
  });

  final BudgetCategory? category;
  final DateTime? expenseDate;
  final String dateLabel;
  final VoidCallback onCategoryTap;
  final VoidCallback onDateTap;

  @override
  Widget build(BuildContext context) {
    final categoryField = _SelectorField(
      label: 'التصنيف المالي',
      value: category?.name ?? 'اختر التصنيف',
      icon: LucideIcons.folder,
      selected: category != null,
      onTap: onCategoryTap,
    );
    final dateField = _SelectorField(
      label: dateLabel,
      value: expenseDate == null ? 'لم يحدد بعد' : _formatDate(expenseDate!),
      icon: LucideIcons.calendar,
      selected: expenseDate != null,
      onTap: onDateTap,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 330) {
          return Column(
            children: [categoryField, const SizedBox(height: 12), dateField],
          );
        }
        return Row(
          children: [
            Expanded(child: categoryField),
            const SizedBox(width: 12),
            Expanded(child: dateField),
          ],
        );
      },
    );
  }
}

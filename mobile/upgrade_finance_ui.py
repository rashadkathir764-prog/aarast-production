import re

# 1. Upgrade ExpenseSummaryCard
summary_path = r"d:\projects\aarast\mobile\lib\features\finance\widgets\expense_summary_card.dart"
with open(summary_path, 'r', encoding='utf-8') as f:
    content = f.read()

new_summary_build = """  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppTheme.heroDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: AppTheme.dGold, size: 24),
                const SizedBox(width: 8),
                Text(
                  'ملخص المصاريف',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _SummaryChip(
                    label: 'مدفوع',
                    amount: summary.totalPaid,
                    count: summary.countPaid,
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _SummaryChip(
                    label: 'مخطط',
                    amount: summary.totalPlanned,
                    count: summary.countPlanned,
                    color: AppTheme.dGold2,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.amount,
    required this.count,
    required this.color,
  });

  final String label;
  final String amount;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(20),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$count عنصر',
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$amount YER',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }"""

content = re.sub(r"  @override\n  Widget build\(BuildContext context\) \{.*?\n  \}", new_summary_build, content, flags=re.DOTALL)

with open(summary_path, 'w', encoding='utf-8') as f:
    f.write(content)


# 2. Upgrade ExpenseItemCard
item_path = r"d:\projects\aarast\mobile\lib\features\finance\widgets\expense_item_card.dart"
with open(item_path, 'r', encoding='utf-8') as f:
    item_content = f.read()

new_item_build = """  @override
  Widget build(BuildContext context) {
    final categoryName = _categoryName();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.premiumCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _StatusBadge(status: expense.status),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    expense.title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.dInk,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (categoryName != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.dBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      categoryName,
                      style: const TextStyle(color: AppTheme.dMaroon, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  )
                else
                  const SizedBox(),
                Text(
                  '${expense.amount} YER',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.dMaroon,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            if (expense.expenseDate != null || expense.hasNote) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(color: AppTheme.dLine, height: 1),
              ),
              if (expense.expenseDate != null)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      _formatDate(expense.expenseDate!),
                      style: const TextStyle(color: AppTheme.dInkSoft, fontSize: 12),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.dMuted),
                  ],
                ),
              if (expense.hasNote) ...[
                const SizedBox(height: 4),
                Text(
                  expense.note!,
                  textAlign: TextAlign.right,
                  style: const TextStyle(color: AppTheme.dInkSoft, fontSize: 13),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }"""

item_content = re.sub(r"  @override\n  Widget build\(BuildContext context\) \{.*?\n  \}", new_item_build, item_content, flags=re.DOTALL)

with open(item_path, 'w', encoding='utf-8') as f:
    f.write(item_content)


print("Finance UI upgraded!")

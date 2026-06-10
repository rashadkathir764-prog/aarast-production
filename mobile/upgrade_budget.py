import re

budget_path = r"d:\projects\aarast\mobile\lib\features\finance\widgets\budget_category_card.dart"
with open(budget_path, 'r', encoding='utf-8') as f:
    content = f.read()

new_build = """  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: AppTheme.premiumCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.dMaroon.withAlpha(20),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.folder_outlined,
                color: AppTheme.dMaroon,
                size: 26,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    category.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.dInk,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    category.hasTargetAmount
                        ? 'الهدف المخطط: ${category.targetAmount} YER'
                        : 'بدون مبلغ مستهدف محدد',
                    style: TextStyle(
                      color: category.hasTargetAmount ? AppTheme.dInkSoft : AppTheme.dMuted,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }"""

content = re.sub(r"  @override\n  Widget build\(BuildContext context\) \{.*?\n  \}", new_build, content, flags=re.DOTALL)

with open(budget_path, 'w', encoding='utf-8') as f:
    f.write(content)
print("Budget card upgraded!")

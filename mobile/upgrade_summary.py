import re

summary_path = r"d:\projects\aarast\mobile\lib\features\tasks\widgets\timeline_summary_card.dart"
with open(summary_path, 'r', encoding='utf-8') as f:
    content = f.read()

new_build = """  @override
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
                const Icon(Icons.timeline, color: AppTheme.dGold, size: 24),
                const SizedBox(width: 8),
                Text(
                  'ملخص الجدول الزمني',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.right,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _SummaryLine(
              label: 'تاريخ الزفاف',
              value: timeline.weddingDate == null
                  ? 'غير محدد'
                  : _formatDate(timeline.weddingDate!),
              icon: Icons.calendar_today_outlined,
            ),
            _SummaryLine(
              label: 'المهام القادمة',
              value: timeline.upcomingTasks.length.toString(),
              icon: Icons.checklist,
            ),
            _SummaryLine(
              label: 'الديون القريبة',
              value: timeline.dueDebts.length.toString(),
              icon: Icons.money_off,
            ),
            _SummaryLine(
              label: 'الأقساط القريبة',
              value: timeline.dueInstallments.length.toString(),
              icon: Icons.payment,
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(30),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ),
          const Spacer(),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
            textAlign: TextAlign.right,
          ),
          const SizedBox(width: 8),
          Icon(icon, color: AppTheme.dGold2, size: 18),
        ],
      ),
    );
  }"""

content = re.sub(r"  @override\n  Widget build\(BuildContext context\) \{.*?\n  \}", new_build, content, flags=re.DOTALL)

with open(summary_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Summary card upgraded!")

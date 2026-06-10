import re

filepath = r"d:\projects\aarast\mobile\lib\features\wedding_plans\widgets\new_dashboard_widgets.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add border to _MiniMetricCard
old_mini_metric = """    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: DashboardUiColors.card,
        borderRadius: BorderRadius.circular(20),
      ),"""
new_mini_metric = """    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: DashboardUiColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),"""
content = content.replace(old_mini_metric, new_mini_metric)

# 2. Fix NewDashboardQuickActions (remove outer white card)
old_quick_actions = """  Widget build(BuildContext context) {
    final planId = provider.plan?.id ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: DashboardUiColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column("""
new_quick_actions = """  Widget build(BuildContext context) {
    final planId = provider.plan?.id ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      child: Column("""
content = content.replace(old_quick_actions, new_quick_actions)

# 3. Fix NewDashboardAlertsMembersGrid (Separate title from the white card)
# I need to use regex to replace the whole build method of NewDashboardAlertsMembersGrid
pattern_alerts = r"class NewDashboardAlertsMembersGrid extends StatelessWidget \{.*?Widget build\(BuildContext context\) \{.*?return Container\(.*?\}\n\s*\}\n"
new_alerts = """class NewDashboardAlertsMembersGrid extends StatelessWidget {
  const NewDashboardAlertsMembersGrid({required this.provider, super.key});
  final DashboardSummaryProvider provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.bookmark_outline_rounded,
                    color: DashboardUiColors.maroon,
                    size: 22,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'ملاحظات مهمة',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: DashboardUiColors.ink,
                    ),
                  ),
                ],
              ),
              const Text(
                'عرض الكل',
                style: TextStyle(
                  color: DashboardUiColors.maroon,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DashboardUiColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                const _NoteItem(
                  title: 'تجربة فستان الزفاف',
                  subtitle: 'الأحد، 15 يونيو 2026 - 4:00 مساءً',
                  icon: Icons.calendar_today_outlined,
                  isImportant: false,
                ),
                Divider(color: Colors.grey.shade100, height: 24),
                const _NoteItem(
                  title: 'تأكيد الحجز في قاعة سمو',
                  subtitle: 'قبل 30 يونيو 2026',
                  icon: Icons.circle,
                  iconColor: DashboardUiColors.gold,
                  iconSize: 12,
                  isImportant: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
"""
content = re.sub(pattern_alerts, new_alerts, content, flags=re.DOTALL)

# 4. Fix NewDashboardSharedPlansCard
pattern_shared = r"class NewDashboardSharedPlansCard extends StatelessWidget \{.*?Widget build\(BuildContext context\) \{.*?return Container\(.*?\}\n\s*\}\n"
new_shared = """class NewDashboardSharedPlansCard extends StatelessWidget {
  const NewDashboardSharedPlansCard({required this.provider, super.key});
  final DashboardSummaryProvider provider;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.groups_outlined, color: DashboardUiColors.maroon, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'الخطط المشتركة',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: DashboardUiColors.ink,
                    ),
                  ),
                ],
              ),
              const Text(
                'عرض الكل',
                style: TextStyle(
                  color: DashboardUiColors.maroon,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DashboardUiColors.card,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                // Right side: The > icon
                const Icon(Icons.chevron_left, color: DashboardUiColors.muted, size: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'خطة عائلتنا',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: DashboardUiColors.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'آخر تحديث: اليوم، 9:20 ص',
                        style: TextStyle(
                          fontSize: 12,
                          color: DashboardUiColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Left side: Avatar stack
                SizedBox(
                  width: 100,
                  height: 36,
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.grey.shade200,
                          child: const Text('+2', style: TextStyle(fontSize: 12, color: Colors.black87)),
                        ),
                      ),
                      const Positioned(
                        left: 24,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundImage: NetworkImage('https://i.pravatar.cc/100?img=3'),
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 48,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundImage: NetworkImage('https://i.pravatar.cc/100?img=4'),
                          ),
                        ),
                      ),
                      const Positioned(
                        left: 72,
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundImage: NetworkImage('https://i.pravatar.cc/100?img=5'),
                          ),
                        ),
                      ),
                    ],
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
"""
content = re.sub(pattern_shared, new_shared, content, flags=re.DOTALL)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Card styles fixed!")

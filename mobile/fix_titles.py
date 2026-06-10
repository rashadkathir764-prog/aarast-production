import re

filepath = r"d:\projects\aarast\mobile\lib\features\wedding_plans\widgets\new_dashboard_widgets.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. NewDashboardQuickActions
quick_actions_old = """          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'إجراءات سريعة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: DashboardUiColors.ink,
                ),
              ),
              Icon(Icons.bolt, color: DashboardUiColors.gold, size: 22),
            ],
          ),"""
quick_actions_new = """          Row(
            children: [
              Icon(Icons.bolt, color: DashboardUiColors.gold, size: 22),
              const SizedBox(width: 8),
              const Text(
                'إجراءات سريعة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: DashboardUiColors.ink,
                ),
              ),
            ],
          ),"""
content = content.replace(quick_actions_old, quick_actions_new)

# 2. NewDashboardAlertsMembersGrid
alerts_old = """          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'ملاحظات مهمة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: DashboardUiColors.ink,
                ),
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
          ),"""
alerts_new = """          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.bookmark_outline_rounded, color: DashboardUiColors.maroon, size: 22),
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
          ),"""
content = content.replace(alerts_old, alerts_new)

# 3. NewDashboardSharedPlansCard
shared_old = """          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'الخطط المشتركة',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: DashboardUiColors.ink,
                ),
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
          ),"""
shared_new = """          Row(
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
          ),"""
content = content.replace(shared_old, shared_new)

# 4. NewDashboardMetricsBudgetSection ("نظرة سريعة")
metrics_old_1 = """                    const Text('نظرة سريعة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.dMaroonDeep)),"""
metrics_new_1 = """                    Row(
                      children: [
                        const Icon(Icons.remove_red_eye_outlined, color: AppTheme.dMaroonDeep, size: 20),
                        const SizedBox(width: 8),
                        const Text('نظرة سريعة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.dMaroonDeep)),
                      ],
                    ),"""
content = content.replace(metrics_old_1, metrics_new_1)

# 4b. NewDashboardMetricsBudgetSection ("ملخص الميزانية")
metrics_old_2 = """                    const Text('ملخص الميزانية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.dMaroonDeep)),"""
metrics_new_2 = """                    Row(
                      children: [
                        const Icon(Icons.account_balance_wallet_outlined, color: AppTheme.dMaroonDeep, size: 20),
                        const SizedBox(width: 8),
                        const Text('ملخص الميزانية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.dMaroonDeep)),
                      ],
                    ),"""
content = content.replace(metrics_old_2, metrics_new_2)

# Also let's fix the icons in NewDashboardMetricsBudgetSection if I made them spaceBetween
# wait I replaced them earlier with just Text. Now they have Row with Icon + Text. That's correct.

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Titles fixed!")

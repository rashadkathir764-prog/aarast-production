import re
import os

filepath = r"d:\projects\aarast\mobile\lib\features\wedding_plans\widgets\new_dashboard_widgets.dart"

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Replace NewDashboardTopHeader to _IconButton (inclusive)
new_header = '''class NewDashboardTopHeader extends StatelessWidget {
  const NewDashboardTopHeader({
    required this.userName,
    this.onProfile,
    this.onNotifications,
    this.hasNotificationDot = true,
    super.key,
  });

  final String userName;
  final VoidCallback? onProfile;
  final VoidCallback? onNotifications;
  final bool hasNotificationDot;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Action icons
          Row(
            children: [
              _IconButton(
                icon: Icons.notifications_none_rounded,
                onTap: onNotifications,
                showDot: hasNotificationDot,
                badgeCount: '3',
              ),
              const SizedBox(width: 10),
              _IconButton(icon: Icons.person_outline_rounded, onTap: onProfile),
            ],
          ),
          // Greeting and Logo
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const _BrandMark(),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Text(
                        '🤎',
                        style: TextStyle(fontSize: 12),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'مساء الخير، ${userName.split(' ').first}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.dInkSoft,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    final isTest = !kIsWeb && Platform.environment.containsKey('FLUTTER_TEST');
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 4.0),
          child: Icon(Icons.favorite, color: AppTheme.dMaroon, size: 10),
        ),
        const SizedBox(width: 2),
        Text(
          'أعرست',
          style: isTest
              ? const TextStyle(
                  fontFamily: 'Amiri',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.dMaroon,
                  height: 1,
                )
              : GoogleFonts.amiri(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.dMaroon,
                  height: 1,
                ),
        ),
      ],
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, this.onTap, this.showDot = false, this.badgeCount});

  final IconData icon;
  final VoidCallback? onTap;
  final bool showDot;
  final String? badgeCount;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppTheme.dCard,
          shape: BoxShape.circle,
          border: Border.all(color: DashboardUiColors.maroon.withOpacity(0.1)),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 24, color: DashboardUiColors.gold),
            if (showDot || badgeCount != null)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.dMaroon,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.dCard, width: 1.5),
                  ),
                  child: badgeCount != null 
                    ? Text(badgeCount!, style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold, height: 1))
                    : const SizedBox(width: 4, height: 4),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
'''

content = re.sub(
    r'class NewDashboardTopHeader extends StatelessWidget \{.*?class _IconButton extends StatelessWidget \{.*?\n\}\n',
    new_header,
    content,
    flags=re.DOTALL
)

# 2. Replace NewDashboardHeroCard
new_hero = '''class NewDashboardHeroCard extends StatelessWidget {
  const NewDashboardHeroCard({required this.provider, super.key});
  final DashboardSummaryProvider provider;

  @override
  Widget build(BuildContext context) {
    final plan = provider.plan;
    if (plan == null) return const SizedBox();

    final allTasks = provider.tasks ?? [];
    final totalTasks = allTasks.length;
    final doneTasks = allTasks.where((t) => t.isDone).length;
    final progress = totalTasks > 0 ? doneTasks / totalTasks : 0.0;
    final percent = (progress * 100).round();

    final dateStr = plan.weddingDate != null ? formatArDate(plan.weddingDate!) : 'غير محدد';
    String countdown = 'غير محدد';
    if (plan.weddingDate != null) {
      final diff = plan.weddingDate!.difference(DateTime.now());
      if (diff.isNegative) {
        countdown = 'تم الزفاف';
      } else {
        countdown = 'تبقى ${diff.inDays} يوم';
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [DashboardUiColors.maroonBright, DashboardUiColors.maroon],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: DashboardUiColors.maroon.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.favorite_border, color: DashboardUiColors.gold, size: 20),
                        const SizedBox(width: 8),
                        const Text(
                          'خطة عرسي',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dateStr,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'أنت في الطريق الصحيح!',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$doneTasks من $totalTasks مهمة مكتملة',
                      style: const TextStyle(fontSize: 13, color: Colors.white70),
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(DashboardUiColors.gold),
                        minHeight: 6,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Column(
                children: [
                  SizedBox(
                    width: 90,
                    height: 90,
                    child: CustomPaint(
                      painter: _ProgressDonutPainter(progress: progress),
                      child: Center(
                        child: Text(
                          '$percent%',
                          style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('مكتمل', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.chevron_left, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('استكمال المهام', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(countdown, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 8),
                  const Icon(Icons.calendar_today_outlined, color: DashboardUiColors.gold, size: 16),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
'''

content = re.sub(
    r'class NewDashboardHeroCard extends StatelessWidget \{.*?class _HeroMetaRow extends StatelessWidget \{',
    new_hero + '\n\nclass _HeroMetaRow extends StatelessWidget {',
    content,
    flags=re.DOTALL
)

# 3. Replace Metrics / Budget section
new_metrics = '''class NewDashboardMetricsBudgetSection extends StatelessWidget {
  const NewDashboardMetricsBudgetSection({required this.provider, super.key});
  final DashboardSummaryProvider provider;

  double _parseAmt(String? val) => double.tryParse(val?.replaceAll(',', '') ?? '0') ?? 0;

  @override
  Widget build(BuildContext context) {
    final plan = provider.plan;
    if (plan == null) return const SizedBox();

    final allTasks = provider.tasks ?? [];
    final pendingTasks = allTasks.where((t) => !t.isDone).length;
    final dueInstallments = provider.dueInstallments?.length ?? 0;
    final debtsTotal = _parseAmt(provider.debtSummary?.totalDebt);

    final budgetTotal = _parseAmt(plan.estimatedBudget);
    final spent = _parseAmt(provider.expenseSummary?.totalPaid);
    final obligations = _parseAmt(provider.debtSummary?.remainingDebt);
    final remaining = math.max(0.0, budgetTotal - spent); // In the design it's total - spent = remaining

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left Column: Budget Summary
        Expanded(
          flex: 10,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DashboardUiColors.card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('ملخص الميزانية', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: DashboardUiColors.ink)),
                    Icon(Icons.account_balance_wallet_outlined, color: DashboardUiColors.maroon, size: 18),
                  ],
                ),
                const SizedBox(height: 20),
                Center(
                  child: SizedBox(
                    width: 100,
                    height: 100,
                    child: CustomPaint(
                      painter: _BudgetDonutPainter(
                        total: budgetTotal > 0 ? budgetTotal : 1,
                        spent: spent,
                        remaining: remaining,
                        obligations: 0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Center(child: Text('إجمالي الميزانية', style: TextStyle(fontSize: 11, color: DashboardUiColors.muted, fontWeight: FontWeight.w700))),
                Center(
                  child: Text(
                    '${formatNumber(budgetTotal)}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: DashboardUiColors.ink),
                    textDirection: TextDirection.ltr,
                  ),
                ),
                Center(child: Text('ر.ي', style: const TextStyle(fontSize: 11, color: DashboardUiColors.muted))),
                const SizedBox(height: 20),
                _BudgetLineItem(label: 'المصروف', amount: spent, currency: plan.currency, color: DashboardUiColors.maroon),
                const SizedBox(height: 8),
                _BudgetLineItem(label: 'المتبقي', amount: remaining, currency: plan.currency, color: DashboardUiColors.gold),
                const SizedBox(height: 20),
                const Row(
                  children: [
                    Icon(Icons.chevron_left, color: DashboardUiColors.maroon, size: 16),
                    SizedBox(width: 4),
                    Text('عرض التفاصيل', style: TextStyle(color: DashboardUiColors.maroon, fontSize: 12, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        // Right Column: Quick Overview
        Expanded(
          flex: 11,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DashboardUiColors.card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('نظرة سريعة', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: DashboardUiColors.ink)),
                    Icon(Icons.remove_red_eye_outlined, color: DashboardUiColors.maroon, size: 18),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _MiniMetricCard(
                        icon: Icons.people_outline,
                        iconColor: DashboardUiColors.success,
                        iconBg: DashboardUiColors.successSoft,
                        title: 'الموردين',
                        value: '12',
                        unit: '',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniMetricCard(
                        icon: Icons.checklist,
                        iconColor: DashboardUiColors.maroon,
                        iconBg: DashboardUiColors.dangerSoft,
                        title: 'المهام',
                        value: '16/26',
                        unit: '',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _MiniMetricCard(
                        icon: Icons.groups_outlined,
                        iconColor: Colors.orange,
                        iconBg: Colors.orange.shade50,
                        title: 'الضيوف',
                        value: '246',
                        unit: '',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniMetricCard(
                        icon: Icons.payment_outlined,
                        iconColor: Colors.purple,
                        iconBg: Colors.purple.shade50,
                        title: 'المدفوعات',
                        value: '8',
                        unit: '',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
'''

content = re.sub(
    r'class NewDashboardMetricsBudgetSection extends StatelessWidget \{.*?class _BudgetDonutPainter extends CustomPainter \{',
    new_metrics + '\n\nclass _BudgetDonutPainter extends CustomPainter {',
    content,
    flags=re.DOTALL
)

# 4. Quick Actions
new_quick_actions = '''class NewDashboardQuickActions extends StatelessWidget {
  const NewDashboardQuickActions({required this.provider, super.key});
  final DashboardSummaryProvider provider;

  @override
  Widget build(BuildContext context) {
    final planId = provider.plan?.id ?? '';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(color: DashboardUiColors.card, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('إجراءات سريعة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: DashboardUiColors.ink)),
              Icon(Icons.bolt, color: DashboardUiColors.gold, size: 22),
            ],
          ),
          const SizedBox(height: 20),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickActionBtn(
                  icon: Icons.add,
                  label: 'نفقات سريعة',
                  onTap: () => context.push(AppRouter.finance(planId)),
                ),
                _QuickActionBtn(
                  icon: Icons.people_outline,
                  label: 'قائمة الضيوف',
                  onTap: () {},
                ),
                _QuickActionBtn(
                  icon: Icons.calendar_month_outlined,
                  label: 'جدول الزواج',
                  onTap: () {},
                ),
                _QuickActionBtn(
                  icon: Icons.storefront_outlined,
                  label: 'الموردين',
                  onTap: () {},
                ),
                _QuickActionBtn(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'الميزانية',
                  onTap: () => context.push(AppRouter.finance(planId)),
                ),
                _QuickActionBtn(
                  icon: Icons.checklist,
                  label: 'قائمة المهام',
                  onTap: () => context.push(AppRouter.tasks(planId)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionBtn extends StatelessWidget {
  const _QuickActionBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: DashboardUiColors.maroon, width: 1.5),
              ),
              child: Icon(icon, color: DashboardUiColors.maroon, size: 24),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: DashboardUiColors.ink), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
'''

content = re.sub(
    r'class NewDashboardQuickActions extends StatelessWidget \{.*?class NewDashboardAlertsMembersGrid extends StatelessWidget \{',
    new_quick_actions + '\n\nclass NewDashboardAlertsMembersGrid extends StatelessWidget {',
    content,
    flags=re.DOTALL
)

# 5. Alerts -> Important Notes & Shared Plans
new_notes = '''class NewDashboardAlertsMembersGrid extends StatelessWidget {
  const NewDashboardAlertsMembersGrid({required this.provider, super.key});
  final DashboardSummaryProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: DashboardUiColors.card, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('ملاحظات مهمة', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: DashboardUiColors.ink)),
              const Text('عرض الكل', style: TextStyle(color: DashboardUiColors.maroon, fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          _NoteItem(
            title: 'تجربة فستان الزفاف',
            subtitle: 'الأحد، 15 يونيو 2026 - 4:00 مساءً',
            icon: Icons.calendar_today_outlined,
            isImportant: false,
          ),
          const SizedBox(height: 12),
          _NoteItem(
            title: 'تأكيد الحجز في قاعة سمو',
            subtitle: 'قبل 30 يونيو 2026',
            icon: Icons.circle,
            iconColor: DashboardUiColors.gold,
            iconSize: 12,
            isImportant: true,
          ),
        ],
      ),
    );
  }
}

class _NoteItem extends StatelessWidget {
  const _NoteItem({required this.title, required this.subtitle, required this.icon, this.iconColor, this.iconSize, this.isImportant = false});
  final String title, subtitle;
  final IconData icon;
  final Color? iconColor;
  final double? iconSize;
  final bool isImportant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isImportant ? DashboardUiColors.ivory : DashboardUiColors.ivory,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Icon(Icons.chevron_left, color: DashboardUiColors.muted, size: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: DashboardUiColors.ink)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: DashboardUiColors.muted)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Icon(icon, color: iconColor ?? DashboardUiColors.maroon, size: iconSize ?? 24),
        ],
      ),
    );
  }
}

class NewDashboardSharedPlansCard extends StatelessWidget {
  const NewDashboardSharedPlansCard({required this.provider, super.key});
  final DashboardSummaryProvider provider;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: DashboardUiColors.card, borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الخطط المشتركة', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: DashboardUiColors.ink)),
              const Text('عرض الكل', style: TextStyle(color: DashboardUiColors.maroon, fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(Icons.chevron_left, color: DashboardUiColors.ink, size: 20),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: DashboardUiColors.ivory, shape: BoxShape.circle),
                      child: const Text('+2', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: DashboardUiColors.ink)),
                    ),
                    const SizedBox(width: 4),
                    const CircleAvatar(radius: 12, backgroundColor: Colors.grey),
                    const CircleAvatar(radius: 12, backgroundColor: Colors.blueGrey),
                    const CircleAvatar(radius: 12, backgroundColor: Colors.brown),
                  ],
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('خطة عائلتنا', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: DashboardUiColors.ink)),
                      const Text('آخر تحديث: اليوم، 9:20 ص', style: TextStyle(fontSize: 11, color: DashboardUiColors.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: DashboardUiColors.maroon, borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.group, color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
'''

content = re.sub(
    r'class NewDashboardAlertsMembersGrid extends StatelessWidget \{.*?Future<void> showAccountSheet',
    new_notes + '\n\nFuture<void> showAccountSheet',
    content,
    flags=re.DOTALL
)

# 6. Bottom Nav Bar
new_nav = '''class NewDashboardBottomNav extends StatelessWidget {
  const NewDashboardBottomNav({
    this.onMore,
    this.onTasks,
    this.onAdd,
    this.onVendors,
    this.onHome,
    this.activeIndex = 4,
    super.key,
  });

  final VoidCallback? onMore;
  final VoidCallback? onTasks;
  final VoidCallback? onAdd;
  final VoidCallback? onVendors;
  final VoidCallback? onHome;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: DashboardUiColors.card,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
        boxShadow: [
          BoxShadow(
            color: DashboardUiColors.maroon.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 80,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _NavItem(icon: Icons.home_filled, label: 'الرئيسية', active: activeIndex == 4, onTap: onHome),
                    _NavItem(icon: Icons.checklist, label: 'المهام', active: activeIndex == 1, onTap: onTasks),
                    const SizedBox(width: 60), // Space for FAB
                    _NavItem(icon: Icons.storefront_outlined, label: 'الموردين', active: activeIndex == 3, onTap: onVendors),
                    _NavItem(icon: Icons.grid_view_rounded, label: 'المزيد', active: activeIndex == 0, onTap: onMore),
                  ],
                ),
              ),
              Positioned(
                top: -24,
                child: GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: DashboardUiColors.maroon,
                      boxShadow: [
                        BoxShadow(
                          color: DashboardUiColors.maroon.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.add_rounded, size: 32, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
'''

content = re.sub(
    r'class NewDashboardBottomNav extends StatelessWidget \{.*?class _NavItem extends StatelessWidget \{',
    new_nav + '\nclass _NavItem extends StatelessWidget {',
    content,
    flags=re.DOTALL
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated successfully")

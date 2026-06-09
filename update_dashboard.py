from pathlib import Path

file_path = Path('mobile/lib/features/wedding_plans/screens/wedding_plan_dashboard_screen.dart')
content = file_path.read_text(encoding='utf-8')

if 'new_dashboard_widgets.dart' not in content:
    content = content.replace(
        "import '../widgets/aarast_dashboard_widgets.dart';",
        "import '../widgets/aarast_dashboard_widgets.dart';\nimport '../widgets/new_dashboard_widgets.dart';"
    )

start_idx = content.find('  Widget _buildContent(')
end_idx = content.find('  Widget _scaledDashboardCanvas(')

new_method = '''  Widget _buildContent(
    BuildContext context,
    DashboardSummaryProvider provider,
    AuthController auth,
  ) {
    if (provider.isLoading && provider.plan == null) {
      return const DashboardSkeleton(key: ValueKey('skeleton'));
    }

    if (provider.errorMessage != null && provider.plan == null) {
      return ListView(
        key: const ValueKey('error'),
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 120),
          Text(
            provider.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.danger),
          ),
          const SizedBox(height: 16),
          Center(
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppTheme.dMaroon),
              onPressed: () => provider.loadDashboard(widget.weddingPlanId),
              child: const Text('إعادة المحاولة'),
            ),
          ),
        ],
      );
    }

    final plan = provider.plan;
    if (plan == null) {
      return ListView(
        key: const ValueKey('empty'),
        children: const [
          SizedBox(height: 120),
          Text('لم يتم العثور على خطة الزفاف.', textAlign: TextAlign.center),
        ],
      );
    }

    return _scaledDashboardCanvas(
      key: const ValueKey('content'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DashboardTopBar(
            userName: auth.user?.name ?? 'ضيف',
            onProfile: () => _openAccountSheet(auth),
            onNotifications: () => _comingSoon('مركز التنبيهات قيد الإعداد'),
          ),
          _padded(NewDashboardHeroCard(provider: provider)),
          const SizedBox(height: 18),
          _padded(NewDashboardMetricsBudgetSection(provider: provider)),
          const SizedBox(height: 18),
          _padded(NewDashboardQuickActions(provider: provider)),
          const SizedBox(height: 18),
          _padded(NewDashboardAlertsMembersGrid(provider: provider)),
          const SizedBox(height: 18),
          _padded(NewDashboardSharedPlansCard(provider: provider)),
          const SizedBox(height: 28),
        ],
      ),
    );
  }

'''

content = content[:start_idx] + new_method + content[end_idx:]
file_path.write_text(content, encoding='utf-8')

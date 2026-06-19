import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../data/dashboard_summary_sources.dart';

class LocalGuestDashboardScreen extends StatelessWidget {
  const LocalGuestDashboardScreen({required this.summary, super.key});

  final LocalGuestDashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    final seed = summary.seed;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppTheme.dBg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: AppTheme.heroDecoration(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      seed.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      summary.daysRemaining == null
                          ? seed.weddingDateLabel
                          : 'متبقي ${summary.daysRemaining} يوم',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: AppTheme.premiumCardDecoration(),
                child: const Row(
                  children: [
                    Icon(
                      Icons.phone_android_rounded,
                      color: AppTheme.dGoldDeep,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'خطة محفوظة على جهازك — سجّل الدخول للمزامنة والمشاركة',
                        style: TextStyle(
                          color: AppTheme.dInk,
                          fontWeight: FontWeight.w800,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'الميزانية',
                      value: seed.estimatedBudgetLabel,
                      icon: Icons.account_balance_wallet_rounded,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _SummaryCard(
                      label: 'التقدم',
                      value: '${summary.progressPercent}%',
                      icon: Icons.donut_large_rounded,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _CountCard(
                      label: 'المهام',
                      value: summary.taskCount,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CountCard(
                      label: 'الضيوف',
                      value: summary.guestCount,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _CountCard(
                      label: 'الموردون',
                      value: summary.providerCount,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _InfoCard(
                title: 'الفئات المختارة',
                value: seed.selectedCategories.join('، '),
              ),
              const SizedBox(height: 10),
              _InfoCard(title: 'خطوتك التالية', value: seed.nextBestAction),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('guest-dashboard-protected-action'),
                onPressed: () => AuthActionGuard.requireAccount(
                  context,
                  reason:
                      'المزامنة والمشاركة تحتاجان حساباً لحفظ الصلاحيات والبيانات بأمان.',
                ),
                icon: const Icon(Icons.cloud_sync_rounded),
                label: const Text('زامن خطتك أو شاركها'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.premiumCardDecoration(),
      child: Column(
        children: [
          Icon(icon, color: AppTheme.dMaroon),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: AppTheme.dInkSoft)),
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.dInk,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: AppTheme.premiumCardDecoration(),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: AppTheme.dMaroon,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(label, style: const TextStyle(color: AppTheme.dInkSoft)),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.premiumCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.dMaroon,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value.isEmpty ? 'لا توجد بيانات بعد' : value,
            style: const TextStyle(
              color: AppTheme.dInk,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

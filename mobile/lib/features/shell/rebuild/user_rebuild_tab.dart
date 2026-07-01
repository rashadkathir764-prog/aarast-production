import 'package:flutter/material.dart';

enum UserRebuildTab {
  home(
    label: 'الرئيسية',
    icon: Icons.home_outlined,
    semanticPurpose: 'today_center_for_current_wedding_plan',
    requiresCurrentPlan: false,
  ),
  money(
    label: 'المال',
    icon: Icons.account_balance_wallet_outlined,
    semanticPurpose: 'financial_planning_budget_expenses_debts_installments',
    requiresCurrentPlan: true,
  ),
  tasks(
    label: 'المهام',
    icon: Icons.check_circle_outline,
    semanticPurpose: 'tasks_timeline_and_due_items',
    requiresCurrentPlan: true,
  ),
  providers(
    label: 'الموردون',
    icon: Icons.storefront_outlined,
    semanticPurpose: 'provider_planning_references_and_quote_context',
    requiresCurrentPlan: true,
  ),
  more(
    label: 'المزيد',
    icon: Icons.more_horiz,
    semanticPurpose: 'secondary_plan_account_settings_and_support_surfaces',
    requiresCurrentPlan: false,
  );

  const UserRebuildTab({
    required this.label,
    required this.icon,
    required this.semanticPurpose,
    required this.requiresCurrentPlan,
  });

  final String label;
  final IconData icon;
  final String semanticPurpose;
  final bool requiresCurrentPlan;
}

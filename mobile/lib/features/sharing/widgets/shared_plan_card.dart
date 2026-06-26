import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/shared_member.dart';
import '../models/shared_wedding_plan.dart';
import 'permission_chip.dart';

class SharedPlanCard extends StatelessWidget {
  const SharedPlanCard({required this.plan, required this.onTap, super.key});

  final SharedWeddingPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labels = plan.sharedMember.permissionLabels;

    return AarastCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PermissionChip(
                label: sharedMemberRoleLabel(plan.sharedMember.role),
                enabled: true,
              ),
              const Spacer(),
              Expanded(
                flex: 3,
                child: Text(
                  plan.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.deepBurgundy,
                    fontWeight: FontWeight.w800,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (plan.city != null) _InfoLine(label: 'المدينة', value: plan.city!),
          if (plan.weddingDate != null)
            _InfoLine(
              label: 'تاريخ الزفاف',
              value: _formatDate(plan.weddingDate!),
            ),
          _InfoLine(
            label: 'الحالة',
            value: plan.status == 'ARCHIVED' ? 'مؤرشفة' : 'قيد التخطيط',
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: labels.isEmpty
                ? const [PermissionChip(label: 'عرض أساسي فقط', enabled: false)]
                : [
                    for (final label in labels)
                      PermissionChip(label: label, enabled: true),
                  ],
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        '$label: $value',
        textAlign: TextAlign.right,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }
}

String _formatDate(DateTime date) {
  return formatArabicCompactDate(date);
}

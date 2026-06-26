import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/shared_member.dart';
import 'permission_chip.dart';

class SharedMemberCard extends StatelessWidget {
  const SharedMemberCard({
    required this.member,
    required this.onTap,
    super.key,
  });

  final SharedMember member;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final permissionLabels = member.permissionLabels;
    final subtitle = member.displaySubtitle;

    return AarastCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              PermissionChip(
                label: sharedMemberRoleLabel(member.role),
                enabled: true,
              ),
              const Spacer(),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      member.displayName,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.deepBurgundy,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'الصلاحيات المالية خاصة ولا تظهر إلا عند تفعيلها.',
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: permissionLabels.isEmpty
                ? const [
                    PermissionChip(
                      label: 'لا توجد صلاحيات إضافية',
                      enabled: false,
                    ),
                  ]
                : [
                    for (final label in permissionLabels)
                      PermissionChip(label: label, enabled: true),
                  ],
          ),
        ],
      ),
    );
  }
}

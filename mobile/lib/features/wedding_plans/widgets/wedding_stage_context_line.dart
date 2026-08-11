import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../models/wedding_plan_stage.dart';
import '../models/wedding_stage_domain_guidance.dart';

class WeddingStageContextLine extends StatelessWidget {
  const WeddingStageContextLine({
    required this.stage,
    required this.domain,
    super.key,
  });

  final WeddingPlanStageState stage;
  final WeddingStageDomain domain;

  @override
  Widget build(BuildContext context) {
    final guidance = resolveWeddingStageDomainGuidance(stage, domain);
    return Semantics(
      container: true,
      label: '${stage.compactLabel}. ${guidance.label}. ${guidance.message}',
      child: Container(
        key: ValueKey('stage-context-${domain.name}'),
        padding: const EdgeInsets.symmetric(vertical: AarastV3Space.x3),
        decoration: const BoxDecoration(
          border: Border.symmetric(
            horizontal: BorderSide(color: AarastV3Color.line),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon, size: 18, color: AarastV3Color.primary),
            const SizedBox(width: AarastV3Space.x3),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '${stage.compactLabel} · ${guidance.label}\n',
                      style: AarastV3Type.label(
                        context,
                      ).copyWith(color: AarastV3Color.primary),
                    ),
                    TextSpan(
                      text: guidance.message,
                      style: AarastV3Type.body(context),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData get _icon => switch (domain) {
    WeddingStageDomain.tasks => LucideIcons.listChecks,
    WeddingStageDomain.guests => LucideIcons.users,
    WeddingStageDomain.money => LucideIcons.walletCards,
    WeddingStageDomain.providers => LucideIcons.store,
  };
}

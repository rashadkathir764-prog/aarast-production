import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContext, AccountContextController, AccountContextRole;

/// q19 «لما الخطة تتغير», the one state the server tells a participant
/// today: the owner put the plan in the memories (lifecycle ARCHIVED, read
/// only). Paused, postponed and deleted wait for the plan states.
class ParticipantPlanStateScreen extends StatelessWidget {
  const ParticipantPlanStateScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AccountContextController>();
    AccountContext? path;
    for (final item in controller.contexts) {
      if (item.role == AccountContextRole.contributor &&
          item.weddingPlanId == weddingPlanId) {
        path = item;
        break;
      }
    }
    final archived = path != null && path.lifecycle == 'ARCHIVED';
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          JourneySubHeader(
            title: path?.displayName ?? 'الخطة',
            subtitle: 'لما الخطة تتغير',
            onBack: () => context.popOrGo(AppRouter.more),
          ),
          if (archived)
            const _StateCard(
              key: ValueKey('participant-plan-archived'),
              icon: LucideIcons.archive,
              title: 'الخطة في الذكريات',
              message: 'العرس تم الحمد لله، وصاحب الخطة حفظها في الذكريات.',
            )
          else
            const JourneyListState(
              key: ValueKey('participant-plan-state-missing'),
              phase: JourneyListPhase.empty,
              section: JourneySection.home,
              emptyIcon: LucideIcons.layers,
              emptyTitle: 'ما فيه تغيير على هذي الخطة',
              emptyMessage: 'افتحها من «حسابي».',
            ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JourneyIconTile(
            icon: icon,
            color: AarastV3Color.textMuted,
            soft: AarastV3Color.line,
            size: 46,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: JourneyType.of(
                    JourneyType.bodyLarge,
                    weight: JourneyType.bold,
                  ),
                ),
                Text(
                  message,
                  style: JourneyType.of(
                    JourneyType.detail,
                    color: AarastV3Color.textMuted,
                    height: 1.45,
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

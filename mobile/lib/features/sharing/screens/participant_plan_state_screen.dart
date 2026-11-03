import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show
        AccountContext,
        AccountContextController,
        AccountContextPersona,
        AccountContextRole;

/// q19 «لما الخطة تتغير»: what the server tells a participant about a plan
/// they help in. The owner put it in the memories (lifecycle ARCHIVED, read
/// only), or took the participant off it (J2-07, the `SHARING_REMOVED`
/// notice): the membership is gone from the account's paths. The page asks
/// the server again on opening, so a notice never shows a stale plan; the
/// path the phone still held names the plan and its owner. Paused,
/// postponed and deleted wait for the plan states.
class ParticipantPlanStateScreen extends StatefulWidget {
  const ParticipantPlanStateScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<ParticipantPlanStateScreen> createState() =>
      _ParticipantPlanStateScreenState();
}

class _ParticipantPlanStateScreenState
    extends State<ParticipantPlanStateScreen> {
  /// The plan's path as the phone held it when the page opened.
  AccountContext? _lastKnown;
  bool _refreshed = false;

  @override
  void initState() {
    super.initState();
    final controller = context.read<AccountContextController>();
    _lastKnown = _pathOf(controller);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await controller.refresh();
      if (mounted) setState(() => _refreshed = true);
    });
  }

  AccountContext? _pathOf(AccountContextController controller) {
    for (final item in controller.contexts) {
      if (item.role == AccountContextRole.contributor &&
          item.weddingPlanId == widget.weddingPlanId) {
        return item;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AccountContextController>();
    final path = _pathOf(controller);
    final known = path ?? _lastKnown;
    final archivedPath = path != null && path.lifecycle == 'ARCHIVED'
        ? path
        : null;
    final removed =
        path == null &&
        _refreshed &&
        controller.hasLoadedContexts &&
        controller.errorMessage == null;
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        padding: AarastV3Density.pageInsets,
        children: [
          JourneySubHeader(
            title: known?.displayName ?? 'الخطة',
            subtitle: 'لما الخطة تتغير',
            onBack: () => context.popOrGo(AppRouter.more),
          ),
          if (archivedPath != null)
            _StateCard(
              key: const ValueKey('participant-plan-archived'),
              icon: LucideIcons.archive,
              title: 'الخطة في الذكريات',
              // J2-20: the owner by the plan's word, and nothing assumed
              // about the wedding itself.
              message:
                  'الخطة في الذكريات: ${archivedPath.planOwnerWord} '
                  '${_ownerIsBride(archivedPath) ? 'حفظتها' : 'حفظها'} هناك.',
            )
          else if (removed)
            _StateCard(
              key: const ValueKey('participant-plan-removed'),
              icon: LucideIcons.userX,
              title: 'ما عاد لك مكان في الخطة',
              message: known == null
                  ? 'ما عاد لك مكان في هذي الخطة. اللي سجّلته قبل يبقى باسمك.'
                  : '${known.planOwnerWord} '
                        '${_ownerIsBride(known) ? 'شالتك' : 'شالك'} من '
                        '${known.displayName}. اللي سجّلته قبل يبقى باسمك.',
            )
          else if (!_refreshed)
            const JourneyListState(
              phase: JourneyListPhase.loading,
              section: JourneySection.home,
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

bool _ownerIsBride(AccountContext path) =>
    path.persona == AccountContextPersona.bride;

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
      padding: const EdgeInsets.all(AarastV3Space.x4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JourneyIconTile(
            icon: icon,
            color: AarastV3Color.textMuted,
            soft: AarastV3Color.line,
            size: 40,
          ),
          const SizedBox(width: AarastV3Space.x3),
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

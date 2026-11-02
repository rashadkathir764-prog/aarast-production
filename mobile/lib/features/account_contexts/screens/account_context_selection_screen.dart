import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/diagnostics/app_logger.dart';
import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/account_context.dart';
import '../providers/account_context_controller.dart';

/// q04 «اختر المسار»: one phone, more than one place to open: your own
/// plan, someone else's you help in, or the provider account. Choosing only
/// publishes the path; the entry gate opens it, with no second sign-in.
class AccountContextSelectionScreen extends StatefulWidget {
  const AccountContextSelectionScreen({super.key});

  @override
  State<AccountContextSelectionScreen> createState() =>
      _AccountContextSelectionScreenState();
}

class _AccountContextSelectionScreenState
    extends State<AccountContextSelectionScreen> {
  bool _shownEventRecorded = false;
  String? _choosing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shownEventRecorded) return;
    _shownEventRecorded = true;
    final controller = context.read<AccountContextController>();
    appLogEvent(
      'ROLE_CHOOSER_SHOWN',
      category: AppLogCategory.context,
      source: 'AccountContextSelectionScreen',
      reason: 'active_context_required',
      attributes: {
        'availableContextCount': controller.availableContexts.length,
      },
    );
  }

  Future<void> _choose(
    AccountContextController controller,
    AccountContext path,
  ) async {
    setState(() => _choosing = path.contextKey);
    await controller.select(path.contextKey);
    // Chosen, the entry gate opens the path; refused, the card is free again.
    if (mounted) setState(() => _choosing = null);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AccountContextController>();
    final paths = controller.availableContexts;

    return AarastScreenFrame(
      key: const ValueKey('account-context-selection-screen'),
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      child: ListView(
        padding: AarastV3Density.pageInsets,
        children: [
          const SizedBox(height: AarastV3Space.x3),
          const Center(child: JourneyWordmark(size: 26)),
          const SizedBox(height: AarastV3Space.x4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AarastV3Space.x1),
            child: Semantics(
              header: true,
              child: Text(
                'اختر المسار',
                style: JourneyType.of(
                  JourneyType.hero,
                  weight: JourneyType.bold,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AarastV3Space.x1),
            child: Text(
              'ايش تفتح الآن؟ ما نطلب منك دخول مرة ثانية.',
              style: JourneyType.of(
                JourneyType.body,
                color: AarastV3Color.textMuted,
              ),
            ),
          ),
          const SizedBox(height: AarastV3Space.x4),
          for (final path in paths) ...[
            _PathCard(
              path: path,
              chosen: _choosing == path.contextKey,
              onTap: controller.isSelecting
                  ? null
                  : () => _choose(controller, path),
            ),
            const SizedBox(height: AarastV3Space.x2),
          ],
          if (controller.errorMessage case final error?) ...[
            JourneyNote(
              text: error,
              color: AarastV3Color.danger,
              soft: AarastV3Color.dangerSoft,
            ),
            const SizedBox(height: AarastV3Space.x2),
            JourneyListState(
              phase: JourneyListPhase.error,
              section: JourneySection.home,
              onRetry: controller.refresh,
            ),
          ],
          const SizedBox(height: AarastV3Space.x1),
          Center(
            child: Text(
              context.say(
                'تقدر تبدّل بينهم من حسابي',
                'تقدرين تبدّلين بينهم من حسابي',
              ),
              style: JourneyType.of(
                JourneyType.small,
                color: AarastV3Color.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One path: a letter in the plan's colour, its name, what it is to you,
/// and a tag. Contexts carry no relation («أخوك») and no participant role,
/// so the line says what is known.
class _PathCard extends StatelessWidget {
  const _PathCard({
    required this.path,
    required this.chosen,
    required this.onTap,
  });

  final AccountContext path;
  final bool chosen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    // The plan's colour and whose wedding it is follow the plan; what it is
    // to you is said to you, as who you are (B5): محمد helping in سلمى's
    // plan reads «تساعد فيها».
    final bride = path.persona == AccountContextPersona.bride;
    final (Color color, String tag, String line) = switch (path.role) {
      AccountContextRole.owner => (
        AarastV3Color.brandAccentStrong,
        bride ? 'عروسة' : 'عريس',
        context.say('خطتك', 'خطتكِ'),
      ),
      AccountContextRole.contributor => (
        bride ? AarastV3Color.rose : AarastV3Color.primary,
        context.say('مشارك', 'مشاركة'),
        context.say('تساعد فيها', 'تساعدين فيها'),
      ),
      AccountContextRole.provider => (
        AarastV3Color.cobalt,
        'مزود',
        'حساب المزود',
      ),
    };
    final name = path.displayName.trim();
    final letterSource = name.startsWith('عرس ') ? name.substring(4) : name;
    final letter = letterSource.trim().isEmpty
        ? 'ع'
        : letterSource.trim().characters.first;
    return Semantics(
      button: true,
      selected: chosen,
      label: '$name، $line، $tag',
      onTap: onTap,
      excludeSemantics: true,
      child: AarastPressable(
        key: ValueKey('account-path-option-${path.contextKey}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(AarastV3Radius.card),
        child: Container(
          padding: const EdgeInsets.all(AarastV3Space.x4),
          decoration: BoxDecoration(
            color: AarastV3Color.paper,
            borderRadius: BorderRadius.circular(AarastV3Radius.card),
            border: Border.all(
              color: chosen ? AarastV3Color.primary : AarastV3Color.line,
              width: chosen ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              JourneyAvatar(letter: letter, color: color, size: 40),
              const SizedBox(width: AarastV3Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: JourneyType.of(
                        JourneyType.bodyLarge,
                        weight: JourneyType.bold,
                      ),
                    ),
                    Text(
                      line,
                      style: JourneyType.of(
                        JourneyType.small,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AarastV3Space.x2),
              if (chosen)
                AarastInlineSpinner(dimension: 20, color: color)
              else
                JourneyTag(
                  label: tag,
                  color: color,
                  soft: color.withValues(alpha: 0.12),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_pressable.dart';
import '../data/plan_assistant_api.dart';
import '../models/plan_assistant.dart';

/// The way into b11 «اسأل اعّرست» on the plan's home (V1 checklist 4.12),
/// a journey row. Shown only when the assistant is set up and the reader is
/// the plan's owner or partner; otherwise it takes no space.
class PlanAssistantEntry extends StatefulWidget {
  const PlanAssistantEntry({required this.weddingPlanId, this.api, super.key});

  final String weddingPlanId;
  final PlanAssistantApi? api;

  @override
  State<PlanAssistantEntry> createState() => _PlanAssistantEntryState();
}

class _PlanAssistantEntryState extends State<PlanAssistantEntry> {
  PlanAssistantStatus? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PlanAssistantEntry oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Another plan on the same home: its door depends on its own access.
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      setState(() => _status = null);
      _load();
    }
  }

  Future<void> _load() async {
    final weddingPlanId = widget.weddingPlanId;
    try {
      final api = widget.api ?? PlanAssistantApi(context.read<ApiClient>());
      final status = await api.status(weddingPlanId);
      if (mounted && weddingPlanId == widget.weddingPlanId) {
        setState(() => _status = status);
      }
    } catch (_) {
      // Offline or unavailable: the home simply shows no door.
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    if (status == null || !status.available) return const SizedBox.shrink();
    final label = context.say('اسأل اعّرست عن عرسك', 'اسألي اعّرست عن عرسك');
    void open() => context.push(AppRouter.planAssistant(widget.weddingPlanId));
    // The home's field under the greeting: it reads as a place to ask, in
    // one 48 line, and opens b11.
    return Padding(
      padding: const EdgeInsets.only(top: AarastV3Space.x3),
      child: Semantics(
        key: const ValueKey('assistant-entry'),
        button: true,
        label: '$label، يجاوبك من خطتك أنت، وما يخترع أسعار',
        onTap: open,
        excludeSemantics: true,
        child: AarastPressable(
          onTap: open,
          borderRadius: BorderRadius.circular(AarastV3Radius.surface),
          child: JourneyBox(
            radius: AarastV3Radius.surface,
            borderColor: AarastV3Color.line,
            borderWidth: AarastV3Space.hair,
            padding: const EdgeInsets.symmetric(horizontal: AarastV3Space.x4),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AarastV3Space.x12),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.sparkles,
                    size: AarastV3Icon.md,
                    color: context.accent.primary,
                  ),
                  const SizedBox(width: AarastV3Space.x2),
                  Expanded(
                    child: Text(
                      '$label…',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: JourneyType.of(
                        JourneyType.body,
                        color: AarastV3Color.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

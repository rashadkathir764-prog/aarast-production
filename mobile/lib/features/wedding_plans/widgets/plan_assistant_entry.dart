import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
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
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: JourneyBox(
        padding: EdgeInsets.zero,
        child: JourneyListRow(
          key: const ValueKey('assistant-entry'),
          icon: LucideIcons.sparkles,
          color: context.accent.primary,
          soft: context.accent.primarySoft,
          title: context.say('اسأل اعّرست', 'اسألي اعّرست'),
          subtitle: 'يجاوبك من خطتك أنت، وما يخترع أسعار',
          trailing: const Icon(
            LucideIcons.chevronLeft,
            size: 18,
            color: AarastV3Color.textFaint,
          ),
          onTap: () =>
              context.push(AppRouter.planAssistant(widget.weddingPlanId)),
        ),
      ),
    );
  }
}

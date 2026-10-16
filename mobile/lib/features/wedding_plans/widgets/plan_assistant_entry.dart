import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/network/api_client.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_pressable.dart';
import '../data/plan_assistant_api.dart';
import '../models/plan_assistant.dart';

/// The planning assistant's door on the plan's home (V1 checklist 4.12).
/// Shown only when the assistant is set up and the reader is the plan's
/// owner or partner; otherwise it takes no space.
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
      padding: const EdgeInsets.only(top: AppTheme.space10),
      child: AarastPressable(
        key: const ValueKey('assistant-entry'),
        onTap: () => context.push(AppRouter.planAssistant(widget.weddingPlanId)),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppTheme.surfaceRaised,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
          ),
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(LucideIcons.sparkles, color: AppTheme.brand),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'اسأل مساعد اعّرست',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'خطة عمل، توزيع الميزانية، مقارنة العروض، وما نسيته.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                Icon(LucideIcons.chevronLeft, color: AppTheme.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

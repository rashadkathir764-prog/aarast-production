import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/utils/app_clock.dart';
import '../data/wedding_moment_ledger.dart';
import '../models/wedding_plan_stage.dart';

/// y06 on entering the wedding week, y07 on the day: each once per phone for
/// this plan and date (D65), opened over the home that watches it. The
/// owner's home and the partner's (Q-18, RA-MO-356) watch the same way.
class WeddingMomentWatch {
  /// The plan, moment and wedding date last looked at.
  String? _signature;

  void watch(
    BuildContext context, {
    required String planId,
    required DateTime? weddingDate,
  }) {
    if (weddingDate == null) return;
    final stage = resolveWeddingPlanStage(weddingDate, now: appNow()).stage;
    final moment = switch (stage) {
      WeddingPlanStage.finalWeek => WeddingMoment.week,
      WeddingPlanStage.weddingDay => WeddingMoment.day,
      _ => null,
    };
    if (moment == null) return;
    final signature = '$planId:${moment.name}:$weddingDate';
    if (signature == _signature) return;
    _signature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final ledger = WeddingMomentLedger(await SharedPreferences.getInstance());
      final first = await ledger.firstTime(planId, moment, weddingDate);
      if (!first || !context.mounted) return;
      await context.push<void>(AppRouter.weddingMoment(planId, moment));
    });
  }
}

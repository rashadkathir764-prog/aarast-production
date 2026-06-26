import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/offline/offline_sync_service.dart';
import '../../../core/offline/sync_status.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/arabic_date_formatter.dart';

// ============================================================================
// Aarast Dashboard — faithful Flutter recreation of the Claude Design handoff
// (RTL, maroon/gold/cream palette, completion donut, budget donut, quick
// actions, alerts, participants, shared plans, custom bottom nav).
// ============================================================================

String dashFormatArDate(DateTime date) {
  return formatArabicDate(date);
}

double dashParseAmount(String? raw) {
  if (raw == null) return 0;
  return double.tryParse(raw.replaceAll(',', '').trim()) ?? 0;
}

String dashFormatMoney(num value) {
  final negative = value < 0;
  final digits = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }
  return '${negative ? '-' : ''}$buffer';
}

/// LTR-rendered numeric/currency text so digits + currency keep their order
/// inside the surrounding RTL layout (mirrors the `.num` rule in the design).
class _Num extends StatelessWidget {
  const _Num(this.text, {this.style, this.align = TextAlign.right});

  final String text;
  final TextStyle? style;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textDirection: TextDirection.ltr,
      textAlign: align,
      style: style,
    );
  }
}

const _uxBurgundy = Color(0xFF8A0032);
const _uxBurgundyDark = Color(0xFF4A001B);
const _uxInk = Color(0xFF162235);
const _uxGold = Color(0xFFC9A24D);
const _uxSoftGold = Color(0xFFE8D29A);
const _uxMuted = Color(0xFF6F7A89);
const _uxLine = Color(0xFFEFE4DA);
const _uxSoft = Color(0xFFFAF6EF);
const _uxSoft2 = Color(0xFFF6EEE4);
const _uxCard = Colors.white;
const _uxRadius = 16.0;

// ============================================================================
// NEUTRAL UX DASHBOARD SKELETON
// ============================================================================

class DashboardUxHeader extends StatelessWidget {
  const DashboardUxHeader({
    required this.userName,
    required this.onNotifications,
    required this.onProfile,
    super.key,
  });

  final String userName;
  final VoidCallback onNotifications;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'أعرست',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _uxBurgundyDark,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'مساء الخير',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _uxInk,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
                const Text(
                  'جاهزين نكمل خطة زفافك',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _uxMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _UxIconButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'الإشعارات',
            onTap: onNotifications,
          ),
          const SizedBox(width: 8),
          _UxIconButton(
            icon: Icons.person_outline_rounded,
            tooltip: 'الملف الشخصي',
            onTap: onProfile,
          ),
        ],
      ),
    );
  }
}

class DashboardUxOfflineBanner extends StatelessWidget {
  const DashboardUxOfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final service = _maybeOfflineService(context);
    if (service == null) return const SizedBox.shrink();

    final state = service.state;
    final shouldShow =
        state == SyncState.offline ||
        state == SyncState.syncing ||
        state == SyncState.syncError ||
        service.pendingCount > 0;
    if (!shouldShow) return const SizedBox.shrink();

    final label = switch (state) {
      SyncState.offline => 'بدون اتصال',
      SyncState.syncing => 'جاري المزامنة',
      SyncState.syncError => 'تعذر الاتصال',
      _ => 'بانتظار المزامنة',
    };
    final icon = state == SyncState.syncing
        ? Icons.sync_rounded
        : Icons.cloud_off_outlined;
    final pending = service.pendingCount > 0
        ? ' · ${service.pendingCount}'
        : '';

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: _uxSoftGold.withAlpha(60),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _uxSoftGold.withAlpha(170)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: _uxBurgundy),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                '$label$pending',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _uxInk,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardUxPlanCard extends StatelessWidget {
  const DashboardUxPlanCard({
    required this.title,
    required this.progressPercent,
    required this.tasksDone,
    required this.tasksTotal,
    required this.onContinue,
    this.city,
    this.weddingDate,
    this.daysRemaining,
    super.key,
  });

  final String title;
  final String? city;
  final DateTime? weddingDate;
  final int progressPercent;
  final int tasksDone;
  final int tasksTotal;
  final int? daysRemaining;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final dateLabel = weddingDate == null
        ? 'لم يحدد الموعد'
        : dashFormatArDate(weddingDate!);
    final daysLabel = daysRemaining == null
        ? 'غير محدد'
        : daysRemaining! < 0
        ? 'انتهى الموعد'
        : '$daysRemaining يوم';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_uxBurgundy, _uxBurgundyDark],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(_uxRadius),
        border: Border.all(color: _uxSoftGold.withAlpha(60)),
        boxShadow: [
          BoxShadow(
            color: _uxBurgundyDark.withAlpha(32),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _UxMetaChip(
                          icon: Icons.location_on_outlined,
                          label: city?.trim().isNotEmpty == true
                              ? city!.trim()
                              : 'المدينة غير محددة',
                        ),
                        _UxMetaChip(
                          icon: Icons.calendar_month_outlined,
                          label: dateLabel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _UxProgressBadge(percent: progressPercent),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _UxSmallMetric(
                  label: 'المهام المكتملة',
                  value: tasksTotal == 0 ? '0' : '$tasksDone/$tasksTotal',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _UxSmallMetric(label: 'المتبقي', value: daysLabel),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _uxBurgundy,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: onContinue,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text(
                'متابعة المهام',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardUxStat {
  const DashboardUxStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String helper;
  final VoidCallback? onTap;
}

class DashboardUxStatsSection extends StatelessWidget {
  const DashboardUxStatsSection({required this.stats, super.key});

  final List<DashboardUxStat> stats;

  @override
  Widget build(BuildContext context) {
    return _UxCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _UxSectionTitle(title: 'إحصائيات سريعة'),
          const SizedBox(height: 8),
          _UxTwoColumnWrap(
            children: [
              for (final stat in stats.take(4)) _UxStatTile(stat: stat),
            ],
          ),
        ],
      ),
    );
  }
}

class DashboardUxAction {
  const DashboardUxAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class DashboardUxActionsSection extends StatelessWidget {
  const DashboardUxActionsSection({required this.actions, super.key});

  final List<DashboardUxAction> actions;

  @override
  Widget build(BuildContext context) {
    return _UxCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _UxSectionTitle(title: 'إجراءات سريعة'),
          const SizedBox(height: 10),
          _UxTwoColumnWrap(
            children: [
              for (final action in actions.take(4))
                _UxActionButton(action: action),
            ],
          ),
        ],
      ),
    );
  }
}

class DashboardUxUpcomingItem {
  const DashboardUxUpcomingItem({
    required this.icon,
    required this.title,
    required this.meta,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String meta;
  final VoidCallback? onTap;
}

class DashboardUxUpcomingSection extends StatelessWidget {
  const DashboardUxUpcomingSection({required this.items, super.key});

  final List<DashboardUxUpcomingItem> items;

  @override
  Widget build(BuildContext context) {
    return _UxCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _UxSectionTitle(title: 'اليوم والقادم'),
          const SizedBox(height: 8),
          if (items.isEmpty)
            const DashboardUxEmptyState(
              icon: Icons.inbox_outlined,
              title: 'لا توجد مواعيد قريبة',
              message: 'ستظهر هنا المهام أو المدفوعات القادمة عند توفرها.',
              compact: true,
            )
          else
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) const Divider(height: 12, color: _uxLine),
              _UxUpcomingRow(item: items[i]),
            ],
        ],
      ),
    );
  }
}

class DashboardUxSharedPlanCard extends StatelessWidget {
  const DashboardUxSharedPlanCard({
    required this.participantCount,
    required this.participantNames,
    required this.onOpen,
    super.key,
  });

  final int participantCount;
  final List<String> participantNames;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final names = participantNames
        .where((name) => name.trim().isNotEmpty)
        .take(3)
        .join('، ');
    final summary = participantCount == 0
        ? 'لا يوجد مشاركون بعد'
        : '$participantCount مشارك في هذه الخطة';

    return _UxCard(
      padding: const EdgeInsets.all(14),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(_uxRadius),
        child: Row(
          children: [
            const _UxIconBox(icon: Icons.group_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'الخطة المشتركة',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _uxInk,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    names.isEmpty ? summary : '$summary: $names',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _uxMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_left_rounded, color: _uxMuted),
          ],
        ),
      ),
    );
  }
}

class DashboardUxLoading extends StatelessWidget {
  const DashboardUxLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _UxSkeletonLine(widthFactor: 0.5),
        SizedBox(height: 12),
        _UxSkeletonBox(height: 188),
        SizedBox(height: 12),
        _UxSkeletonBox(height: 152),
        SizedBox(height: 12),
        _UxSkeletonBox(height: 128),
      ],
    );
  }
}

class DashboardUxEmptyState extends StatelessWidget {
  const DashboardUxEmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.compact = false,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 8 : 36, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _uxMuted, size: compact ? 24 : 34),
          const SizedBox(height: 8),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _uxInk,
              fontSize: compact ? 13 : 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            maxLines: compact ? 2 : 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _uxMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _UxCard extends StatelessWidget {
  const _UxCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _uxCard,
        borderRadius: BorderRadius.circular(_uxRadius),
        border: Border.all(color: _uxLine),
        boxShadow: [
          BoxShadow(
            color: _uxBurgundyDark.withAlpha(10),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
  }
}

class _UxIconButton extends StatelessWidget {
  const _UxIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: _uxCard,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _uxLine),
              boxShadow: [
                BoxShadow(
                  color: _uxBurgundyDark.withAlpha(8),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: _uxBurgundy, size: 21),
          ),
        ),
      ),
    );
  }
}

class _UxProgressBadge extends StatelessWidget {
  const _UxProgressBadge({required this.percent});

  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 58,
      height: 58,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: _uxGold.withAlpha(200), width: 3),
        color: Colors.white.withAlpha(26),
      ),
      child: Text(
        '$percent%',
        textDirection: TextDirection.ltr,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _UxMetaChip extends StatelessWidget {
  const _UxMetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(24),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _uxSoftGold.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _uxSoftGold, size: 15),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UxSmallMetric extends StatelessWidget {
  const _UxSmallMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(24),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _uxSoftGold.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _uxSoftGold,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _UxSectionTitle extends StatelessWidget {
  const _UxSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: _uxInk,
        fontSize: 14,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _UxTwoColumnWrap extends StatelessWidget {
  const _UxTwoColumnWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

class _UxStatTile extends StatelessWidget {
  const _UxStatTile({required this.stat});

  final DashboardUxStat stat;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _uxCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: stat.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _uxLine),
            color: _uxCard,
          ),
          child: Row(
            children: [
              _UxIconBox(icon: stat.icon),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      stat.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _uxMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      stat.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        color: _uxBurgundy,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      stat.helper,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _uxMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UxActionButton extends StatelessWidget {
  const _UxActionButton({required this.action});

  final DashboardUxAction action;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _uxCard,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _uxLine),
            color: _uxCard,
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: _uxSoft,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _uxLine),
                ),
                child: Icon(action.icon, color: _uxBurgundy, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  action.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _uxInk,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UxUpcomingRow extends StatelessWidget {
  const _UxUpcomingRow({required this.item});

  final DashboardUxUpcomingItem item;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: item.onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            _UxIconBox(icon: item.icon),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _uxInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              item.meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _uxMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UxIconBox extends StatelessWidget {
  const _UxIconBox({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _uxSoft,
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _uxSoftGold.withAlpha(150)),
      ),
      child: Icon(icon, color: _uxBurgundy, size: 18),
    );
  }
}

class _UxSkeletonLine extends StatelessWidget {
  const _UxSkeletonLine({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: widthFactor,
      child: const _UxSkeletonBox(height: 18),
    );
  }
}

class _UxSkeletonBox extends StatelessWidget {
  const _UxSkeletonBox({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _uxSoft2,
        borderRadius: BorderRadius.circular(_uxRadius),
        border: Border.all(color: _uxLine),
      ),
    );
  }
}

OfflineSyncService? _maybeOfflineService(BuildContext context) {
  try {
    return context.watch<OfflineSyncService>();
  } on ProviderNotFoundException {
    return null;
  }
}

// ============================================================================
// TOP BAR
// ============================================================================

class DashboardTopBar extends StatelessWidget {
  const DashboardTopBar({
    required this.userName,
    this.onProfile,
    this.onNotifications,
    this.hasNotificationDot = true,
    super.key,
  });

  final String userName;
  final VoidCallback? onProfile;
  final VoidCallback? onNotifications;
  final bool hasNotificationDot;

  @override
  Widget build(BuildContext context) {
    final firstName = userName.trim().isEmpty
        ? 'ضيف'
        : userName.trim().split(RegExp(r'\s+')).first;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Text(
                      'أعرسِت',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppTheme.dMaroon,
                        fontFamily: AppTheme.displayFontFamily,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const Positioned(
                      top: -4,
                      right: 82,
                      child: Icon(
                        Icons.favorite_rounded,
                        size: 13,
                        color: AppTheme.dMaroon,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        'مساء الخير، $firstName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.dInkSoft,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.favorite_rounded,
                      color: AppTheme.dGoldDeep,
                      size: 15,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          _IconButton(icon: Icons.person_outline_rounded, onTap: onProfile),
          const SizedBox(width: 10),
          _IconButton(
            icon: Icons.notifications_none_rounded,
            onTap: onNotifications,
            badgeLabel: hasNotificationDot ? '3' : null,
          ),
        ],
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, this.onTap, this.badgeLabel});

  final IconData icon;
  final VoidCallback? onTap;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: AppTheme.dCard,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppTheme.dMaroonDeep.withValues(alpha: 0.10),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, size: 22, color: AppTheme.dInkSoft),
            if (badgeLabel != null)
              Positioned(
                top: 2,
                left: 1,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  height: 18,
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppTheme.dMaroon,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.dCard, width: 2),
                  ),
                  child: Text(
                    badgeLabel!,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// HERO CARD (completion donut + plan meta + countdown)
// ============================================================================

class DashboardHeroCard extends StatefulWidget {
  const DashboardHeroCard({
    required this.title,
    required this.statusLabel,
    required this.tasksDone,
    required this.tasksTotal,
    this.city,
    this.weddingDate,
    super.key,
  });

  final String title;
  final String statusLabel;
  final int tasksDone;
  final int tasksTotal;
  final String? city;
  final DateTime? weddingDate;

  @override
  State<DashboardHeroCard> createState() => _DashboardHeroCardState();
}

class _DashboardHeroCardState extends State<DashboardHeroCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (widget.weddingDate != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String? get _countdownText {
    final date = widget.weddingDate;
    if (date == null) return null;
    final diff = date.difference(DateTime.now());
    if (diff.isNegative) return 'تم الزفاف';
    final days = diff.inDays;
    final hours = diff.inHours % 24;
    final minutes = diff.inMinutes % 60;
    return '$days يوم، $hours ساعات، $minutes دقيقة المتبقية';
  }

  @override
  Widget build(BuildContext context) {
    final progress = widget.tasksTotal > 0
        ? widget.tasksDone / widget.tasksTotal
        : 0.0;
    final pct = (progress * 100).round();
    final completionText = '$pct% مكتمل';
    final subText = '${widget.tasksDone} من ${widget.tasksTotal} مهام مكتملة';

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          colors: [AppTheme.dMaroonBright, AppTheme.dMaroon, AppTheme.dMaroon2],
          stops: [0, 0.45, 1],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.dMaroonDeep.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _HeroPatternPainter())),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // text column (start / right)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.title,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        height: 1.15,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.city != null)
                      _metaRow(icon: Icons.place_outlined, value: widget.city!),
                    if (widget.weddingDate != null)
                      _metaRow(
                        icon: Icons.calendar_today_outlined,
                        value: dashFormatArDate(widget.weddingDate!),
                        label: 'تاريخ الزفاف',
                      ),
                    if (_countdownText != null)
                      _metaRow(
                        icon: Icons.hourglass_bottom_rounded,
                        value: _countdownText!,
                      ),
                    const SizedBox(height: 4),
                    _statusLine(),
                    const SizedBox(height: 10),
                    _progressBar(progress),
                    const SizedBox(height: 10),
                    Text(
                      completionText,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subText,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              // completion donut (end / left)
              Column(
                children: [
                  SizedBox(
                    width: 116,
                    height: 116,
                    child: CustomPaint(
                      painter: _ProgressDonutPainter(progress: progress),
                      child: Center(
                        child: Text(
                          '$pct%',
                          style: const TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    completionText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.dGold2,
                    ),
                  ),
                  SizedBox(
                    width: 120,
                    child: Text(
                      subText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.72),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metaRow({
    required IconData icon,
    required String value,
    String? label,
  }) {
    // RTL: icon on the right, then label, then value flowing left.
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: AppTheme.dGold2),
          const SizedBox(width: 8),
          if (label != null) ...[
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: Colors.white.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.92),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusLine() {
    // RTL: dim label on the right, gold status pill to its left.
    return Row(
      children: [
        Text(
          'حالة الخطة',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.dGold.withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppTheme.dGold.withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 14,
                color: AppTheme.dGold2,
              ),
              const SizedBox(width: 6),
              Text(
                widget.statusLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.dGold2,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _progressBar(double progress) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: Container(
        height: 9,
        color: Colors.white.withValues(alpha: 0.16),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: progress.clamp(0.0, 1.0),
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.dGold, AppTheme.dGold2],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    const gap = 14.0;
    // fade the hatch towards the right (start) edge only
    final rect = Rect.fromLTWH(
      size.width * 0.45,
      0,
      size.width * 0.55,
      size.height,
    );
    canvas.save();
    canvas.clipRect(rect);
    for (var x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + size.height, size.height),
        paint,
      );
      canvas.drawLine(
        Offset(x + size.height, 0),
        Offset(x, size.height),
        paint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ProgressDonutPainter extends CustomPainter {
  _ProgressDonutPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const stroke = 13.0;
    final radius = (size.width - stroke) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.white.withValues(alpha: 0.14);
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.dGold;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(covariant _ProgressDonutPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ============================================================================
// BUDGET SUMMARY CARD (segmented donut + breakdown)
// ============================================================================

class DashboardSnapshotRow extends StatelessWidget {
  const DashboardSnapshotRow({
    required this.totalBudget,
    required this.spent,
    required this.currency,
    required this.tasksDone,
    required this.tasksTotal,
    required this.vendorCount,
    required this.paymentCount,
    required this.guestCount,
    this.onBudgetTap,
    super.key,
  });

  final double totalBudget;
  final double spent;
  final String currency;
  final int tasksDone;
  final int tasksTotal;
  final int vendorCount;
  final int paymentCount;
  final int guestCount;
  final VoidCallback? onBudgetTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final budget = _BudgetSnapshotCard(
          totalBudget: totalBudget,
          spent: spent,
          currency: currency,
          onTap: onBudgetTap,
        );
        final glance = _QuickGlanceSnapshotCard(
          tasksValue: '$tasksDone/$tasksTotal',
          vendorCount: vendorCount,
          paymentCount: paymentCount,
          guestCount: guestCount,
        );

        if (constraints.maxWidth < 350) {
          return Column(children: [budget, const SizedBox(height: 14), glance]);
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: budget),
            const SizedBox(width: 14),
            Expanded(child: glance),
          ],
        );
      },
    );
  }
}

class _BudgetSnapshotCard extends StatelessWidget {
  const _BudgetSnapshotCard({
    required this.totalBudget,
    required this.spent,
    required this.currency,
    this.onTap,
  });

  final double totalBudget;
  final double spent;
  final String currency;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final remaining = math.max(0.0, totalBudget - spent);
    final spentRatio = totalBudget > 0
        ? (spent / totalBudget).clamp(0.0, 1.0)
        : 0.0;

    return _DashCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 12),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SnapshotTitle(
            title: 'ملخص الميزانية',
            icon: Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 14),
          Text(
            'إجمالي الميزانية',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppTheme.dInkSoft,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          _Num(
            '${dashFormatMoney(totalBudget)} $currency',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.dInk,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 66,
                height: 66,
                child: CustomPaint(
                  painter: _SnapshotDonutPainter(progress: spentRatio),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _SnapshotLegendLine(
                      label: 'المصروف',
                      value: '${dashFormatMoney(spent)} $currency',
                      color: AppTheme.dMaroon,
                    ),
                    const SizedBox(height: 10),
                    _SnapshotLegendLine(
                      label: 'المتبقي',
                      value: '${dashFormatMoney(remaining)} $currency',
                      color: AppTheme.dGoldDeep,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _FootLink(label: 'عرض التفاصيل', onTap: onTap ?? () {}),
        ],
      ),
    );
  }
}

class _QuickGlanceSnapshotCard extends StatelessWidget {
  const _QuickGlanceSnapshotCard({
    required this.tasksValue,
    required this.vendorCount,
    required this.paymentCount,
    required this.guestCount,
  });

  final String tasksValue;
  final int vendorCount;
  final int paymentCount;
  final int guestCount;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SnapshotTitle(
            title: 'نظرة سريعة',
            icon: Icons.visibility_outlined,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SnapshotMiniBox(
                  label: 'الموردين',
                  value: '$vendorCount',
                  icon: Icons.groups_rounded,
                  color: AppTheme.dGreen,
                  bg: AppTheme.dGreenBg,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SnapshotMiniBox(
                  label: 'المهام',
                  value: tasksValue,
                  icon: Icons.assignment_turned_in_rounded,
                  color: AppTheme.dMaroon,
                  bg: AppTheme.dPinkBg,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _SnapshotMiniBox(
                  label: 'الضيوف',
                  value: '$guestCount',
                  icon: Icons.people_alt_rounded,
                  color: AppTheme.dGoldDeep,
                  bg: AppTheme.dCreamBg,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _SnapshotMiniBox(
                  label: 'المدفوعات',
                  value: '$paymentCount',
                  icon: Icons.credit_card_rounded,
                  color: AppTheme.dBlue,
                  bg: AppTheme.dBlueBg,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SnapshotTitle extends StatelessWidget {
  const _SnapshotTitle({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.dMaroon, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: AppTheme.dInk,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _SnapshotLegendLine extends StatelessWidget {
  const _SnapshotLegendLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.dInkSoft,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              _Num(
                value,
                style: const TextStyle(
                  color: AppTheme.dInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SnapshotMiniBox extends StatelessWidget {
  const _SnapshotMiniBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.bg,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.dCard2,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.dLine.withAlpha(180)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 7),
          _Num(
            value,
            align: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.dInk,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.dInkSoft,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SnapshotDonutPainter extends CustomPainter {
  const _SnapshotDonutPainter({required this.progress});

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const stroke = 12.0;
    final radius = (size.width - stroke) / 2;
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = AppTheme.dCreamBg;
    final spentPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt
      ..color = AppTheme.dMaroon;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      spentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SnapshotDonutPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class BudgetSummaryCard extends StatelessWidget {
  const BudgetSummaryCard({
    required this.total,
    required this.spent,
    required this.obligations,
    required this.debtsTotal,
    required this.upcomingInstallments,
    required this.currency,
    super.key,
  });

  final double total;
  final double spent;
  final double obligations;
  final double debtsTotal;
  final double upcomingInstallments;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final remaining = math.max(0.0, total - spent - obligations);
    final denom = spent + remaining + obligations;
    double frac(double v) => denom > 0 ? v / denom : 0;

    return _DashCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: title + icon on the right, total on the left (RTL).
          Row(
            children: [
              const _SectionIcon(
                icon: Icons.savings_outlined,
                color: AppTheme.dGoldDeep,
                bg: AppTheme.dCreamBg,
              ),
              const SizedBox(width: 10),
              const Text(
                'ملخص الميزانية',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.dInk,
                ),
              ),
              const Spacer(),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: _Num(
                    '${dashFormatMoney(total)} $currency',
                    align: TextAlign.left,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.dInk,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Body: stat list (right) · donut (center) · legend (left) — RTL order.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _budgetStat(
                      'الديون',
                      '${dashFormatMoney(debtsTotal)} $currency',
                    ),
                    _budgetStat(
                      'الأقساط القادمة',
                      '${dashFormatMoney(upcomingInstallments)} $currency',
                    ),
                    _budgetStat('الميزانية الكلية', dashFormatMoney(total)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 126,
                height: 126,
                child: CustomPaint(
                  painter: _SegmentDonutPainter(
                    segments: [
                      _Segment(frac(spent), AppTheme.dMaroon),
                      _Segment(frac(remaining), AppTheme.dTrack),
                      _Segment(frac(obligations), AppTheme.dGold),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _budgetLine(
                      'المصروف',
                      AppTheme.dMaroon,
                      '${dashFormatMoney(spent)} $currency',
                      frac(spent),
                    ),
                    _budgetLine(
                      'المتبقي',
                      AppTheme.dTrack,
                      '${dashFormatMoney(remaining)} $currency',
                      frac(remaining),
                    ),
                    _budgetLine(
                      'الالتزامات القادمة',
                      AppTheme.dGold,
                      '${dashFormatMoney(obligations)} $currency',
                      frac(obligations),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Right-hand stat: dim label above an LTR value (debts / installments / total).
  Widget _budgetStat(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.dInkSoft,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: _Num(
              value,
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.dInk,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetLine(String label, Color color, String value, double frac) {
    // RTL: content right-aligned (toward the donut); dot sits left of the label.
    return Padding(
      padding: const EdgeInsets.only(bottom: 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.dInk,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 2),
          _Num(
            '$value  (${(frac * 100).round()}%)',
            style: const TextStyle(fontSize: 12, color: AppTheme.dInkSoft),
          ),
        ],
      ),
    );
  }
}

class _Segment {
  const _Segment(this.fraction, this.color);
  final double fraction;
  final Color color;
}

class _SegmentDonutPainter extends CustomPainter {
  _SegmentDonutPainter({required this.segments});

  final List<_Segment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    const stroke = 22.0;
    final radius = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final total = segments.fold<double>(0, (s, e) => s + e.fraction);
    if (total <= 0) {
      final empty = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppTheme.dTrack.withValues(alpha: 0.5);
      canvas.drawCircle(center, radius, empty);
      return;
    }

    var start = -math.pi / 2;
    for (final seg in segments) {
      if (seg.fraction <= 0) continue;
      final sweep = 2 * math.pi * (seg.fraction / total);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = seg.color;
      canvas.drawArc(rect, start, sweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _SegmentDonutPainter oldDelegate) => true;
}

// ============================================================================
// MINI STAT CARDS (upcoming tasks / installments / debts)
// ============================================================================

class MiniStatCard extends StatelessWidget {
  const MiniStatCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.bigValue,
    required this.unit,
    this.subLabel,
    this.subValue,
    this.subValueColor,
    this.subSecondary,
    this.locked = false,
    super.key,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String bigValue;
  final String unit;
  final String? subLabel;
  final String? subValue;
  final Color? subValueColor;
  final String? subSecondary;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      borderRadius: 20,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 23, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppTheme.dInkSoft,
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: _Num(
              locked ? '—' : bigValue,
              align: TextAlign.center,
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                color: AppTheme.dInk,
                height: 1.1,
              ),
            ),
          ),
          Text(
            unit,
            style: const TextStyle(fontSize: 12, color: AppTheme.dMuted),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Container(height: 1, color: AppTheme.dLine),
          ),
          if (locked)
            const Icon(
              Icons.lock_outline_rounded,
              size: 18,
              color: AppTheme.dMuted,
            )
          else ...[
            if (subLabel != null)
              Text(
                subLabel!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: AppTheme.dMuted),
              ),
            if (subValue != null)
              FittedBox(
                fit: BoxFit.scaleDown,
                child: _Num(
                  subValue!,
                  align: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: subValueColor ?? AppTheme.dInk,
                  ),
                ),
              ),
            if (subSecondary != null)
              _Num(
                subSecondary!,
                align: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppTheme.dMuted),
              ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// QUICK ACTIONS
// ============================================================================

class QuickAction {
  const QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final VoidCallback? onTap;
}

class QuickActionsCard extends StatelessWidget {
  const QuickActionsCard({required this.actions, super.key});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: 'إجراءات سريعة',
            icon: Icons.bolt_rounded,
            iconColor: Colors.white,
            iconBg: AppTheme.dMaroon,
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _QuickActionItem(action: actions[i])),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  const _QuickActionItem({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final enabled = action.onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: AppTheme.dCard2,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.dLine),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: action.bg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(action.icon, size: 22, color: action.color),
                ),
                const SizedBox(height: 9),
                SizedBox(
                  height: 30,
                  child: Center(
                    child: Text(
                      action.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.dInk,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ALERTS
// ============================================================================

enum AlertTone { pink, cream, green }

class DashboardAlert {
  const DashboardAlert({
    required this.title,
    required this.body,
    required this.icon,
    required this.tone,
  });

  final String title;
  final String body;
  final IconData icon;
  final AlertTone tone;
}

class AlertsCard extends StatelessWidget {
  const AlertsCard({required this.alerts, this.onViewAll, super.key});

  final List<DashboardAlert> alerts;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: 'تنبيهات مهمة',
            icon: Icons.notifications_none_rounded,
            iconColor: AppTheme.dMaroon,
            iconBg: AppTheme.dPinkBg,
            trailing: Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.dPinkBg,
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Text(
                '!',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppTheme.dMaroon,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (alerts.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'لا توجد تنبيهات حالياً',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.dMuted, fontSize: 13),
              ),
            )
          else
            for (final alert in alerts) ...[
              _AlertTile(alert: alert),
              const SizedBox(height: 11),
            ],
          if (onViewAll != null)
            _FootLink(label: 'عرض كل التنبيهات', onTap: onViewAll!),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile({required this.alert});

  final DashboardAlert alert;

  @override
  Widget build(BuildContext context) {
    final (bg, accent) = switch (alert.tone) {
      AlertTone.pink => (AppTheme.dPinkBg, AppTheme.dMaroon),
      AlertTone.cream => (AppTheme.dCreamBg, AppTheme.dGoldDeep),
      AlertTone.green => (AppTheme.dGreenBg, AppTheme.dGreen),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // RTL: white icon tile on the right, text to its left (right-aligned).
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.dMaroonDeep.withValues(alpha: 0.12),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(alert.icon, size: 19, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alert.title,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  alert.body,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: AppTheme.dInkSoft,
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

// ============================================================================
// PARTICIPANTS
// ============================================================================

class ParticipantInfo {
  const ParticipantInfo({
    required this.name,
    required this.roleLabel,
    required this.isManager,
    this.phone,
  });

  final String name;
  final String roleLabel;
  final bool isManager;
  final String? phone;
}

class ParticipantsCard extends StatelessWidget {
  const ParticipantsCard({
    required this.participants,
    required this.count,
    this.onAddMember,
    super.key,
  });

  final List<ParticipantInfo> participants;
  final int count;
  final VoidCallback? onAddMember;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: 'المشاركون في الخطة',
            icon: Icons.groups_rounded,
            iconColor: Colors.white,
            iconBg: AppTheme.dMaroon,
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 5),
              decoration: BoxDecoration(
                color: AppTheme.dMaroon,
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                '$count عضو',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (participants.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'لا يوجد مشاركون بعد',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.dMuted, fontSize: 13),
              ),
            )
          else
            for (var i = 0; i < participants.length; i++)
              _ParticipantTile(
                info: participants[i],
                showDivider: i < participants.length - 1,
              ),
          if (onAddMember != null)
            _FootLink(label: 'إضافة عضو', onTap: onAddMember!),
        ],
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.info, required this.showDivider});

  final ParticipantInfo info;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: AppTheme.dLine))
            : null,
      ),
      child: Row(
        children: [
          _Avatar(name: info.name),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  info.name,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.dInk,
                  ),
                ),
                if (info.phone != null)
                  _Num(
                    info.phone!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.dMuted,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 3),
            decoration: BoxDecoration(
              color: info.isManager ? AppTheme.dCreamBg : AppTheme.dGreenBg,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              info.roleLabel,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: info.isManager ? AppTheme.dGoldDeep : AppTheme.dGreen,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  static const _palette = [
    Color(0xFFB6432F),
    Color(0xFF3A3A3A),
    Color(0xFF4F6D7A),
    Color(0xFF8A5A44),
    Color(0xFF5B6E4F),
  ];

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim().characters.first : '؟';
    final color = _palette[name.hashCode.abs() % _palette.length];
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppTheme.dMaroonDeep.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

// ============================================================================
// SHARED PLANS
// ============================================================================

class SharedPlansCard extends StatelessWidget {
  const SharedPlansCard({required this.onOpen, this.subtitle, super.key});

  final VoidCallback onOpen;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(
            title: 'الخطط المشتركة معي',
            icon: Icons.groups_rounded,
            iconColor: Colors.white,
            iconBg: AppTheme.dMaroon,
            trailing: subtitle == null
                ? null
                : Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.dInkSoft,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          Material(
            borderRadius: BorderRadius.circular(16),
            color: Colors.transparent,
            child: InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 15,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [AppTheme.dMaroonBright, AppTheme.dMaroon],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.dMaroon.withValues(alpha: 0.45),
                      blurRadius: 22,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.folder_shared_rounded,
                        size: 22,
                        color: AppTheme.dGold2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'عرض الخطط المشتركة',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.chevron_left_rounded, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// BOTTOM NAV
// ============================================================================

class DashboardBottomNav extends StatelessWidget {
  const DashboardBottomNav({
    this.onHome,
    this.onMoney,
    this.onTasks,
    this.onAdd,
    this.onProviders,
    this.onMore,
    this.activeIndex = 0,
    super.key,
  });

  final VoidCallback? onHome;
  final VoidCallback? onMoney;
  final VoidCallback? onTasks;
  final VoidCallback? onAdd;
  final VoidCallback? onProviders;
  final VoidCallback? onMore;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(top: BorderSide(color: Color(0xFFD8D8D8))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _WireNavItem(
                      icon: Icons.home_rounded,
                      label: 'الرئيسية',
                      active: activeIndex == 0,
                      onTap: onHome,
                    ),
                    _WireNavItem(
                      icon: Icons.account_balance_wallet_outlined,
                      label: 'المال',
                      active: activeIndex == 1,
                      onTap: onMoney,
                    ),
                    _WireNavItem(
                      icon: Icons.checklist_rounded,
                      label: 'المهام',
                      active: activeIndex == 2,
                      onTap: onTasks,
                    ),
                    const SizedBox(width: 64),
                    _WireNavItem(
                      icon: Icons.storefront_outlined,
                      label: 'الموردون',
                      active: activeIndex == 3,
                      onTap: onProviders,
                    ),
                    _WireNavItem(
                      icon: Icons.grid_view_rounded,
                      label: 'المزيد',
                      active: activeIndex == 4,
                      onTap: onMore,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -22,
                child: InkWell(
                  onTap: onAdd,
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppTheme.dMaroon,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.dGold2, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WireNavItem extends StatelessWidget {
  const _WireNavItem({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.dMaroon : AppTheme.dMuted;
    return InkResponse(
      onTap: onTap,
      radius: 36,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 54,
        height: 52,
        decoration: BoxDecoration(
          color: active ? AppTheme.dPinkBg.withAlpha(90) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: active ? Border.all(color: AppTheme.dLine, width: 0.8) : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 23, color: color),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: active ? FontWeight.w900 : FontWeight.w700,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
class _UnusedDashboardBottomNav extends StatelessWidget {
  const _UnusedDashboardBottomNav();

  final VoidCallback? onMore = null;
  final VoidCallback? onTasks = null;
  final VoidCallback? onAdd = null;
  final VoidCallback? onPlans = null;
  final VoidCallback? onHome = null;
  final int activeIndex = 4;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _uxCard,
        border: const Border(top: BorderSide(color: _uxLine)),
        boxShadow: [
          BoxShadow(
            color: _uxBurgundyDark.withAlpha(20),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _NavItem(
                      icon: Icons.home_rounded,
                      label: 'الرئيسية',
                      active: activeIndex == 4,
                      onTap: onHome,
                    ),
                    _NavItem(
                      icon: Icons.calendar_month_rounded,
                      label: 'المهام',
                      active: activeIndex == 1,
                      onTap: onTasks,
                    ),
                    const SizedBox(width: 90),
                    _NavItem(
                      icon: Icons.work_outline_rounded,
                      label: 'الموردين',
                      active: activeIndex == 3,
                      onTap: onPlans,
                    ),
                    _NavItem(
                      icon: Icons.grid_view_rounded,
                      label: 'المزيد',
                      active: activeIndex == 0,
                      onTap: onMore,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: -24,
                child: GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 62,
                    height: 62,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(
                        colors: [_uxBurgundy, _uxBurgundyDark],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _uxBurgundy.withAlpha(70),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                      border: Border.all(color: _uxSoftGold, width: 1.5),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? _uxBurgundy : _uxMuted;
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 24, color: color),
        const SizedBox(height: 5),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: active ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
    return InkResponse(
      onTap: onTap,
      radius: 36,
      child: SizedBox(width: 60, child: content),
    );
  }
}

// ============================================================================
// ACCOUNT SHEET (profile + logout)
// ============================================================================

Future<void> showAccountSheet(
  BuildContext context, {
  required String name,
  String? phone,
  required VoidCallback onLogout,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.dCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.dLine,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: const BoxDecoration(
                        color: AppTheme.dPinkBg,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        color: AppTheme.dMaroon,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.dInk,
                            ),
                          ),
                          if (phone != null)
                            _Num(
                              phone,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppTheme.dMuted,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.dMaroon,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    onLogout();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 20),
                  label: const Text('تسجيل الخروج'),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

// ============================================================================
// LOCKED SECTION + LOADING SKELETON
// ============================================================================

class LockedSectionCard extends StatelessWidget {
  const LockedSectionCard({required this.title, required this.icon, super.key});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return _DashCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: AppTheme.dMuted),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.dMuted,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'غير متاح حسب صلاحياتك',
                style: TextStyle(fontSize: 12, color: AppTheme.dMuted),
              ),
            ],
          ),
          const SizedBox(width: 10),
          _SectionIcon(icon: icon, color: AppTheme.dMuted, bg: AppTheme.dLine),
        ],
      ),
    );
  }
}

class DashboardSkeleton extends StatefulWidget {
  const DashboardSkeleton({super.key});

  @override
  State<DashboardSkeleton> createState() => _DashboardSkeletonState();
}

class _DashboardSkeletonState extends State<DashboardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 0.75).animate(_controller),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            children: [
              _box(180),
              const SizedBox(height: 16),
              _box(150),
              const SizedBox(height: 16),
              _box(120),
              const SizedBox(height: 16),
              _box(160),
            ],
          ),
        ),
      ),
    );
  }

  Widget _box(double height) => Container(
    height: height,
    decoration: BoxDecoration(
      color: AppTheme.dTrack.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(22),
    ),
  );
}

// ============================================================================
// SHARED PRIMITIVES
// ============================================================================

class _DashCard extends StatelessWidget {
  const _DashCard({
    required this.child,
    required this.padding,
    this.borderRadius = 22,
  });

  final Widget child;
  final EdgeInsets padding;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppTheme.dCard,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.dMaroonDeep.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    // RTL: leading icon on the right, optional trailing widget on the left.
    return Row(
      children: [
        _SectionIcon(icon: icon, color: iconColor, bg: iconBg),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: AppTheme.dInk,
            ),
          ),
        ),
        if (trailing != null) ...[const SizedBox(width: 10), trailing!],
      ],
    );
  }
}

class _SectionIcon extends StatelessWidget {
  const _SectionIcon({
    required this.icon,
    required this.color,
    required this.bg,
  });

  final IconData icon;
  final Color color;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, size: 21, color: color),
    );
  }
}

class _FootLink extends StatelessWidget {
  const _FootLink({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          // RTL: label on the right, forward chevron to its left.
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.dMaroon,
              ),
            ),
            const SizedBox(width: 6),
            const Icon(
              Icons.chevron_left_rounded,
              size: 18,
              color: AppTheme.dMaroon,
            ),
          ],
        ),
      ),
    );
  }
}

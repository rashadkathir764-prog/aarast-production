import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../../core/theme/aarast_design_tokens.dart';
import '../../models/dashboard_summary.dart';

class AarastParticipantsGlanceCard extends StatelessWidget {
  const AarastParticipantsGlanceCard({
    required this.summary,
    required this.onOpenSharing,
    super.key,
  });

  final DashboardSummary summary;
  final VoidCallback onOpenSharing;

  bool get _canManageSharing =>
      summary.permissions.isOwner || summary.permissions.canManageMembers;

  String get _roleLabel {
    final role = (summary.currentUserRole ?? summary.permissions.role ?? '')
        .toUpperCase();
    if (summary.permissions.isOwner || role == 'OWNER') return 'مالك الخطة';
    if (role.contains('MANAGER')) return 'مدير';
    if (role.contains('CONTRIBUTOR')) return 'مساهم';
    if (role.contains('VIEWER')) return 'مشاهد';
    if (summary.isLocalOnly) return 'خطة محلية';
    return 'عضو في الخطة';
  }

  String get _body {
    if (summary.isLocalOnly) {
      return 'المشاركة تحتاج حساباً لحفظ الصلاحيات والدعوات بأمان.';
    }
    if (summary.participantCount <= 1 && summary.pendingInvites == 0) {
      return 'أنت فقط على هذه الخطة حتى الآن.';
    }
    if (summary.pendingInvites > 0) {
      return '${summary.pendingInvites} دعوة بانتظار الرد.';
    }
    return 'صلاحيات المشاركين مرتبطة بهذه الخطة.';
  }

  String get _actionLabel {
    if (summary.isLocalOnly) return 'تفعيل المشاركة';
    return _canManageSharing ? 'إدارة المشاركين' : 'عرض المشاركة';
  }

  /// الكرت الكامل يستحق مساحته فقط عندما يوجد ما يتصرف المستخدم حياله؛
  /// خلاف ذلك يكفي صف هادئ لا ينافس الميزانية والمهام بصريًا.
  bool get _needsAttention => summary.pendingInvites > 0 || summary.isLocalOnly;

  @override
  Widget build(BuildContext context) {
    return _needsAttention ? _buildFull(context) : _buildCompact(context);
  }

  Widget _buildCompact(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final count = summary.participantCount;
    final caption = count <= 1 ? 'أنت فقط حتى الآن' : '$count مشاركين';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenSharing,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            color: AarastDesignTokens.infoSoft.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AarastDesignTokens.surface,
                  borderRadius: BorderRadius.circular(
                    AarastDesignTokens.radiusSm,
                  ),
                ),
                child: const Icon(
                  LucideIcons.users,
                  color: AarastDesignTokens.info,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'المشاركون في الخطة',
                    style: textTheme.labelLarge?.copyWith(
                      color: AarastDesignTokens.ink,
                    ),
                    children: [
                      TextSpan(
                        text: ' · $caption',
                        style: textTheme.labelMedium?.copyWith(
                          color: AarastDesignTokens.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                LucideIcons.chevronLeft,
                size: 18,
                color: AarastDesignTokens.muted.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFull(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenSharing,
        borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
        child: Ink(
          decoration: BoxDecoration(
            color: AarastDesignTokens.surface,
            borderRadius: BorderRadius.circular(AarastDesignTokens.radiusLg),
            border: Border.all(color: AarastDesignTokens.border),
            boxShadow: [
              BoxShadow(
                color: AarastDesignTokens.ink.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AarastDesignTokens.infoSoft,
                      borderRadius: BorderRadius.circular(
                        AarastDesignTokens.radiusSm,
                      ),
                    ),
                    child: const Icon(
                      LucideIcons.users,
                      color: AarastDesignTokens.info,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'المشاركون في الخطة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        color: AarastDesignTokens.title,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Icon(
                    LucideIcons.chevronLeft,
                    size: 20,
                    color: AarastDesignTokens.muted.withValues(alpha: 0.7),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _ParticipantMetric(
                    label: 'المشاركون',
                    value: summary.participantCount.toString(),
                  ),
                  _ParticipantMetric(
                    label: 'دعوات معلقة',
                    value: summary.pendingInvites.toString(),
                  ),
                  _ParticipantMetric(label: 'دورك', value: _roleLabel),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AarastDesignTokens.infoSoft.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(
                    AarastDesignTokens.radiusSm,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.shieldCheck,
                      size: 16,
                      color: AarastDesignTokens.info,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.labelMedium?.copyWith(
                          color: AarastDesignTokens.ink,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  _actionLabel,
                  style: textTheme.labelMedium?.copyWith(
                    color: AarastDesignTokens.burgundy,
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

class _ParticipantMetric extends StatelessWidget {
  const _ParticipantMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.labelSmall?.copyWith(
              color: AarastDesignTokens.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              maxLines: 1,
              style: textTheme.titleMedium?.copyWith(
                color: AarastDesignTokens.ink,
                fontWeight: FontWeight.w800,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

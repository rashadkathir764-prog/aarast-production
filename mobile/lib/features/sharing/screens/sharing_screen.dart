import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/aarast_motion.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/utils/auth_action_guard.dart';
import '../models/shared_member.dart';
import '../providers/sharing_provider.dart';
import '../widgets/shared_member_card.dart';

class SharingScreen extends StatefulWidget {
  const SharingScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<SharingScreen> createState() => _SharingScreenState();
}

class _SharingScreenState extends State<SharingScreen> {
  bool _isCheckingSharingAccess = true;
  bool _showLoginGate = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshSharingAccessAndLoad();
    });
  }

  @override
  void didUpdateWidget(covariant SharingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _refreshSharingAccessAndLoad();
      });
    }
  }

  Future<void> _refreshSharingAccessAndLoad() async {
    setState(() {
      _isCheckingSharingAccess = true;
      _showLoginGate = false;
    });

    final shouldGate = await AuthActionGuard.shouldGateProtectedSharing(
      context,
      weddingPlanId: widget.weddingPlanId,
    );
    if (!mounted) return;

    setState(() {
      _isCheckingSharingAccess = false;
      _showLoginGate = shouldGate;
    });

    if (!shouldGate) {
      await context.read<SharingProvider>().loadMembers(widget.weddingPlanId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SharingProvider>();

    return AarastPageScaffold(
      title: 'المشاركة والصلاحيات',
      subtitle: 'شارك الخطة وحدد ما يمكن لكل عضو رؤيته أو إدارته',
      showBack: true,
      child: RefreshIndicator(
        color: AppTheme.burgundy,
        onRefresh: () {
          if (_showLoginGate ||
              provider.authGateKind == SharingAuthGateKind.sessionExpired) {
            return Future<void>.value();
          }
          return provider.loadMembers(widget.weddingPlanId);
        },
        child: _SharingContent(
          provider: provider,
          weddingPlanId: widget.weddingPlanId,
          isCheckingSharingAccess: _isCheckingSharingAccess,
          showLoginGate: _showLoginGate,
        ),
      ),
    );
  }
}

class _SharingContent extends StatelessWidget {
  const _SharingContent({
    required this.provider,
    required this.weddingPlanId,
    required this.isCheckingSharingAccess,
    required this.showLoginGate,
  });

  final SharingProvider provider;
  final String weddingPlanId;
  final bool isCheckingSharingAccess;
  final bool showLoginGate;

  @override
  Widget build(BuildContext context) {
    if (isCheckingSharingAccess) {
      return AarastSkeleton.list(rows: 6, rowHeight: 60, withHeader: true);
    }

    if (showLoginGate) {
      return const AuthGatePanel(
        title: AuthActionGuard.sharingLoginGateTitle,
        body: AuthActionGuard.sharingLoginGateBody,
        icon: LucideIcons.userPlus,
      );
    }

    if (provider.authGateKind == SharingAuthGateKind.sessionExpired) {
      return const AuthGatePanel(
        title: AuthActionGuard.sessionExpiredTitle,
        body: AuthActionGuard.sharingSessionExpiredBody,
        icon: LucideIcons.fileClock,
      );
    }

    if (provider.isLoading && provider.members.isEmpty) {
      return AarastSkeleton.list(rows: 6, rowHeight: 60, withHeader: true);
    }

    if (provider.errorMessage != null && provider.members.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 40),
          AarastErrorState(
            title: 'تعذر تحميل المشاركة',
            message: provider.errorMessage!,
            onRetry: () => provider.loadMembers(weddingPlanId),
          ),
        ],
      );
    }

    final pendingInvites = provider.invites
        .where((invite) => invite.isPending)
        .toList();

    return ListView(
      children: AarastStagger.children(context, [
        const _PrivacyStrip(),
        const SizedBox(height: 12),
        AarastButton(
          label: 'إضافة عضو',
          icon: LucideIcons.userPlus,
          onPressed: provider.isSubmitting
              ? null
              : () => context.push(AppRouter.addSharedMember(weddingPlanId)),
        ),
        if (provider.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            provider.errorMessage!,
            textAlign: TextAlign.right,
            style: const TextStyle(color: AppTheme.danger),
          ),
        ],
        if (pendingInvites.isNotEmpty) ...[
          const SizedBox(height: 18),
          _SectionTitle('الدعوات المعلقة (${pendingInvites.length})'),
          const SizedBox(height: 8),
          for (final invite in pendingInvites)
            _PendingInviteCard(
              invite: invite,
              onCancel: provider.isSubmitting
                  ? null
                  : () => provider.cancelInvite(invite),
            ),
        ],
        const SizedBox(height: 18),
        _SectionTitle('المشاركون (${provider.members.length})'),
        const SizedBox(height: 8),
        if (provider.members.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
            ),
            child: Text(
              'الخطة خاصة بك الآن. استخدم زر إضافة عضو لإضافة شخص موثوق.',
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: AppTheme.muted),
              textAlign: TextAlign.center,
            ),
          ),
        for (final member in provider.members)
          SharedMemberCard(
            member: member,
            onTap: member.isOwner
                ? null
                : () {
                    provider.selectMember(member);
                    context.push(AppRouter.editSharedMember(member.id));
                  },
          ),
      ]),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.right,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        color: AppTheme.deepBurgundy,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

/// سطر خصوصية واحد يغني عن كرتَي الشرح السابقين — العنوان في ترويسة
/// الصفحة أصلًا، والمهم الوحيد هنا: المال لا يُشارك إلا بصلاحية.
class _PrivacyStrip extends StatelessWidget {
  const _PrivacyStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.gold.withAlpha(26),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        children: [
          const Icon(LucideIcons.lock, size: 15, color: AppTheme.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'المال خاص افتراضيًا — لا يظهر لأي عضو إلا بصلاحية تمنحها.',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppTheme.ink,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingInviteCard extends StatelessWidget {
  const _PendingInviteCard({required this.invite, required this.onCancel});

  final PlanInvite invite;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return AarastCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppTheme.gold.withAlpha(26),
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.send, size: 15, color: AppTheme.gold),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invite.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${sharedMemberRoleLabel(invite.role)} · بانتظار القبول',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: AppTheme.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'إلغاء الدعوة',
            onPressed: onCancel,
            icon: const Icon(LucideIcons.x, size: 18, color: AppTheme.muted),
          ),
        ],
      ),
    );
  }
}

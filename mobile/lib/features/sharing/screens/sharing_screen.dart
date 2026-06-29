import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
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
        color: AppTheme.dMaroon,
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
      return const Center(child: CircularProgressIndicator());
    }

    if (showLoginGate) {
      return const AuthGatePanel(
        title: AuthActionGuard.sharingLoginGateTitle,
        body: AuthActionGuard.sharingLoginGateBody,
        icon: Icons.group_add_outlined,
      );
    }

    if (provider.authGateKind == SharingAuthGateKind.sessionExpired) {
      return const AuthGatePanel(
        title: AuthActionGuard.sessionExpiredTitle,
        body: AuthActionGuard.sharingSessionExpiredBody,
        icon: Icons.lock_clock_outlined,
      );
    }

    if (provider.isLoading && provider.members.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && provider.members.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Text(
            provider.errorMessage!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.danger),
          ),
          const SizedBox(height: 16),
          AarastButton(
            label: 'إعادة المحاولة',
            icon: Icons.refresh_rounded,
            onPressed: () => provider.loadMembers(weddingPlanId),
          ),
        ],
      );
    }

    return ListView(
      children: [
        const _PrivacyNotice(),
        const SizedBox(height: 12),
        AarastButton(
          label: 'إضافة عضو',
          icon: Icons.person_add,
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
        const SizedBox(height: 18),
        if (provider.invites.any((invite) => invite.isPending)) ...[
          Text(
            'الدعوات المعلقة',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.deepBurgundy,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 8),
          for (final invite in provider.invites.where(
            (invite) => invite.isPending,
          ))
            _PendingInviteCard(
              invite: invite,
              onCancel: provider.isSubmitting
                  ? null
                  : () => provider.cancelInvite(invite),
            ),
          const SizedBox(height: 14),
        ],
        Text(
          'المشاركون المقبولون',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.deepBurgundy,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.right,
        ),
        if (provider.members.isEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.dCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.dLine),
            ),
            child: const Text(
              'الخطة خاصة بك الآن. استخدم زر إضافة عضو لإضافة شخص موثوق.',
              style: TextStyle(
                color: AppTheme.dInkSoft,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
        const SizedBox(height: 8),
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
      ],
    );
  }
}

class _PendingInviteCard extends StatelessWidget {
  const _PendingInviteCard({required this.invite, required this.onCancel});

  final PlanInvite invite;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AarastCard(
        color: AppTheme.dCard,
        border: Border.all(color: AppTheme.dLine),
        child: Row(
          children: [
            const Icon(Icons.schedule_send_outlined, color: AppTheme.dGoldDeep),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invite.displayName,
                    style: const TextStyle(
                      color: AppTheme.dInk,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '${sharedMemberRoleLabel(invite.role)} • بانتظار القبول',
                    style: const TextStyle(
                      color: AppTheme.dInkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            AarastButton(
              label: 'إلغاء الدعوة',
              variant: AarastButtonVariant.ghost,
              expand: false,
              onPressed: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.dCard,
      border: Border.all(color: AppTheme.dLine),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'إدارة الخصوصية',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.deepBurgundy,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 8),
          const Text(
            'هذه الشاشة مخصصة لمالك الخطة. البيانات المالية مثل الميزانية والمصاريف والديون لا تظهر للأعضاء إلا بصلاحية واضحة.',
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

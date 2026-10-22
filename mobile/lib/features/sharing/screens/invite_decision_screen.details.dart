part of 'invite_decision_screen.dart';

class _InviteDetails extends StatelessWidget {
  const _InviteDetails({
    required this.invite,
    required this.isSubmitting,
    required this.onAccept,
    required this.onDecline,
    required this.onOpenAcceptedPlan,
    required this.onBack,
    this.errorMessage,
  });

  final PlanInvite invite;
  final bool isSubmitting;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onOpenAcceptedPlan;
  final VoidCallback onBack;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        if (invite.hasActiveMembership)
          _InviteJoinedHero(invite: invite)
        else if (invite.hasEndedMembership)
          const _EndedMembershipHero()
        else
          _InvitePlanHero(invite: invite),
        if (!invite.hasEndedMembership) ...[
          const SizedBox(height: 14),
          _InvitePermissionsCard(invite: invite),
        ],
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          _InlineError(errorMessage!),
        ],
        const SizedBox(height: 16),
        if (invite.isPending) ...[
          AarastButton(
            key: const Key('invite-accept-button'),
            label: 'قبول والانضمام',
            icon: LucideIcons.checkCircle2,
            isLoading: isSubmitting,
            onPressed: isSubmitting ? null : onAccept,
          ),
          const SizedBox(height: 10),
          AarastButton(
            key: const Key('invite-decline-button'),
            label: 'رفض الدعوة',
            variant: AarastButtonVariant.secondary,
            onPressed: isSubmitting ? null : onDecline,
          ),
        ] else if (invite.hasActiveMembership)
          AarastButton(
            key: const Key('invite-open-plan-button'),
            label: 'الدخول إلى الخطة',
            icon: LucideIcons.arrowLeft,
            isLoading: isSubmitting,
            onPressed: isSubmitting ? null : onOpenAcceptedPlan,
          )
        else if (invite.hasEndedMembership)
          const _ClosedInviteStatus(status: 'MEMBERSHIP_ENDED')
        else
          _ClosedInviteStatus(status: invite.status),
        const SizedBox(height: 10),
        AarastButton(
          label: 'رجوع',
          variant: AarastButtonVariant.ghost,
          onPressed: isSubmitting ? null : onBack,
        ),
      ],
    );
  }
}

class _InvitePlanHero extends StatelessWidget {
  const _InvitePlanHero({required this.invite});

  final PlanInvite invite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.gapXl),
      decoration: BoxDecoration(
        color: AppTheme.textPrimary,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.focus.withValues(alpha: 0.72)),
      ),
      child: Column(
        children: [
          const _WeddingRingsMark(),
          const SizedBox(height: 12),
          Text(
            'أنت مدعو للمساهمة في',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.brandMuted,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            invite.weddingPlanTitle ?? 'خطة زفاف مشتركة',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontFamily: AppTheme.displayFontFamily,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusPill),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                const Icon(
                  LucideIcons.user,
                  color: AppTheme.brandMuted,
                  size: 17,
                ),
                Text(
                  'الداعي: ${invite.inviterName ?? 'صاحب الخطة'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '• ${sharedMemberRoleLabel(invite.role)}',
                  style: const TextStyle(
                    color: AppTheme.brandMuted,
                    fontWeight: FontWeight.w900,
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

class _InviteJoinedHero extends StatelessWidget {
  const _InviteJoinedHero({required this.invite});

  final PlanInvite invite;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('invite-joined-success'),
      padding: const EdgeInsets.all(AppTheme.gapXl),
      decoration: BoxDecoration(
        color: AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.34)),
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: AppTheme.surfaceRaised,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.focus, width: 2),
            ),
            child: const Icon(
              LucideIcons.check,
              color: AppTheme.success,
              size: 34,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'تم الانضمام بنجاح',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
              fontFamily: AppTheme.displayFontFamily,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'أصبحت ${sharedMemberRoleLabel(invite.role)} في ${invite.weddingPlanTitle ?? 'الخطة المشتركة'}.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndedMembershipHero extends StatelessWidget {
  const _EndedMembershipHero();

  @override
  Widget build(BuildContext context) {
    return AarastEmptyState(
      key: const Key('invite-membership-ended'),
      icon: LucideIcons.userX,
      title: 'انتهت عضويتك في هذه الخطة',
      message:
          'هذه الدعوة مقبولة سابقًا، لكن عضويتك في الخطة لم تعد فعالة. '
          'اطلب من صاحب الخطة إرسال دعوة جديدة.',
    );
  }
}

class _InvitePermissionsCard extends StatelessWidget {
  const _InvitePermissionsCard({required this.invite});

  final PlanInvite invite;

  @override
  Widget build(BuildContext context) {
    final financeMessage = invite.canManageMoney
        ? 'يمكنك مشاهدة المال وإدارته ضمن هذه الخطة.'
        : invite.canViewMoney
        ? 'يمكنك مشاهدة المال، لكن التعديل يحتاج صلاحية إدارة المال.'
        : 'الميزانية والتكاليف والدفعات خاصة ولن تظهر لك.';

    return AarastCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: AppTheme.brandMuted,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(
                  LucideIcons.shieldCheck,
                  color: AppTheme.brand,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'صلاحياتك في الخطة',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'راجع ما ستتمكن من الوصول إليه قبل الانضمام.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 300 ? 2 : 1;
              final width =
                  (constraints.maxWidth - (columns - 1) * 8) / columns;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final label in invite.permissionLabels)
                    SizedBox(
                      width: width,
                      child: _PermissionTile(
                        label: label,
                        icon: _permissionIcon(label),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: invite.canViewMoney
                  ? AppTheme.successSoft
                  : AppTheme.canvas,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(
                color: invite.canViewMoney
                    ? AppTheme.success.withValues(alpha: 0.22)
                    : AppTheme.border,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  invite.canViewMoney
                      ? LucideIcons.walletCards
                      : LucideIcons.lock,
                  color: invite.canViewMoney
                      ? AppTheme.success
                      : AppTheme.textSecondary,
                  size: 19,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    financeMessage,
                    style: TextStyle(
                      color: invite.canViewMoney
                          ? AppTheme.success
                          : AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
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

class _WeddingRingsMark extends StatelessWidget {
  const _WeddingRingsMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 58,
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PositionedDirectional(
            start: 8,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.brandMuted, width: 2),
              ),
            ),
          ),
          PositionedDirectional(
            end: 8,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.focus, width: 2),
              ),
            ),
          ),
          const Positioned(
            top: 0,
            child: Icon(
              LucideIcons.heart,
              color: AppTheme.brandMuted,
              size: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.canvas,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.brand, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                height: 1.25,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(
            LucideIcons.checkCircle2,
            color: AppTheme.success,
            size: 15,
          ),
        ],
      ),
    );
  }
}

IconData _permissionIcon(String label) {
  return switch (label) {
    'المهام' => LucideIcons.listChecks,
    'الضيوف' => LucideIcons.users,
    'الخدمات والمزودين' => LucideIcons.store,
    'دعوة أعضاء' => LucideIcons.userPlus,
    'إدارة المال' || 'مشاهدة المال' => LucideIcons.walletCards,
    _ => LucideIcons.eye,
  };
}

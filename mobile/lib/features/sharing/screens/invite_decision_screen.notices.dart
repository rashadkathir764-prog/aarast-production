part of 'invite_decision_screen.dart';

class _InviteListCard extends StatelessWidget {
  const _InviteListCard({required this.invite, required this.onTap});

  final PlanInvite invite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.brandMuted,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: const Icon(LucideIcons.mailCheck),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      invite.weddingPlanTitle ?? 'خطة زفاف مشتركة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${sharedMemberRoleLabel(invite.role)} • ${_statusLabel(invite.status)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.arrowRight, color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoInviteState extends StatelessWidget {
  const _NoInviteState({
    required this.message,
    required this.onChangePhone,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onChangePhone;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        AarastEmptyState(
          icon: LucideIcons.mailQuestion,
          title: 'لا توجد دعوة',
          message: message,
        ),
        const SizedBox(height: 12),
        AarastButton(
          label: 'تغيير الرقم',
          variant: AarastButtonVariant.secondary,
          onPressed: onChangePhone,
        ),
        const SizedBox(height: 10),
        AarastButton(
          label: 'إعادة المحاولة',
          variant: AarastButtonVariant.ghost,
          onPressed: onRetry,
        ),
        const SizedBox(height: 10),
        AarastButton(
          label: 'العودة',
          variant: AarastButtonVariant.ghost,
          onPressed: () => context.go(AppRouter.welcome),
        ),
      ],
    );
  }
}

class _InviteAccountSetupNotice extends StatelessWidget {
  const _InviteAccountSetupNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.brandMuted,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.focus.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(LucideIcons.keyRound, size: 20, color: AppTheme.brand),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'أنشئ حساب المساهم مرة واحدة',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'اختر اسمًا وكلمة مرور. بعد ذلك يمكنك الدخول مباشرة دون طلب رمز تحقق في كل مرة.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
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

class _InviteNotice extends StatelessWidget {
  const _InviteNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.brandMuted,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.brand),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                    height: 1.45,
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

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dangerSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.danger.withValues(alpha: 0.24)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppTheme.danger,
          fontWeight: FontWeight.w800,
          height: 1.4,
        ),
      ),
    );
  }
}

class _ClosedInviteStatus extends StatelessWidget {
  const _ClosedInviteStatus({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = _statusLabel(status);
    return AarastEmptyState(
      icon: LucideIcons.info,
      title: label,
      message: switch (status) {
        'MEMBERSHIP_ENDED' =>
          'هذه الدعوة مقبولة سابقًا، لكن عضويتك في الخطة لم تعد فعالة. اطلب من صاحب الخطة إرسال دعوة جديدة.',
        'DECLINED' => 'تم رفض هذه الدعوة سابقًا.',
        'EXPIRED' =>
          'انتهت صلاحية الدعوة. اطلب من صاحب الخطة إرسال دعوة جديدة.',
        'CANCELLED' => 'تم إلغاء هذه الدعوة من صاحب الخطة.',
        _ => 'حالة الدعوة الحالية: $label',
      },
    );
  }
}

String _statusLabel(String status) {
  return switch (status) {
    'PENDING' => 'بانتظار القبول',
    'ACCEPTED' => 'مقبولة',
    'MEMBERSHIP_ENDED' => 'انتهت العضوية',
    'DECLINED' => 'مرفوضة',
    'EXPIRED' => 'منتهية',
    'CANCELLED' => 'ملغاة',
    _ => status,
  };
}

String _maskedPhone(String phone) {
  final compact = phone.replaceAll(RegExp(r'\s+'), '');
  if (compact.length <= 4) return compact;
  return '••• ${compact.substring(compact.length - 4)}';
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../auth/providers/auth_controller.dart';
import '../models/shared_member.dart';
import '../providers/sharing_provider.dart';

enum _InviteAccessStep { phone, otp, invites }

class InviteDecisionScreen extends StatefulWidget {
  const InviteDecisionScreen({this.token, super.key});

  final String? token;

  @override
  State<InviteDecisionScreen> createState() => _InviteDecisionScreenState();
}

class _InviteDecisionScreenState extends State<InviteDecisionScreen> {
  static const _otpLength = 6;
  static const _otpPurpose = 'LOGIN';

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  _InviteAccessStep _step = _InviteAccessStep.phone;
  String? _devOtpMessage;
  PlanInvite? _openedInvite;

  String? get _token {
    final value = widget.token?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthController>();
      if (auth.status == AuthStatus.authenticated) {
        _loadVerifiedInvites();
      }
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showError('أدخل الرقم الذي وصلت إليه الدعوة.');
      return;
    }

    final result = await context.read<AuthController>().requestOtp(
      phone: phone,
      purpose: _otpPurpose,
    );
    if (!mounted || result == null) return;
    setState(() {
      _step = _InviteAccessStep.otp;
      _devOtpMessage = result.localDevMessage;
    });
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != _otpLength) {
      _showError('رمز التحقق غير صحيح.');
      return;
    }

    final auth = context.read<AuthController>();
    final success = await auth.verifyOtp(
      phone: _phoneController.text.trim(),
      purpose: _otpPurpose,
      code: code,
    );
    if (!mounted || !success) return;
    if (auth.status != AuthStatus.authenticated) {
      context.read<SharingProvider>().clearInviteAccessState();
      setState(() {
        _step = _InviteAccessStep.invites;
        _openedInvite = null;
      });
      return;
    }
    await _loadVerifiedInvites();
  }

  Future<void> _loadVerifiedInvites() async {
    final provider = context.read<SharingProvider>();
    await provider.loadMyInvites(token: _token);
    if (!mounted) return;
    setState(() {
      _step = _InviteAccessStep.invites;
      _openedInvite = provider.selectedInvite;
    });
  }

  Future<void> _respond(PlanInvite invite, {required bool accept}) async {
    final provider = context.read<SharingProvider>();
    final ok = await provider.respondToInvite(invite.token, accept: accept);
    if (!mounted || !ok) return;
    final updated = provider.selectedInvite ?? invite;
    if (accept) {
      context.go(
        AppRouter.planCenter(updated.weddingPlanId),
        extra: provider.acceptedInviteMember,
      );
      return;
    }
    setState(() => _openedInvite = updated);
  }

  Future<void> _openAcceptedPlan(PlanInvite invite) async {
    final provider = context.read<SharingProvider>();
    await provider.loadSharedPlans();
    if (!mounted) return;

    SharedMember? member;
    for (final plan in provider.sharedPlans) {
      if (plan.id == invite.weddingPlanId) {
        member = plan.sharedMember;
        break;
      }
    }

    context.go(AppRouter.planCenter(invite.weddingPlanId), extra: member);
  }

  void _showError(String message) => AarastToast.showError(context, message);

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (_step) {
      _InviteAccessStep.phone => 'أدخل الرقم الذي وصلت إليه الدعوة.',
      _InviteAccessStep.otp => 'أدخل رمز التحقق قبل عرض الدعوات.',
      _InviteAccessStep.invites => 'اختر الدعوة ثم ادخل للخطة بصلاحياتك.',
    };

    return AarastPageScaffold(
      title: 'وصلتني دعوة لخطة',
      subtitle: subtitle,
      showBack: true,
      onBack: _handleBack,
      resizeToAvoidBottomInset: true,
      child: switch (_step) {
        _InviteAccessStep.phone => _PhoneStep(
          controller: _phoneController,
          onSubmit: _requestOtp,
        ),
        _InviteAccessStep.otp => _OtpStep(
          controller: _otpController,
          devOtpMessage: _devOtpMessage,
          onVerify: _verifyOtp,
          onResend: _requestOtp,
          onChangePhone: () => setState(() {
            _otpController.clear();
            _step = _InviteAccessStep.phone;
          }),
        ),
        _InviteAccessStep.invites => _InvitesStep(
          openedInvite: _openedInvite,
          onOpenInvite: (invite) => setState(() => _openedInvite = invite),
          onCloseInvite: () => setState(() => _openedInvite = null),
          onAccept: (invite) => _respond(invite, accept: true),
          onDecline: (invite) => _respond(invite, accept: false),
          onOpenAcceptedPlan: _openAcceptedPlan,
          onChangePhone: () => setState(() {
            _openedInvite = null;
            _otpController.clear();
            _step = _InviteAccessStep.phone;
          }),
          onRetry: _loadVerifiedInvites,
        ),
      },
    );
  }

  void _handleBack() {
    if (_step == _InviteAccessStep.otp) {
      setState(() => _step = _InviteAccessStep.phone);
      return;
    }
    if (_step == _InviteAccessStep.invites && _openedInvite != null) {
      setState(() => _openedInvite = null);
      return;
    }
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(AppRouter.welcome);
  }
}

class _PhoneStep extends StatelessWidget {
  const _PhoneStep({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return ListView(
      children: [
        const _InviteNotice(
          icon: LucideIcons.shieldCheck,
          title: 'الخصوصية أولاً',
          message:
              'لن تظهر تفاصيل الخطة قبل التحقق من رقم الهاتف المرتبط بالدعوة.',
        ),
        const SizedBox(height: 16),
        AarastCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _FieldLabel('رقم الهاتف'),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  key: const Key('invite-phone-field'),
                  controller: controller,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    hintText: '777 123 456',
                    prefixIcon: Icon(LucideIcons.smartphone),
                  ),
                  onSubmitted: (_) => onSubmit(),
                ),
              ),
              if (auth.errorMessage != null) ...[
                const SizedBox(height: 12),
                _InlineError(auth.errorMessage!),
              ],
              const SizedBox(height: 18),
              AarastButton(
                key: const Key('invite-request-otp-button'),
                label: 'إرسال رمز التحقق',
                icon: LucideIcons.messageSquare,
                isLoading: auth.isSubmitting,
                onPressed: auth.isSubmitting ? null : onSubmit,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OtpStep extends StatelessWidget {
  const _OtpStep({
    required this.controller,
    required this.onVerify,
    required this.onResend,
    required this.onChangePhone,
    this.devOtpMessage,
  });

  final TextEditingController controller;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onChangePhone;
  final String? devOtpMessage;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    return ListView(
      children: [
        if (devOtpMessage != null) ...[
          _InviteNotice(
            icon: LucideIcons.code2,
            title: 'رمز التحقق للتجربة',
            message: devOtpMessage!,
          ),
          const SizedBox(height: 16),
        ],
        AarastCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _FieldLabel('رمز التحقق'),
              Directionality(
                textDirection: TextDirection.ltr,
                child: TextField(
                  key: const Key('invite-otp-field'),
                  controller: controller,
                  maxLength: 6,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppTheme.burgundy,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    hintText: '000000',
                    prefixIcon: Icon(LucideIcons.shieldCheck),
                  ),
                  onSubmitted: (_) => onVerify(),
                ),
              ),
              if (auth.errorMessage != null) ...[
                const SizedBox(height: 12),
                const _InlineError('رمز التحقق غير صحيح.'),
              ],
              const SizedBox(height: 18),
              AarastButton(
                key: const Key('invite-verify-otp-button'),
                label: 'تأكيد الرمز',
                icon: LucideIcons.checkCircle2,
                isLoading: auth.isSubmitting,
                onPressed: auth.isSubmitting ? null : onVerify,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: AarastButton(
                      label: 'إعادة إرسال الرمز',
                      variant: AarastButtonVariant.secondary,
                      onPressed: auth.isSubmitting ? null : onResend,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: AarastButton(
                      label: 'تغيير الرقم',
                      variant: AarastButtonVariant.ghost,
                      onPressed: auth.isSubmitting ? null : onChangePhone,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InvitesStep extends StatelessWidget {
  const _InvitesStep({
    required this.openedInvite,
    required this.onOpenInvite,
    required this.onCloseInvite,
    required this.onAccept,
    required this.onDecline,
    required this.onOpenAcceptedPlan,
    required this.onChangePhone,
    required this.onRetry,
  });

  final PlanInvite? openedInvite;
  final ValueChanged<PlanInvite> onOpenInvite;
  final VoidCallback onCloseInvite;
  final ValueChanged<PlanInvite> onAccept;
  final ValueChanged<PlanInvite> onDecline;
  final ValueChanged<PlanInvite> onOpenAcceptedPlan;
  final VoidCallback onChangePhone;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SharingProvider>();
    if (provider.isLoading) {
      return AarastSkeleton.list(rows: 3, rowHeight: 120, withHeader: false);
    }

    if (openedInvite != null) {
      return _InviteDetails(
        invite: openedInvite!,
        isSubmitting: provider.isSubmitting,
        errorMessage: provider.errorMessage,
        onAccept: () => onAccept(openedInvite!),
        onDecline: () => onDecline(openedInvite!),
        onOpenAcceptedPlan: () => onOpenAcceptedPlan(openedInvite!),
        onBack: onCloseInvite,
      );
    }

    final invites = provider.myInvites;
    if (invites.isEmpty) {
      return _NoInviteState(
        message:
            provider.errorMessage ??
            'لا توجد دعوة مرتبطة بهذا الرقم. تأكد من الرقم أو اطلب من صاحب الخطة إرسال دعوة جديدة.',
        onChangePhone: onChangePhone,
        onRetry: onRetry,
      );
    }

    return ListView.separated(
      itemCount: invites.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final invite = invites[index];
        return _InviteListCard(
          invite: invite,
          onTap: () {
            if (invite.isAccepted) {
              onOpenAcceptedPlan(invite);
              return;
            }
            onOpenInvite(invite);
          },
        );
      },
    );
  }
}

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
        AarastCard(
          color: AppTheme.ivory,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                invite.weddingPlanTitle ?? 'خطة زفاف مشتركة',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              _MetaLine(
                icon: LucideIcons.user,
                text: 'صاحب الخطة: ${invite.inviterName ?? 'غير محدد'}',
              ),
              _MetaLine(
                icon: LucideIcons.badge,
                text: 'دورك: ${sharedMemberRoleLabel(invite.role)}',
              ),
              const SizedBox(height: 14),
              const _FieldLabel('الصلاحيات المتاحة'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final label in invite.permissionLabels)
                    _PermissionChip(label),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'الميزانية والمستحقات والدفعات مخفية ما لم يمنحك صاحب الخطة صلاحية مالية واضحة.',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w700,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        if (errorMessage != null) ...[
          const SizedBox(height: 12),
          _InlineError(errorMessage!),
        ],
        const SizedBox(height: 16),
        if (invite.isPending)
          Row(
            children: [
              Expanded(
                child: AarastButton(
                  label: 'رفض الدعوة',
                  variant: AarastButtonVariant.secondary,
                  isLoading: isSubmitting,
                  onPressed: isSubmitting ? null : onDecline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AarastButton(
                  key: const Key('invite-accept-button'),
                  label: 'قبول الدعوة',
                  icon: LucideIcons.logIn,
                  isLoading: isSubmitting,
                  onPressed: isSubmitting ? null : onAccept,
                ),
              ),
            ],
          )
        else if (invite.isAccepted)
          AarastButton(
            label: 'فتح الخطة',
            icon: LucideIcons.layoutDashboard,
            isLoading: isSubmitting,
            onPressed: isSubmitting ? null : onOpenAcceptedPlan,
          )
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
                  color: AppTheme.goldSoft,
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
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${sharedMemberRoleLabel(invite.role)} • ${_statusLabel(invite.status)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.arrowRight, color: AppTheme.muted),
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
      color: AppTheme.goldSoft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.burgundy),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.muted,
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

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.muted),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppTheme.muted,
                fontWeight: FontWeight.w700,
              ),
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
          color: AppTheme.ink,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PermissionChip extends StatelessWidget {
  const _PermissionChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.ink,
          fontWeight: FontWeight.w800,
          fontSize: 12,
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
    'DECLINED' => 'مرفوضة',
    'EXPIRED' => 'منتهية',
    'CANCELLED' => 'ملغاة',
    _ => status,
  };
}

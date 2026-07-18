import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_otp_field.dart';
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
  static const _resendCooldown = 60;

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  _InviteAccessStep _step = _InviteAccessStep.phone;
  AarastOtpFieldState _otpFieldState = AarastOtpFieldState.idle;
  bool _isVerifying = false;
  String? _otpNoticeMessage;
  PlanInvite? _openedInvite;
  Timer? _resendTimer;
  int _resendSeconds = 0;

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
      // A private link may be opened on a phone that is still signed in as
      // the inviter (or another family member).  Never resolve that token
      // against the stale session: the invitee must prove the phone that the
      // link was issued to first.  The OTP verification will then replace the
      // application session with the verified invitee account.
      final token = _token;
      final resumesVerifiedLink =
          token != null &&
          auth.status == AuthStatus.authenticated &&
          auth.consumePendingInviteResume(token);
      if (resumesVerifiedLink ||
          (token == null && auth.status == AuthStatus.authenticated)) {
        _loadVerifiedInvites();
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final auth = context.read<AuthController>();
    if (auth.isSubmitting) return;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      _showError('أدخل الرقم الذي وصلت إليه الدعوة.');
      return;
    }

    final token = _token;
    final result = token == null
        ? await auth.requestOtp(phone: phone, purpose: _otpPurpose)
        : await auth.requestInviteOtp(token: token, phone: phone);
    if (!mounted || result == null) return;
    _otpController.clear();
    setState(() {
      _step = _InviteAccessStep.otp;
      _otpFieldState = AarastOtpFieldState.idle;
      _otpNoticeMessage = result.noticeMessage;
    });
    _startResendCooldown();
  }

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0) return;
    await _requestOtp();
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != _otpLength) {
      setState(() => _otpFieldState = AarastOtpFieldState.error);
      _showError('رمز التحقق غير صحيح.');
      return;
    }
    if (_isVerifying) return;

    final auth = context.read<AuthController>();
    final previousUserId = auth.user?.id;
    final token = _token;
    setState(() => _isVerifying = true);
    final success = await auth.verifyOtp(
      phone: _phoneController.text.trim(),
      purpose: _otpPurpose,
      code: code,
      resumeInviteToken: token,
    );
    if (!mounted) return;
    if (!success) {
      setState(() {
        _isVerifying = false;
        _otpFieldState = AarastOtpFieldState.error;
      });
      return;
    }
    _resendTimer?.cancel();
    if (token != null && previousUserId != auth.user?.id) {
      // The account boundary is about to dispose this State. The in-memory
      // resume token is claimed by the newly mounted router, which continues
      // the verified invite without exposing it to the previous account.
      return;
    }
    if (token != null) auth.consumePendingInviteResume(token);
    setState(() => _otpFieldState = AarastOtpFieldState.success);
    await Future<void>.delayed(AarastOtpField.successHold(context));
    if (!mounted) return;
    if (auth.status != AuthStatus.authenticated) {
      context.read<SharingProvider>().clearInviteAccessState();
      setState(() {
        _isVerifying = false;
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
    final linkedInvite = _token == null ? null : provider.selectedInvite;
    if (linkedInvite != null &&
        await _enterLinkedInvite(provider, linkedInvite)) {
      return;
    }
    setState(() {
      _isVerifying = false;
      _step = _InviteAccessStep.invites;
      _openedInvite = provider.selectedInvite;
    });
  }

  Future<bool> _enterLinkedInvite(
    SharingProvider provider,
    PlanInvite invite,
  ) async {
    var resolvedInvite = invite;
    SharedMember? member;
    if (invite.isPending) {
      final accepted = await provider.respondToInvite(
        invite.token,
        accept: true,
      );
      if (!mounted || !accepted) return false;
      resolvedInvite = provider.selectedInvite ?? invite;
      member = provider.acceptedInviteMember;
    } else if (invite.isAccepted) {
      await provider.loadSharedPlans();
      if (!mounted) return false;
      for (final plan in provider.sharedPlans) {
        if (plan.id == invite.weddingPlanId) {
          member = plan.sharedMember;
          break;
        }
      }
    } else {
      return false;
    }

    if (!resolvedInvite.isAccepted) return false;
    context.go(
      AppRouter.planCenter(resolvedInvite.weddingPlanId),
      extra: member,
    );
    return true;
  }

  void _onOtpChanged(String value) {
    if (value.isEmpty) return;
    if (_otpFieldState == AarastOtpFieldState.error) {
      setState(() => _otpFieldState = AarastOtpFieldState.idle);
    }
    final auth = context.read<AuthController>();
    if (auth.errorMessage != null) auth.clearError();
  }

  void _returnToPhone() {
    _resendTimer?.cancel();
    final auth = context.read<AuthController>();
    if (auth.errorMessage != null) auth.clearError();
    _otpController.clear();
    setState(() {
      _openedInvite = null;
      _otpFieldState = AarastOtpFieldState.idle;
      _isVerifying = false;
      _resendSeconds = 0;
      _step = _InviteAccessStep.phone;
    });
  }

  void _openRegistration() {
    final auth = context.read<AuthController>();
    final phone = _phoneController.text.trim();
    final token = _token;
    final resumeLocation = token == null
        ? AppRouter.inviteAccess
        : AppRouter.inviteDecision(token);
    auth.clearError();
    context.go(
      Uri.parse(AppRouter.register)
          .replace(
            queryParameters: {
              if (phone.isNotEmpty) 'phone': phone,
              'resume': resumeLocation,
            },
          )
          .toString(),
    );
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    if (!mounted) return;
    setState(() => _resendSeconds = _resendCooldown);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
        return;
      }
      setState(() => _resendSeconds -= 1);
    });
  }

  Future<void> _respond(PlanInvite invite, {required bool accept}) async {
    final provider = context.read<SharingProvider>();
    final ok = await provider.respondToInvite(invite.token, accept: accept);
    if (!mounted || !ok) return;
    final updated = provider.selectedInvite ?? invite;
    setState(() => _openedInvite = updated);
  }

  Future<void> _confirmDecline(PlanInvite invite) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AarastDialog(
        icon: const Icon(
          LucideIcons.alertCircle,
          color: AppTheme.warning,
          size: 30,
        ),
        title: const Text('تأكيد رفض الدعوة'),
        content: const Text(
          'لن تنضم إلى هذه الخطة، ويمكن لصاحبها إرسال دعوة جديدة لك لاحقًا.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('العودة للدعوة'),
          ),
          TextButton(
            key: const Key('invite-confirm-decline-button'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.danger),
            child: const Text('نعم، رفض الدعوة'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _respond(invite, accept: false);
    }
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
      child: Column(
        children: [
          _InviteJourneyProgress(step: _step),
          const SizedBox(height: AppTheme.gapLg),
          Expanded(
            child: switch (_step) {
              _InviteAccessStep.phone => _PhoneStep(
                controller: _phoneController,
                onSubmit: _requestOtp,
              ),
              _InviteAccessStep.otp => _OtpStep(
                controller: _otpController,
                phone: _phoneController.text.trim(),
                state: _otpFieldState,
                resendSeconds: _resendSeconds,
                otpNoticeMessage: _otpNoticeMessage,
                onCodeChanged: _onOtpChanged,
                onVerify: _verifyOtp,
                onResend: _resendOtp,
                onChangePhone: _returnToPhone,
                onCreateAppAccount: _openRegistration,
                autoJoin: _token != null,
              ),
              _InviteAccessStep.invites => _InvitesStep(
                openedInvite: _openedInvite,
                onOpenInvite: (invite) =>
                    setState(() => _openedInvite = invite),
                onCloseInvite: () => setState(() => _openedInvite = null),
                onAccept: (invite) => _respond(invite, accept: true),
                onDecline: _confirmDecline,
                onOpenAcceptedPlan: _openAcceptedPlan,
                onChangePhone: _returnToPhone,
                onRetry: _loadVerifiedInvites,
              ),
            },
          ),
        ],
      ),
    );
  }

  void _handleBack() {
    if (_step == _InviteAccessStep.otp) {
      _returnToPhone();
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
        const _InviteWelcomeHero(
          icon: LucideIcons.mailCheck,
          eyebrow: 'دعوة خاصة لك',
          title: 'انضم إلى خطة تمت دعوتك إليها',
          message:
              'تحقق من رقمك لعرض الخطة ودورك والصلاحيات الممنوحة لك بأمان.',
        ),
        const SizedBox(height: 14),
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
              const SizedBox(height: 12),
              const _PrivacyLine(),
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

class _InviteJourneyProgress extends StatelessWidget {
  const _InviteJourneyProgress({required this.step});

  final _InviteAccessStep step;

  @override
  Widget build(BuildContext context) {
    final activeIndex = switch (step) {
      _InviteAccessStep.phone => 0,
      _InviteAccessStep.otp => 1,
      _InviteAccessStep.invites => 2,
    };
    const labels = ['رقم الهاتف', 'التحقق', 'الدعوة'];

    return Semantics(
      label: 'المرحلة ${activeIndex + 1} من 3: ${labels[activeIndex]}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusPill),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            for (var index = 0; index < labels.length; index++) ...[
              if (index > 0)
                Expanded(
                  child: Container(
                    height: 1,
                    color: index <= activeIndex
                        ? AppTheme.gold
                        : AppTheme.border,
                  ),
                ),
              _InviteJourneyMarker(
                label: labels[index],
                index: index,
                activeIndex: activeIndex,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InviteJourneyMarker extends StatelessWidget {
  const _InviteJourneyMarker({
    required this.label,
    required this.index,
    required this.activeIndex,
  });

  final String label;
  final int index;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final isActive = index == activeIndex;
    final isComplete = index < activeIndex;
    final color = isActive || isComplete ? AppTheme.burgundy : AppTheme.muted;

    return SizedBox(
      width: 58,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: AppTheme.motionFast,
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isActive
                  ? AppTheme.burgundy
                  : isComplete
                  ? AppTheme.goldSoft
                  : AppTheme.ivory,
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive || isComplete ? AppTheme.gold : AppTheme.border,
              ),
            ),
            child: isComplete
                ? const Icon(
                    LucideIcons.check,
                    size: 15,
                    color: AppTheme.burgundy,
                  )
                : Text(
                    '${index + 1}',
                    style: TextStyle(
                      color: isActive ? Colors.white : color,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InviteWelcomeHero extends StatelessWidget {
  const _InviteWelcomeHero({
    required this.icon,
    required this.eyebrow,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String eyebrow;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.gapLg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppTheme.surfaceElevated, AppTheme.goldSoft],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.36)),
        boxShadow: AppTheme.softShadow(opacity: 0.04),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.gold),
            ),
            child: Icon(icon, color: AppTheme.burgundy, size: 25),
          ),
          const SizedBox(height: 10),
          Text(
            eyebrow,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppTheme.goldDeep,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.title,
              fontWeight: FontWeight.w900,
              fontFamily: AppTheme.displayFontFamily,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.muted,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine();

  @override
  Widget build(BuildContext context) {
    return const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.shieldCheck, size: 18, color: AppTheme.success),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'لن نعرض تفاصيل الخطة قبل مطابقة الرقم بالدعوة.',
            style: TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _OtpStep extends StatelessWidget {
  const _OtpStep({
    required this.controller,
    required this.phone,
    required this.state,
    required this.resendSeconds,
    required this.onCodeChanged,
    required this.onVerify,
    required this.onResend,
    required this.onChangePhone,
    required this.onCreateAppAccount,
    required this.autoJoin,
    this.otpNoticeMessage,
  });

  final TextEditingController controller;
  final String phone;
  final AarastOtpFieldState state;
  final int resendSeconds;
  final ValueChanged<String> onCodeChanged;
  final VoidCallback onVerify;
  final VoidCallback onResend;
  final VoidCallback onChangePhone;
  final VoidCallback onCreateAppAccount;
  final bool autoJoin;
  final String? otpNoticeMessage;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final missingAppAccount =
        auth.errorCode == 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF';
    return ListView(
      children: [
        _InviteWelcomeHero(
          icon: LucideIcons.messageCircle,
          eyebrow: 'التحقق من الهوية',
          title: 'أدخل رمز التحقق',
          message:
              'أرسلنا الرمز إلى '
              '${PhoneNumberUtils.isolateLtr(_maskedPhone(phone))}',
        ),
        const SizedBox(height: 14),
        if (otpNoticeMessage != null) ...[
          _InviteNotice(
            icon: LucideIcons.code2,
            title: 'حالة إرسال الرمز',
            message: otpNoticeMessage!,
          ),
          const SizedBox(height: 16),
        ],
        AarastCard(
          // عند نجاح الرمز تتحوّل البطاقة كاملة إلى لوحة ✓ الخضراء.
          child: AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 280),
            child: state == AarastOtpFieldState.success
                ? const AarastOtpSuccessPanel(
                    subtitle: 'تم توثيق رقمك — جارٍ فتح مساحة المساهمة.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _FieldLabel('رمز التحقق'),
                      AarastOtpField(
                        controller: controller,
                        state: state,
                        enabled: !auth.isSubmitting,
                        fieldKey: const Key('invite-otp-field'),
                        onChanged: onCodeChanged,
                        onCompleted: (_) => onVerify(),
                      ),
                      if (auth.errorMessage != null) ...[
                        const SizedBox(height: 12),
                        _InlineError(auth.errorMessage!),
                      ],
                      const SizedBox(height: 18),
                      if (missingAppAccount)
                        AarastButton(
                          key: const ValueKey('invite-create-app-account'),
                          label: 'إنشاء حساب التطبيق والمتابعة',
                          icon: LucideIcons.userPlus,
                          onPressed: phone.isEmpty ? null : onCreateAppAccount,
                        )
                      else
                        AarastButton(
                          key: const Key('invite-verify-otp-button'),
                          label: autoJoin
                              ? 'تأكيد الرمز والانضمام'
                              : 'تأكيد الرمز',
                          icon: LucideIcons.checkCircle2,
                          isLoading: auth.isSubmitting,
                          onPressed: auth.isSubmitting ? null : onVerify,
                        ),
                      const SizedBox(height: 10),
                      if (missingAppAccount)
                        AarastButton(
                          label: 'تغيير الرقم',
                          variant: AarastButtonVariant.ghost,
                          onPressed: auth.isSubmitting ? null : onChangePhone,
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: AarastButton(
                                key: const ValueKey('invite-otp-resend-button'),
                                label: resendSeconds > 0
                                    ? 'إعادة الإرسال خلال $resendSeconds ث'
                                    : 'إعادة إرسال الرمز',
                                variant: AarastButtonVariant.secondary,
                                onPressed:
                                    auth.isSubmitting || resendSeconds > 0
                                    ? null
                                    : onResend,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AarastButton(
                                label: 'تغيير الرقم',
                                variant: AarastButtonVariant.ghost,
                                onPressed: auth.isSubmitting
                                    ? null
                                    : onChangePhone,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
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
        if (invite.isAccepted)
          _InviteJoinedHero(invite: invite)
        else
          _InvitePlanHero(invite: invite),
        const SizedBox(height: 14),
        _InvitePermissionsCard(invite: invite),
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
        ] else if (invite.isAccepted)
          AarastButton(
            key: const Key('invite-open-plan-button'),
            label: 'الدخول إلى الخطة',
            icon: LucideIcons.arrowLeft,
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

class _InvitePlanHero extends StatelessWidget {
  const _InvitePlanHero({required this.invite});

  final PlanInvite invite;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.gapXl),
      decoration: BoxDecoration(
        gradient: AppTheme.heroGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.72)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.burgundyDark.withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        children: [
          const _WeddingRingsMark(),
          const SizedBox(height: 12),
          Text(
            'أنت مدعو للمساهمة في',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.goldLight,
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
                  color: AppTheme.goldLight,
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
                    color: AppTheme.goldLight,
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
        gradient: const LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [AppTheme.surfaceElevated, AppTheme.successSoft],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusXl),
        border: Border.all(color: AppTheme.success.withValues(alpha: 0.34)),
      ),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: AppTheme.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.gold, width: 2),
              boxShadow: AppTheme.softShadow(opacity: 0.08),
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
              color: AppTheme.title,
              fontWeight: FontWeight.w900,
              fontFamily: AppTheme.displayFontFamily,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'أصبحت ${sharedMemberRoleLabel(invite.role)} في ${invite.weddingPlanTitle ?? 'الخطة المشتركة'}.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.muted,
              height: 1.45,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
                  color: AppTheme.goldSoft,
                  borderRadius: BorderRadius.circular(AppTheme.radiusSm),
                ),
                child: const Icon(
                  LucideIcons.shieldCheck,
                  color: AppTheme.burgundy,
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
                        color: AppTheme.ink,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const Text(
                      'راجع ما ستتمكن من الوصول إليه قبل الانضمام.',
                      style: TextStyle(
                        color: AppTheme.muted,
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
                  : AppTheme.ivory,
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
                      : AppTheme.muted,
                  size: 19,
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    financeMessage,
                    style: TextStyle(
                      color: invite.canViewMoney
                          ? AppTheme.success
                          : AppTheme.muted,
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
                border: Border.all(color: AppTheme.goldLight, width: 2),
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
                border: Border.all(color: AppTheme.gold, width: 2),
              ),
            ),
          ),
          const Positioned(
            top: 0,
            child: Icon(LucideIcons.heart, color: AppTheme.goldLight, size: 13),
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
        color: AppTheme.ivory,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.burgundy, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.ink,
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
    'الخدمات والموردون' => LucideIcons.store,
    'دعوة أعضاء' => LucideIcons.userPlus,
    'إدارة المال' || 'مشاهدة المال' => LucideIcons.walletCards,
    _ => LucideIcons.eye,
  };
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

String _maskedPhone(String phone) {
  final compact = phone.replaceAll(RegExp(r'\s+'), '');
  if (compact.length <= 4) return compact;
  return '••• ${compact.substring(compact.length - 4)}';
}

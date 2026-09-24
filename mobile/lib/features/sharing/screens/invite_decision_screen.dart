import 'dart:async';
import 'dart:convert';

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
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;
import '../../auth/auth_api.dart'
    show AuthController, AuthObscureToggle, AuthStatus, AuthTextField;
import '../models/shared_member.dart';
import '../providers/sharing_provider.dart';

part 'invite_decision_screen.steps.dart';
part 'invite_decision_screen.details.dart';
part 'invite_decision_screen.notices.dart';

enum _InviteAccessStep { phone, accountSetup, otp, invites }

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
  final _accountNameController = TextEditingController();
  final _accountPasswordController = TextEditingController();
  final _accountPasswordConfirmationController = TextEditingController();

  _InviteAccessStep _step = _InviteAccessStep.phone;
  AarastOtpFieldState _otpFieldState = AarastOtpFieldState.idle;
  bool _isVerifying = false;
  String? _otpNoticeMessage;
  bool _otpDeliveryConfirmed = false;
  bool _accountSetupRequired = false;
  bool _obscureAccountPassword = true;
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
    _accountNameController.dispose();
    _accountPasswordController.dispose();
    _accountPasswordConfirmationController.dispose();
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
      _step = result.accountSetupRequired
          ? _InviteAccessStep.accountSetup
          : _InviteAccessStep.otp;
      _otpFieldState = AarastOtpFieldState.idle;
      _otpNoticeMessage = result.noticeMessage;
      _otpDeliveryConfirmed = result.isDeliveryConfirmed;
      _accountSetupRequired = token != null && result.accountSetupRequired;
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
    final accountName = _accountNameController.text.trim();
    final accountPassword = _accountPasswordController.text;
    final accountPasswordConfirmation =
        _accountPasswordConfirmationController.text;
    if (_accountSetupRequired) {
      if (accountName.isEmpty) {
        _showError('أدخل اسم المساهم لإنشاء الحساب.');
        return;
      }
      if (accountPassword.length < 6) {
        _showError('كلمة المرور يجب أن تكون 6 أحرف على الأقل.');
        return;
      }
      if (utf8.encode(accountPassword).length > 72) {
        _showError('كلمة المرور طويلة جدًا. استخدم 72 بايت كحد أقصى.');
        return;
      }
      if (accountPassword != accountPasswordConfirmation) {
        _showError('تأكيد كلمة المرور غير مطابق.');
        return;
      }
    }
    setState(() => _isVerifying = true);
    final success = await auth.verifyOtp(
      phone: _phoneController.text.trim(),
      purpose: _otpPurpose,
      code: code,
      resumeInviteToken: token,
      accountName: _accountSetupRequired ? accountName : null,
      accountPassword: _accountSetupRequired ? accountPassword : null,
    );
    if (!mounted) return;
    if (!success) {
      setState(() {
        _isVerifying = false;
        _otpFieldState = AarastOtpFieldState.error;
        if (auth.errorCode == 'INVITE_ACCOUNT_SETUP_REQUIRED') {
          _accountSetupRequired = true;
          _step = _InviteAccessStep.accountSetup;
        }
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
    setState(() {
      _isVerifying = false;
      _step = _InviteAccessStep.invites;
      _openedInvite = linkedInvite ?? provider.selectedInvite;
    });
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
    _accountNameController.clear();
    _accountPasswordController.clear();
    _accountPasswordConfirmationController.clear();
    setState(() {
      _openedInvite = null;
      _otpFieldState = AarastOtpFieldState.idle;
      _isVerifying = false;
      _resendSeconds = 0;
      _otpNoticeMessage = null;
      _otpDeliveryConfirmed = false;
      _accountSetupRequired = false;
      _obscureAccountPassword = true;
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
    if (invite.hasEndedMembership) {
      _showError('هذه الدعوة مقبولة سابقًا، لكن عضويتك في الخطة لم تعد فعالة.');
      return;
    }
    final inviteProvider = context.read<SharingProvider>();
    final accountContexts = context.read<AccountContextController>();
    var member = inviteProvider.acceptedInviteMember;
    if (member?.weddingPlanId != invite.weddingPlanId) {
      member = null;
    }

    final expectedContextKey = 'plan:${invite.weddingPlanId}:contributor';
    final inviteContextKey = invite.contextKey;
    final acceptedContextKey = inviteProvider.acceptedInviteContextKey;
    final contextKey = inviteContextKey == expectedContextKey
        ? inviteContextKey
        : acceptedContextKey == expectedContextKey
        ? acceptedContextKey
        : null;
    if (contextKey == null) {
      _showError('تعذر العثور على مسار المساهم لهذه الخطة.');
      return;
    }

    final selected = await accountContexts.select(contextKey);
    if (!mounted) return;
    if (!selected ||
        accountContexts.selectedContext?.contextKey != contextKey) {
      _showError(accountContexts.errorMessage ?? 'تعذر تفعيل مسار المساهم.');
      return;
    }

    final scopedProvider = context.read<SharingProvider>();
    await scopedProvider.loadSharedPlans();
    if (!mounted) return;

    if (member == null) {
      for (final plan in scopedProvider.sharedPlans) {
        if (plan.id == invite.weddingPlanId) {
          member = plan.sharedMember;
          break;
        }
      }
    }

    context.go(AppRouter.planCenter(invite.weddingPlanId), extra: member);
  }

  void _showError(String message) => AarastToast.showError(context, message);

  @override
  Widget build(BuildContext context) {
    final subtitle = switch (_step) {
      _InviteAccessStep.phone => 'أدخل الرقم الذي وصلت إليه الدعوة.',
      _InviteAccessStep.accountSetup =>
        'أنشئ كلمة سر دائمة قبل تأكيد رمز الدعوة.',
      _InviteAccessStep.otp => 'أدخل رمز التحقق قبل عرض الدعوات.',
      _InviteAccessStep.invites => 'راجع الدعوة ثم اختر قبولها أو رفضها.',
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
              _InviteAccessStep.accountSetup => _AccountSetupStep(
                nameController: _accountNameController,
                passwordController: _accountPasswordController,
                passwordConfirmationController:
                    _accountPasswordConfirmationController,
                obscurePassword: _obscureAccountPassword,
                onTogglePassword: () => setState(
                  () => _obscureAccountPassword = !_obscureAccountPassword,
                ),
                onContinue: _continueAccountSetup,
                onChangePhone: _returnToPhone,
              ),
              _InviteAccessStep.otp => _OtpStep(
                controller: _otpController,
                phone: _phoneController.text.trim(),
                state: _otpFieldState,
                resendSeconds: _resendSeconds,
                otpNoticeMessage: _otpNoticeMessage,
                deliveryConfirmed: _otpDeliveryConfirmed,
                onCodeChanged: _onOtpChanged,
                onVerify: _verifyOtp,
                onResend: _resendOtp,
                onChangePhone: _returnToPhone,
                onCreateAppAccount: _openRegistration,
                reviewInviteAfterVerification: _token != null,
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
    if (_step == _InviteAccessStep.accountSetup) {
      _returnToPhone();
      return;
    }
    if (_step == _InviteAccessStep.otp) {
      if (_accountSetupRequired) {
        setState(() => _step = _InviteAccessStep.accountSetup);
      } else {
        _returnToPhone();
      }
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

  void _continueAccountSetup() {
    final name = _accountNameController.text.trim();
    final password = _accountPasswordController.text;
    final confirmation = _accountPasswordConfirmationController.text;
    if (name.isEmpty) {
      _showError('أدخل اسم المساهم لإنشاء الحساب.');
      return;
    }
    if (password.length < 6) {
      _showError('كلمة المرور يجب أن تكون 6 أحرف على الأقل.');
      return;
    }
    if (utf8.encode(password).length > 72) {
      _showError('كلمة المرور طويلة جدًا. استخدم 72 بايت كحد أقصى.');
      return;
    }
    if (password != confirmation) {
      _showError('تأكيد كلمة المرور غير مطابق.');
      return;
    }
    setState(() => _step = _InviteAccessStep.otp);
  }
}

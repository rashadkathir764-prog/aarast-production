import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/widgets/aarast_otp_field.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../account_contexts/account_contexts_api.dart'
    show AccountContextController;
import '../../auth/auth_api.dart' show AuthController, AuthStatus;
import '../models/participant_access.dart';
import '../models/shared_member.dart';
import '../providers/sharing_provider.dart';

part 'invite_decision_screen.cards.dart';

enum _InviteStep { phone, account, code, invite }

/// q01 to q03: an invite link opens on the phone it was sent to. The number
/// is proven with a code first (q01), a new person makes an account on the
/// way (q02), and only then the invite shows who asks, the role and what
/// each section allows (q03). Joining or refusing is always an explicit
/// press; nothing about the plan shows before the code.
class InviteDecisionScreen extends StatefulWidget {
  const InviteDecisionScreen({required this.token, super.key});

  final String token;

  @override
  State<InviteDecisionScreen> createState() => _InviteDecisionScreenState();
}

class _InviteDecisionScreenState extends State<InviteDecisionScreen> {
  static const _otpLength = 6;
  static const _otpPurpose = 'LOGIN';
  static const _resendCooldown = 60;

  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();

  _InviteStep _step = _InviteStep.phone;
  AarastOtpFieldState _otpFieldState = AarastOtpFieldState.idle;
  bool _isVerifying = false;
  bool _accountSetupRequired = false;
  bool _openingPlan = false;
  String? _otpNoticeMessage;
  bool _otpDeliveryConfirmed = false;
  String? _nameError;
  String? _passwordError;
  String? _confirmationError;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  String get _token => widget.token.trim();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final auth = context.read<AuthController>();
      // A private link may be opened on a phone that is still signed in as
      // the inviter or someone else. The invite is never read with that
      // session: the phone it was sent to is proven first, and the verified
      // account then resumes here through the account boundary.
      if (auth.status == AuthStatus.authenticated &&
          auth.consumePendingInviteResume(_token)) {
        _loadInvite();
      }
    });
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final auth = context.read<AuthController>();
    if (auth.isSubmitting) return;
    if (_phoneController.text.trim().isEmpty) {
      AarastToast.showError(context, 'اكتب الرقم اللي وصلتك عليه الدعوة.');
      return;
    }
    final result = await auth.requestInviteOtp(
      token: _token,
      phone: _phoneController.text.trim(),
    );
    if (!mounted || result == null) return;
    _otpController.clear();
    setState(() {
      _accountSetupRequired = result.accountSetupRequired;
      _step = result.accountSetupRequired
          ? _InviteStep.account
          : _InviteStep.code;
      _otpFieldState = AarastOtpFieldState.idle;
      _otpNoticeMessage = result.noticeMessage;
      _otpDeliveryConfirmed = result.isDeliveryConfirmed;
    });
    _startResendCooldown();
  }

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0) return;
    final auth = context.read<AuthController>();
    final result = await auth.requestInviteOtp(
      token: _token,
      phone: _phoneController.text.trim(),
    );
    if (!mounted || result == null) return;
    setState(() {
      _otpNoticeMessage = result.noticeMessage;
      _otpDeliveryConfirmed = result.isDeliveryConfirmed;
    });
    _startResendCooldown();
  }

  /// q02: the account's name and password are checked here, then sent with
  /// the code, so the same code makes the account and proves the number.
  void _continueAccount() {
    final name = _nameController.text.trim();
    final password = _passwordController.text;
    setState(() {
      _nameError = name.isEmpty ? 'اكتب اسمك' : null;
      _passwordError = password.length < 6
          ? 'كلمة المرور 6 أحرف أو أكثر'
          : utf8.encode(password).length > 72
          ? 'كلمة المرور طويلة، خلّها أقصر'
          : null;
      _confirmationError =
          _passwordError == null && password != _confirmationController.text
          ? 'الكلمتين مو نفس بعض'
          : null;
    });
    if (_nameError != null ||
        _passwordError != null ||
        _confirmationError != null) {
      return;
    }
    setState(() => _step = _InviteStep.code);
  }

  Future<void> _verifyOtp() async {
    final code = _otpController.text.trim();
    if (code.length != _otpLength) {
      setState(() => _otpFieldState = AarastOtpFieldState.error);
      return;
    }
    if (_isVerifying) return;

    final auth = context.read<AuthController>();
    final previousUserId = auth.user?.id;
    setState(() => _isVerifying = true);
    final success = await auth.verifyOtp(
      phone: _phoneController.text.trim(),
      purpose: _otpPurpose,
      code: code,
      resumeInviteToken: _token,
      accountName: _accountSetupRequired ? _nameController.text.trim() : null,
      accountPassword: _accountSetupRequired ? _passwordController.text : null,
    );
    if (!mounted) return;
    if (!success) {
      setState(() {
        _isVerifying = false;
        _otpFieldState = AarastOtpFieldState.error;
        if (auth.errorCode == 'INVITE_ACCOUNT_SETUP_REQUIRED') {
          _accountSetupRequired = true;
          _step = _InviteStep.account;
        }
      });
      return;
    }
    _resendTimer?.cancel();
    if (previousUserId != auth.user?.id) {
      // The account boundary is about to replace this page. The verified
      // account's router resumes this link and shows the invite there.
      return;
    }
    auth.consumePendingInviteResume(_token);
    setState(() => _otpFieldState = AarastOtpFieldState.success);
    await Future<void>.delayed(AarastOtpField.successHold(context));
    if (!mounted) return;
    await _loadInvite();
  }

  Future<void> _loadInvite() async {
    final provider = context.read<SharingProvider>();
    setState(() {
      _isVerifying = false;
      _step = _InviteStep.invite;
    });
    await provider.loadMyInvites(token: _token);
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
      _otpFieldState = AarastOtpFieldState.idle;
      _isVerifying = false;
      _resendSeconds = 0;
      _otpNoticeMessage = null;
      _otpDeliveryConfirmed = false;
      _accountSetupRequired = false;
      _nameError = null;
      _passwordError = null;
      _confirmationError = null;
      _step = _InviteStep.phone;
    });
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

  Future<void> _accept(PlanInvite invite) async {
    final provider = context.read<SharingProvider>();
    final ok = await provider.respondToInvite(invite.token, accept: true);
    if (!mounted || !ok) return;
    await _openPlan(provider.selectedInvite ?? invite);
  }

  Future<void> _confirmDecline(PlanInvite invite) async {
    final confirmed = await showJourneySheet<bool>(
      context: context,
      builder: (sheetContext) => JourneySheetBody(
        title: 'ترفض الدعوة؟',
        subtitle: 'ما تنضم للخطة، وصاحبها يقدر يرسل لك دعوة جديدة بعدين.',
        children: [
          JourneyButton(
            key: const Key('invite-confirm-decline-button'),
            label: 'ارفض الدعوة',
            background: AarastV3Color.danger,
            expand: true,
            large: true,
            onPressed: () => Navigator.of(sheetContext).pop(true),
          ),
          const SizedBox(height: 6),
          Center(
            child: JourneyTextAction(
              label: 'رجوع',
              onPressed: () => Navigator.of(sheetContext).pop(false),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<SharingProvider>().respondToInvite(
      invite.token,
      accept: false,
    );
  }

  /// After joining, the plan opens straight on its home (x06); the
  /// participant's path is selected, never guessed.
  Future<void> _openPlan(PlanInvite invite) async {
    if (_openingPlan) return;
    final provider = context.read<SharingProvider>();
    final accountContexts = context.read<AccountContextController>();
    final expected = 'plan:${invite.weddingPlanId}:contributor';
    final contextKey =
        invite.contextKey == expected ||
            provider.acceptedInviteContextKey == expected
        ? expected
        : null;
    if (contextKey == null) {
      AarastToast.showError(context, 'ما لقينا مكانك في هذي الخطة.');
      return;
    }
    setState(() => _openingPlan = true);
    final router = GoRouter.of(context);
    final selected = await accountContexts.select(contextKey);
    if (!mounted) return;
    if (!selected ||
        accountContexts.selectedContext?.contextKey != contextKey) {
      setState(() => _openingPlan = false);
      AarastToast.showError(
        context,
        accountContexts.errorMessage ?? 'ما قدرنا نفتح الخطة. حاول مرة ثانية.',
      );
      return;
    }
    router.go(AppRouter.home);
  }

  void _handleBack() {
    switch (_step) {
      case _InviteStep.account:
        _returnToPhone();
      case _InviteStep.code:
        if (_accountSetupRequired) {
          setState(() => _step = _InviteStep.account);
        } else {
          _returnToPhone();
        }
      case _InviteStep.phone:
      case _InviteStep.invite:
        context.popOrGo(
          context.read<AuthController>().status == AuthStatus.authenticated
              ? AppRouter.home
              : AppRouter.welcome,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    // The invite is read only once the phone is proven.
    final sharing = _step == _InviteStep.invite
        ? context.watch<SharingProvider>()
        : null;
    final invite = sharing?.selectedInvite;
    final title = switch (_step) {
      _InviteStep.phone => 'دعوة للمشاركة',
      _InviteStep.account => 'حسابك في اعّرست',
      _InviteStep.code => 'رمز التحقق',
      _InviteStep.invite => 'الدعوة',
    };
    final children = switch (_step) {
      _InviteStep.phone => _phoneStep(auth),
      _InviteStep.account => _accountStep(),
      _InviteStep.code => _codeStep(auth),
      _InviteStep.invite => _inviteStep(sharing!, invite),
    };
    final bottom = _bottom(auth, sharing, invite);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: AarastScreenFrame(
        maxWidth: 520,
        backgroundColor: AarastV3Color.canvas,
        resizeToAvoidBottomInset: true,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                children: [
                  JourneySubHeader(title: title, onBack: _handleBack),
                  _InviteSteps(
                    current: switch (_step) {
                      _InviteStep.phone => 0,
                      _InviteStep.account || _InviteStep.code => 1,
                      _InviteStep.invite => 2,
                    },
                  ),
                  const SizedBox(height: 16),
                  ...children,
                ],
              ),
            ),
            if (bottom != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: bottom,
              ),
          ],
        ),
      ),
    );
  }

  /// q01: the number the invite was sent to. The inviter's line is not shown
  /// yet: nothing about the plan is read before the code (C35).
  List<Widget> _phoneStep(AuthController auth) {
    return [
      JourneyTextField(
        key: const Key('invite-phone-field'),
        label: 'رقم الهاتف',
        controller: _phoneController,
        icon: LucideIcons.phone,
        hint: '7XX XXX XXX',
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.done,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
        autofocus: true,
        errorText: auth.errorMessage,
        onChanged: (_) {
          if (auth.errorMessage != null) auth.clearError();
        },
        onSubmitted: (_) => _requestOtp(),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'نفس الرقم اللي وصلته الدعوة عليه.',
          style: JourneyType.of(
            JourneyType.small,
            color: AarastV3Color.textMuted,
          ),
        ),
      ),
    ];
  }

  /// q02: a first visit makes the account; the code comes next.
  List<Widget> _accountStep() {
    return [
      Text(
        'أول مرة تدخل؟ نسوي لك حساب، وتقدر بعدين تبدأ خطتك أنت كمان.',
        style: JourneyType.of(
          JourneyType.body,
          color: AarastV3Color.textMuted,
          height: 1.5,
        ),
      ),
      const SizedBox(height: 14),
      JourneyTextField(
        key: const ValueKey('invite-account-name-field'),
        label: 'اسمك',
        controller: _nameController,
        textInputAction: TextInputAction.next,
        autofocus: true,
        autofillHints: const [AutofillHints.name],
        errorText: _nameError,
        onChanged: (_) {
          if (_nameError != null) setState(() => _nameError = null);
        },
      ),
      const SizedBox(height: 10),
      JourneyTextField(
        key: const ValueKey('invite-account-password-field'),
        label: 'كلمة المرور',
        controller: _passwordController,
        icon: LucideIcons.lock,
        obscureText: true,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.newPassword],
        errorText: _passwordError,
        onChanged: (_) {
          if (_passwordError != null) setState(() => _passwordError = null);
        },
      ),
      const SizedBox(height: 10),
      JourneyTextField(
        key: const ValueKey('invite-account-password-confirmation-field'),
        label: 'تأكيد كلمة المرور',
        controller: _confirmationController,
        icon: LucideIcons.lock,
        obscureText: true,
        textInputAction: TextInputAction.done,
        errorText: _confirmationError,
        onChanged: (_) {
          if (_confirmationError != null) {
            setState(() => _confirmationError = null);
          }
        },
        onSubmitted: (_) => _continueAccount(),
      ),
    ];
  }

  /// The code (no screen of its own in the design): the step line stays on
  /// «التحقق», and the copy never claims a delivery the server did not
  /// confirm.
  List<Widget> _codeStep(AuthController auth) {
    if (_otpFieldState == AarastOtpFieldState.success) {
      return const [
        AarastOtpSuccessPanel(
          title: 'تأكدنا من رقمك',
          subtitle: 'نفتح لك الدعوة الحين.',
        ),
      ];
    }
    final phone = PhoneNumberUtils.display(_phoneController.text.trim());
    final waiting = _resendSeconds > 0;
    return [
      Text(
        _otpDeliveryConfirmed
            ? 'أرسلنا لك رمز على واتساب'
            : 'طلبنا لك رمز على واتساب',
        style: JourneyType.of(JourneyType.title, weight: JourneyType.bold),
      ),
      const SizedBox(height: 4),
      Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        children: [
          Text(
            _otpDeliveryConfirmed ? 'وصل إلى الرقم' : 'إذا وصلك على الرقم',
            style: JourneyType.of(
              JourneyType.body,
              color: AarastV3Color.textMuted,
            ),
          ),
          Text(
            phone ?? _phoneController.text.trim(),
            textDirection: TextDirection.ltr,
            style: JourneyType.of(
              JourneyType.body,
              color: AarastV3Color.textMuted,
            ),
          ),
          JourneyTextAction(
            label: 'تغيير',
            color: AarastV3Color.primary,
            onPressed: auth.isSubmitting ? null : _returnToPhone,
          ),
        ],
      ),
      const SizedBox(height: 18),
      if (_otpNoticeMessage case final notice?) ...[
        JourneyNote(text: notice, icon: LucideIcons.messageCircle),
        const SizedBox(height: 14),
      ],
      AarastOtpField(
        controller: _otpController,
        length: _otpLength,
        state: _otpFieldState,
        enabled: !_isVerifying,
        fieldKey: const Key('invite-otp-field'),
        onChanged: _onOtpChanged,
        onCompleted: (_) => _verifyOtp(),
      ),
      if (auth.errorMessage case final error?) ...[
        const SizedBox(height: 12),
        JourneyNote(
          text: error,
          icon: LucideIcons.alertCircle,
          color: AarastV3Color.danger,
          soft: AarastV3Color.dangerSoft,
        ),
      ],
      const SizedBox(height: 12),
      Center(
        child: JourneyTextAction(
          key: const ValueKey('invite-otp-resend-button'),
          label: waiting
              ? 'نعيد الإرسال بعد ${_clock(_resendSeconds)}'
              : 'أرسل رمز جديد',
          color: AarastV3Color.primary,
          onPressed: waiting || auth.isSubmitting ? null : _resendOtp,
        ),
      ),
    ];
  }

  /// q03: who asks, the role, and what each section allows, built from the
  /// invite's own flags.
  List<Widget> _inviteStep(SharingProvider sharing, PlanInvite? invite) {
    if (sharing.isLoading) {
      return const [
        JourneyListState(
          phase: JourneyListPhase.loading,
          section: JourneySection.home,
        ),
      ];
    }
    if (invite == null) {
      return [
        if (sharing.errorMessage case final error?) ...[
          JourneyNote(
            text: error,
            icon: LucideIcons.alertCircle,
            color: AarastV3Color.danger,
            soft: AarastV3Color.dangerSoft,
          ),
          const SizedBox(height: 12),
        ],
        JourneyListState(
          key: const ValueKey('invite-load-error'),
          phase: JourneyListPhase.error,
          section: JourneySection.home,
          onRetry: _loadInvite,
        ),
      ];
    }
    final inviter = invite.inviterName?.trim() ?? '';
    final ended = invite.hasEndedMembership;
    return [
      _InviterCard(invite: invite),
      if (ended)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: JourneyNote(
            key: const Key('invite-membership-ended'),
            text:
                'قبلت هذي الدعوة من قبل، بس ما عاد لك وصول للخطة. اطلب منه يرسل لك دعوة جديدة.',
            icon: LucideIcons.userX,
            color: AarastV3Color.textMuted,
            soft: AarastV3Color.paper,
          ),
        )
      else ...[
        JourneySectionTitle('دورك: ${participantRoleLabel(invite.role)}'),
        _InviteRights(invite: invite),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            '${inviter.isEmpty ? 'صاحب الخطة' : inviter} يقدر يغيّرها، وأنت تقدر تطلع من الخطة متى ما تشتي.',
            style: JourneyType.of(
              JourneyType.detail,
              color: AarastV3Color.textMuted,
            ),
          ),
        ),
        if (!invite.isPending && !invite.hasActiveMembership) ...[
          const SizedBox(height: 12),
          JourneyNote(
            key: ValueKey('invite-status-${invite.status}'),
            text: _closedInviteMessage(invite.status),
            icon: LucideIcons.info,
            color: AarastV3Color.textMuted,
            soft: AarastV3Color.paper,
          ),
        ],
      ],
      if (sharing.errorMessage case final error?) ...[
        const SizedBox(height: 12),
        JourneyNote(
          text: error,
          icon: LucideIcons.alertCircle,
          color: AarastV3Color.danger,
          soft: AarastV3Color.dangerSoft,
        ),
      ],
    ];
  }

  Widget? _bottom(
    AuthController auth,
    SharingProvider? sharing,
    PlanInvite? invite,
  ) {
    switch (_step) {
      case _InviteStep.phone:
        return JourneyButton(
          key: const Key('invite-request-otp-button'),
          label: 'إرسال رمز التحقق',
          icon: LucideIcons.send,
          expand: true,
          large: true,
          loading: auth.isSubmitting,
          onPressed: _requestOtp,
        );
      case _InviteStep.account:
        return JourneyButton(
          key: const ValueKey('invite-account-setup-continue'),
          label: 'متابعة إلى رمز التحقق',
          expand: true,
          large: true,
          onPressed: _continueAccount,
        );
      case _InviteStep.code:
        if (_otpFieldState == AarastOtpFieldState.success) return null;
        return JourneyButton(
          key: const Key('invite-verify-otp-button'),
          label: 'تأكيد الرمز',
          expand: true,
          large: true,
          loading: _isVerifying || auth.isSubmitting,
          onPressed: _verifyOtp,
        );
      case _InviteStep.invite:
        if (sharing == null || invite == null || sharing.isLoading) {
          return null;
        }
        if (invite.isPending) {
          return Row(
            children: [
              Expanded(
                child: JourneyButton(
                  key: const Key('invite-accept-button'),
                  label: 'قبول والانضمام',
                  large: true,
                  loading: sharing.isSubmitting || _openingPlan,
                  onPressed: () => _accept(invite),
                ),
              ),
              const SizedBox(width: 10),
              JourneyButton.quiet(
                key: const Key('invite-decline-button'),
                label: 'رفض الدعوة',
                large: true,
                onPressed: sharing.isSubmitting || _openingPlan
                    ? null
                    : () => _confirmDecline(invite),
              ),
            ],
          );
        }
        if (invite.hasActiveMembership) {
          return JourneyButton(
            key: const Key('invite-open-plan-button'),
            label: 'ادخل الخطة',
            expand: true,
            large: true,
            loading: _openingPlan,
            onPressed: () => _openPlan(invite),
          );
        }
        return null;
    }
  }
}

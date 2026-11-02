import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart'
    show adminAppPasswordRequiredMessage;
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/routing/pop_or_go.dart';
import '../../../core/utils/arabic_date_formatter.dart';
import '../../../core/utils/whatsapp_share.dart';
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

enum _InviteStep { phone, code, closed, invite }

/// The message that asks the plan's owner for a new invite, when this one
/// does not open with the proven number.
const _askNewInviteMessage =
    'هلا، دعوة اعّرست ما فتحت معي. ممكن دعوة جديدة على رقمي؟';

/// An invite link opens on the phone it was sent to (D75). The number (and,
/// for a first visit, a name; no password) is proven with a WhatsApp code,
/// and only then the invite shows who asks, the role and what each section
/// allows. Joining or refusing is always an explicit press; nothing about
/// the plan shows before the code. A link that does not open with that
/// number (ended, or sent to another number; the server keeps the two
/// apart from no one) says both and offers to ask for a new one.
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

  _InviteStep _step = _InviteStep.phone;
  AarastOtpFieldState _otpFieldState = AarastOtpFieldState.idle;
  bool _isVerifying = false;
  bool _accountSetupRequired = false;
  bool _openingPlan = false;
  String? _otpNoticeMessage;
  bool _otpDeliveryConfirmed = false;
  String? _nameError;
  String? _phoneError;
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
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final auth = context.read<AuthController>();
    if (auth.isSubmitting) return;
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || !isValidYemeniPhoneInput(phone)) {
      setState(
        () => _phoneError = phone.isEmpty
            ? 'اكتب الرقم اللي وصلتك عليه الدعوة'
            : 'رقم الجوال غير صحيح',
      );
      return;
    }
    final result = await auth.requestInviteOtp(token: _token, phone: phone);
    if (!mounted || result == null) return;
    _otpController.clear();
    final needsName =
        result.accountSetupRequired && _nameController.text.trim().isEmpty;
    setState(() {
      _accountSetupRequired = result.accountSetupRequired;
      // A first visit needs a name for the account: asked here, before
      // the code is typed, so the same code makes the account.
      _nameError = needsName ? 'اكتب اسمك، أول مرة تدخل اعّرست' : null;
      _step = needsName ? _InviteStep.phone : _InviteStep.code;
      _otpFieldState = AarastOtpFieldState.idle;
      _otpNoticeMessage = result.noticeMessage;
      _otpDeliveryConfirmed = result.isDeliveryConfirmed;
    });
    _startResendCooldown();
  }

  /// The name was missing on a first visit; the code is already on its way.
  void _continueWithName() {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'اكتب اسمك، أول مرة تدخل اعّرست');
      return;
    }
    setState(() {
      _nameError = null;
      _step = _InviteStep.code;
    });
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
    );
    if (!mounted) return;
    if (!success) {
      setState(() {
        _isVerifying = false;
        _otpFieldState = AarastOtpFieldState.error;
        if (auth.errorCode == 'INVITE_ACCOUNT_SETUP_REQUIRED') {
          _accountSetupRequired = true;
          // With a name already given, only an admin's number still needs
          // more (a password), which this screen does not take.
          _nameError = _nameController.text.trim().isEmpty
              ? 'اكتب اسمك، أول مرة تدخل اعّرست'
              : adminAppPasswordRequiredMessage;
          _step = _InviteStep.phone;
        } else if (auth.errorCode == 'INVITE_NOT_FOUND_FOR_PHONE') {
          _resendTimer?.cancel();
          _step = _InviteStep.closed;
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
      _phoneError = null;
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
          const SizedBox(height: AarastV3Space.x1),
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
      case _InviteStep.code:
      case _InviteStep.closed:
        _returnToPhone();
      case _InviteStep.phone:
      case _InviteStep.invite:
        context.popOrGo(
          context.read<AuthController>().status == AuthStatus.authenticated
              ? AppRouter.home
              : AppRouter.welcome,
        );
    }
  }

  Future<void> _askNewInvite() async {
    bool opened;
    try {
      opened = await launchUrl(
        whatsAppShareUri(_askNewInviteMessage),
        mode: LaunchMode.externalApplication,
      );
    } on Object {
      opened = false;
    }
    if (opened || !mounted) return;
    await Clipboard.setData(const ClipboardData(text: _askNewInviteMessage));
    if (!mounted) return;
    AarastToast.showInfo(context, 'نسخنا لك الرسالة، أرسلها له بأي طريقة.');
  }

  void _showCodeHelp() {
    showJourneySheet<void>(
      context: context,
      builder: (sheetContext) => JourneyCodeHelpSheet(
        resendSeconds: () => _resendSeconds,
        changeLabel: 'تغيير الرقم',
        onResend: () {
          Navigator.of(sheetContext).pop();
          _resendOtp();
        },
        onChangeNumber: () {
          Navigator.of(sheetContext).pop();
          _returnToPhone();
        },
        onLater: null,
        onPassword: null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    // The invite is read only once the phone is proven.
    final sharing = _step == _InviteStep.invite
        ? context.watch<SharingProvider>()
        : null;
    final invite = sharing?.selectedInvite;
    final children = switch (_step) {
      _InviteStep.phone => _phoneStep(auth),
      _InviteStep.code => _codeStep(auth),
      _InviteStep.closed => _closedStep(),
      _InviteStep.invite => _inviteStep(sharing!, invite),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: AarastScreenFrame(
        maxWidth: 520,
        backgroundColor: AarastV3Color.canvas,
        resizeToAvoidBottomInset: true,
        child: JourneyPage(
          bottom: _bottom(auth, sharing, invite),
          children: [
            JourneyStepBar(onBack: _handleBack),
            ...children,
          ],
        ),
      ),
    );
  }

  /// The number the invite was sent to, and a name for a first visit.
  /// Nothing about the plan is read before the code (C35).
  List<Widget> _phoneStep(AuthController auth) {
    final error = auth.errorMessage;
    return [
      const JourneyEntryQuestion(
        question: 'دعوة للمشاركة',
        help: 'نفس الرقم اللي وصلته الدعوة عليه.',
      ),
      const SizedBox(height: AarastV3Space.x5),
      JourneyPhoneField(
        key: const Key('invite-phone-field'),
        controller: _phoneController,
        autofocus: true,
        errorText: _phoneError,
        onChanged: (_) {
          if (auth.errorMessage != null) auth.clearError();
          if (_phoneError != null) setState(() => _phoneError = null);
        },
        onSubmitted: (_) => _requestOtp(),
      ),
      const SizedBox(height: AarastV3Field.gap),
      JourneyTextField(
        key: const ValueKey('invite-account-name-field'),
        label: 'الاسم',
        hint: 'اسمك',
        controller: _nameController,
        textInputAction: TextInputAction.done,
        autofillHints: const [AutofillHints.name],
        helper: 'لو أول مرة تدخل اعّرست',
        helperColor: AarastV3Color.textMuted,
        errorText: _nameError,
        onChanged: (_) {
          if (_nameError != null) setState(() => _nameError = null);
        },
      ),
      if (error != null) ...[
        const SizedBox(height: AarastV3Space.x3),
        JourneyNote(
          text: auth.failedOffline ? 'ما قدرنا نرسل الرمز، النت مقطوع.' : error,
          icon: LucideIcons.alertCircle,
          color: AarastV3Color.danger,
          soft: AarastV3Color.dangerSoft,
        ),
      ],
    ];
  }

  /// The code, as on every code screen; the copy never claims a delivery
  /// the server did not confirm.
  List<Widget> _codeStep(AuthController auth) {
    final phone = _phoneController.text.trim();
    final wrongCode = auth.errorCode == 'OTP_INVALID_OR_EXPIRED';
    return [
      JourneyEntryQuestion(
        question: _otpDeliveryConfirmed
            ? 'أرسلنا لك رمز على واتساب'
            : 'طلبنا لك رمز على واتساب',
        help: PhoneNumberUtils.directionalDisplay(phone) ?? phone,
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: JourneyTextAction(
          label: 'تغيير الرقم',
          color: context.accent.primaryDark,
          onPressed: auth.isSubmitting ? null : _returnToPhone,
        ),
      ),
      if (_otpNoticeMessage case final notice?) ...[
        const SizedBox(height: AarastV3Space.x2),
        JourneyEntryNote(text: notice, icon: LucideIcons.messageCircle),
      ],
      const SizedBox(height: AarastV3Space.x3),
      AarastOtpField(
        controller: _otpController,
        length: _otpLength,
        state: _otpFieldState,
        enabled: !_isVerifying,
        fieldKey: const Key('invite-otp-field'),
        onChanged: _onOtpChanged,
        onCompleted: (_) => _verifyOtp(),
      ),
      if (wrongCode) ...[
        const SizedBox(height: AarastV3Space.x3),
        Text(
          'الرمز غلط، جرّب مرة ثانية.',
          textAlign: TextAlign.center,
          style: JourneyType.of(
            JourneyType.body,
            weight: JourneyType.bold,
            color: AarastV3Color.danger,
          ),
        ),
      ] else if (auth.errorMessage case final error?) ...[
        const SizedBox(height: AarastV3Space.x3),
        JourneyNote(
          text: error,
          icon: LucideIcons.alertCircle,
          color: AarastV3Color.danger,
          soft: AarastV3Color.dangerSoft,
        ),
      ],
      const SizedBox(height: AarastV3Space.x4),
      JourneyCodeResendRow(
        seconds: _resendSeconds,
        onResend: auth.isSubmitting ? null : _resendOtp,
        onHelp: _showCodeHelp,
      ),
    ];
  }

  /// The proven number does not open this link: it ended, or it was sent
  /// to another number. Both are said, since the server tells them apart
  /// to no one.
  List<Widget> _closedStep() {
    return const [
      JourneyEntryQuestion(
        question: 'الدعوة ما تفتح بهذا الرقم',
        help:
            'يا إنها انتهت، يا إنها انرسلت لرقم ثاني. الدعوة تفتح بس بالرقم اللي انرسلت له.',
      ),
      SizedBox(height: AarastV3Space.x5),
      JourneyEntryNote(
        key: Key('invite-closed'),
        text: 'رسالة واتساب جاهزة تطلب فيها دعوة جديدة لرقمك.',
        icon: LucideIcons.messageCircle,
      ),
    ];
  }

  /// Who asks, the role, and what each section allows, from the invite's
  /// own flags.
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
          const SizedBox(height: AarastV3Space.x3),
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
    final planTitle = invite.weddingPlanTitle?.trim() ?? '';
    final date = invite.weddingDate;
    final city = invite.weddingCity?.trim() ?? '';
    final ended = invite.hasEndedMembership;
    return [
      const SizedBox(height: AarastV3Space.x2),
      const JourneyEntryNote(
        text: 'تأكدنا من رقمك.',
        icon: LucideIcons.check,
        tone: JourneyEntryNoteTone.bare,
      ),
      JourneyEntryQuestion(
        key: const ValueKey('invite-inviter-card'),
        question: _inviteTitle(invite, inviter, planTitle),
        help: [
          if (planTitle.isNotEmpty) planTitle,
          if (city.isNotEmpty) city,
          if (date != null) formatArabicWeekdayDayMonth(date),
        ].join(' · '),
      ),
      const SizedBox(height: AarastV3Space.x5),
      if (ended)
        const JourneyEntryNote(
          key: Key('invite-membership-ended'),
          text:
              'قبلت هذي الدعوة من قبل، بس ما عاد لك وصول للخطة. اطلب دعوة جديدة من صاحب الخطة.',
          icon: LucideIcons.userX,
          color: AarastV3Color.textMuted,
        )
      else ...[
        JourneyBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'دورك: ${participantRoleLabel(invite.role)}',
                style: JourneyType.of(
                  JourneyType.bodyLarge,
                  weight: JourneyType.bold,
                ),
              ),
              const SizedBox(height: AarastV3Space.x1),
              _InviteRights(invite: invite),
            ],
          ),
        ),
        if (!invite.isPending && !invite.hasActiveMembership) ...[
          const SizedBox(height: AarastV3Space.x3),
          JourneyEntryNote(
            key: ValueKey('invite-status-${invite.status}'),
            text: _closedInviteMessage(invite.status),
            icon: LucideIcons.info,
            color: AarastV3Color.textMuted,
          ),
        ],
      ],
      if (sharing.errorMessage case final error?) ...[
        const SizedBox(height: AarastV3Space.x3),
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
        final codeSent = _accountSetupRequired && _resendSeconds > 0;
        return JourneyEntryActions(
          primary: JourneyButton(
            key: const Key('invite-request-otp-button'),
            label: codeSent ? 'التالي' : 'أرسل الرمز',
            expand: true,
            large: true,
            loading: auth.isSubmitting,
            onPressed: codeSent ? _continueWithName : _requestOtp,
          ),
        );
      case _InviteStep.code:
        return null;
      case _InviteStep.closed:
        return JourneyEntryActions(
          primary: JourneyButton(
            key: const Key('invite-ask-new'),
            label: 'طلب دعوة جديدة على واتساب',
            icon: LucideIcons.messageCircle,
            expand: true,
            large: true,
            onPressed: _askNewInvite,
          ),
          secondary: JourneyEntryLink(
            label: 'تغيير الرقم',
            strong: true,
            onPressed: _returnToPhone,
          ),
        );
      case _InviteStep.invite:
        if (sharing == null || invite == null || sharing.isLoading) {
          return null;
        }
        if (invite.isPending) {
          return JourneyEntryActions(
            primary: JourneyButton(
              key: const Key('invite-accept-button'),
              label: 'قبول والانضمام',
              expand: true,
              large: true,
              loading: sharing.isSubmitting || _openingPlan,
              onPressed: () => _accept(invite),
            ),
            secondary: JourneyEntryLink(
              key: const Key('invite-decline-button'),
              label: 'رفض الدعوة',
              onPressed: sharing.isSubmitting || _openingPlan
                  ? null
                  : () => _confirmDecline(invite),
            ),
          );
        }
        if (invite.hasActiveMembership) {
          return JourneyEntryActions(
            primary: JourneyButton(
              key: const Key('invite-open-plan-button'),
              label: 'ادخل الخطة',
              expand: true,
              large: true,
              loading: _openingPlan,
              onPressed: () => _openPlan(invite),
            ),
          );
        }
        return null;
    }
  }
}

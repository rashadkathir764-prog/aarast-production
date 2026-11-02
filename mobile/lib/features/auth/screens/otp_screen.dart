import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart' show AarastScreenFrame;
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_otp_field.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../onboarding/onboarding_api.dart'
    show GuestOnboardingDraft, GuestOnboardingStorage, GuestPersona;
import '../models/pending_registration.dart';
import '../providers/auth_controller.dart';

class OtpScreenArgs {
  const OtpScreenArgs({
    required this.phone,
    this.purpose = 'VERIFY_PHONE',
    this.otpNoticeMessage,
    this.registration,
    this.successLocation,
  });

  final String phone;
  final String purpose;
  final String? otpNoticeMessage;
  final PendingRegistration? registration;
  final String? successLocation;
}

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    this.phone,
    this.purpose,
    this.otpNoticeMessage,
    this.registration,
    this.successLocation,
    super.key,
  });

  final String? phone;
  final String? purpose;
  final String? otpNoticeMessage;
  final PendingRegistration? registration;
  final String? successLocation;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  static const _codeLength = 6;
  static const _resendCooldown = 60;

  final TextEditingController _codeController = TextEditingController();

  bool _isVerifying = false;
  AarastOtpFieldState _fieldState = AarastOtpFieldState.idle;
  String? _otpNoticeMessage;
  Timer? _resendTimer;
  int _resendSeconds = _resendCooldown;

  /// The plan kept on this phone, if any: its colour and words, and the
  /// way to look at it first when the code does not come.
  GuestOnboardingDraft? _keptPlan;

  @override
  void initState() {
    super.initState();
    _otpNoticeMessage = widget.otpNoticeMessage;
    _startResendCooldown();
    WidgetsBinding.instance.addPostFrameCallback((_) => _readKeptPlan());
  }

  Future<void> _readKeptPlan() async {
    final GuestOnboardingStorage storage;
    try {
      storage = context.read<GuestOnboardingStorage>();
    } on ProviderNotFoundException {
      return;
    }
    final draft = await storage.loadDraft();
    if (!mounted || draft == null || !draft.isCompleteGuestPlan) return;
    setState(() => _keptPlan = draft);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendCooldown({bool notify = false}) {
    _resendTimer?.cancel();
    if (notify && mounted) {
      setState(() => _resendSeconds = _resendCooldown);
    } else {
      _resendSeconds = _resendCooldown;
    }
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

  Future<void> _resendOtp() async {
    if (_resendSeconds > 0) return;
    final authController = context.read<AuthController>();
    if (authController.isSubmitting) return;
    final phone = widget.phone ?? authController.otpRequest?.phone;
    final purpose =
        widget.purpose ?? authController.otpRequest?.purpose ?? 'VERIFY_PHONE';
    if (phone == null || phone.isEmpty) return;
    final result = await authController.requestOtp(
      phone: phone,
      purpose: purpose,
    );
    if (!mounted || result == null) return;
    _codeController.clear();
    setState(() {
      _fieldState = AarastOtpFieldState.idle;
      _otpNoticeMessage = result.noticeMessage;
    });
    _startResendCooldown(notify: true);
    if (result.isDeliveryConfirmed) {
      AarastToast.showSuccess(context, 'تم تسليم الرمز إلى واتساب');
    } else {
      AarastToast.showInfo(
        context,
        'طلبنا إعادة الإرسال، لكن لم نتأكد من وصول الرمز بعد.',
      );
    }
  }

  void _onCodeChanged(String value) {
    if (value.isEmpty) return;
    if (_fieldState == AarastOtpFieldState.error) {
      setState(() => _fieldState = AarastOtpFieldState.idle);
    }
    final auth = context.read<AuthController>();
    if (auth.errorMessage != null) auth.clearError();
  }

  Future<void> _verifyOtp() async {
    final code = _codeController.text;
    if (code.length < _codeLength || _isVerifying) return;
    final auth = context.read<AuthController>();
    final phone = widget.phone ?? auth.otpRequest?.phone;
    final purpose =
        widget.purpose ?? auth.otpRequest?.purpose ?? 'VERIFY_PHONE';
    if (phone == null || phone.isEmpty) {
      AarastToast.showInfo(context, 'اطلب رمز تحقق جديد للمتابعة.');
      return;
    }

    setState(() => _isVerifying = true);
    final registration = widget.registration;
    final success = registration == null
        ? await auth.verifyOtp(
            phone: phone,
            purpose: purpose,
            code: code,
            successLocation: widget.successLocation,
          )
        : await auth.register(
            name: registration.name,
            phone: registration.phone,
            otpCode: code,
            resumeInviteToken: _privateInviteTokenFromLocation(
              widget.successLocation,
            ),
            successLocation: widget.successLocation,
          );

    if (!mounted) return;
    if (!success) {
      setState(() {
        _isVerifying = false;
        _fieldState = AarastOtpFieldState.error;
      });
      return;
    }

    // The boxes turn to success; the router then opens what comes next
    // (saving the plan, the invitation, the joining).
    setState(() => _fieldState = AarastOtpFieldState.success);
  }

  void _goBack() {
    final auth = context.read<AuthController>();
    final phone = widget.phone ?? auth.otpRequest?.phone ?? '';
    final purpose =
        widget.purpose ?? auth.otpRequest?.purpose ?? 'VERIFY_PHONE';
    auth.clearError();
    if (context.canPop()) {
      context.pop();
      return;
    }
    final destination = widget.registration != null || purpose == 'REGISTER'
        ? AppRouter.register
        : AppRouter.login;
    context.go(
      _authLocation(
        destination,
        phone: phone,
        resumeLocation: widget.successLocation,
      ),
    );
  }

  void _goToLogin(String phone) {
    context.read<AuthController>().clearError();
    context.go(
      _authLocation(
        AppRouter.login,
        phone: phone,
        resumeLocation: widget.successLocation,
      ),
    );
  }

  void _goToPasswordReset(String phone) {
    context.read<AuthController>().clearError();
    context.go(
      _authLocation(
        AppRouter.resetPassword,
        phone: phone,
        resumeLocation: widget.successLocation,
      ),
    );
  }

  String _authLocation(
    String location, {
    required String phone,
    String? resumeLocation,
  }) {
    return Uri.parse(location)
        .replace(
          queryParameters: {
            if (phone.isNotEmpty) 'phone': phone,
            if (_isSafeInternalLocation(resumeLocation))
              'resume': resumeLocation,
          },
        )
        .toString();
  }

  bool _isSafeInternalLocation(String? location) {
    return location != null &&
        location.startsWith('/') &&
        !location.startsWith('//');
  }

  String? _privateInviteTokenFromLocation(String? location) {
    if (!_isSafeInternalLocation(location)) return null;
    final uri = Uri.tryParse(location!);
    if (uri == null ||
        uri.hasAuthority ||
        uri.pathSegments.length != 2 ||
        uri.pathSegments.first != 'invites') {
      return null;
    }
    final token = uri.pathSegments.last.trim();
    return token.isEmpty ? null : token;
  }

  /// «الرمز ما وصل؟»: what to check, then send it again, fix the number,
  /// or (with a plan on the phone) look at it first, or sign in with a
  /// password.
  Future<void> _showCodeHelp(String phone, {required bool registration}) {
    final kept = _keptPlan != null && registration;
    return showJourneySheet<void>(
      context: context,
      builder: (sheetContext) => JourneyCodeHelpSheet(
        resendSeconds: () => _resendSeconds,
        changeLabel: _changeLabel(context, registration: registration),
        onResend: () {
          Navigator.of(sheetContext).pop();
          _resendOtp();
        },
        onChangeNumber: () {
          Navigator.of(sheetContext).pop();
          _goBack();
        },
        onLater: kept
            ? () {
                Navigator.of(sheetContext).pop();
                context.read<AuthController>().clearError();
                context.go(AppRouter.home);
              }
            : null,
        onPassword: kept
            ? null
            : () {
                Navigator.of(sheetContext).pop();
                _goToLogin(phone);
              },
      ),
    );
  }

  /// «غيّر الرقم» in the plan owner's words while saving a plan; the
  /// neutral «تغيير الرقم» everywhere else.
  String _changeLabel(BuildContext context, {required bool registration}) =>
      registration && _keptPlan != null
      ? context.say('غيّر الرقم', 'غيّري الرقم')
      : 'تغيير الرقم';

  bool get _forProvider =>
      widget.successLocation?.startsWith('/provider/') == true;

  @override
  Widget build(BuildContext context) {
    final persona = _keptPlan?.persona == GuestPersona.bride
        ? 'BRIDE'
        : 'GROOM';
    return JourneyProfileScope(
      profile: JourneyProfile.fromPersona(persona),
      child: Builder(builder: _page),
    );
  }

  Widget _page(BuildContext context) {
    final auth = context.watch<AuthController>();
    final otpNoticeMessage =
        _otpNoticeMessage ?? auth.otpRequest?.noticeMessage;
    final phone = widget.phone ?? auth.otpRequest?.phone ?? '';
    final purpose =
        widget.purpose ?? auth.otpRequest?.purpose ?? 'VERIFY_PHONE';
    final isRegistration = widget.registration != null || purpose == 'REGISTER';
    // The copy never claims a delivery the server did not confirm.
    final delivered = auth.otpRequest?.isDeliveryConfirmed == true;
    final heading = auth.otpRequest?.isLocalDev == true
        ? 'أدخل رمز التجربة'
        : delivered
        ? 'أرسلنا لك رمز على واتساب'
        : 'طلبنا لك رمز على واتساب';
    final existingAccount =
        auth.errorCode == 'ACCOUNT_ALREADY_EXISTS' ||
        auth.errorCode == 'ADMIN_APP_PASSWORD_ALREADY_SET';
    final missingAccountAfterProof =
        auth.errorCode == 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF';
    final disabledAccountAfterProof =
        auth.errorCode == 'ACCOUNT_DISABLED_AFTER_PHONE_PROOF';
    final wrongCode = auth.errorCode == 'OTP_INVALID_OR_EXPIRED';
    final stopped =
        existingAccount ||
        missingAccountAfterProof ||
        disabledAccountAfterProof;
    final dark = context.accent.primaryDark;
    final after = isRegistration
        ? _keptPlan != null
              ? context.say(
                  'أول ما تكمل الأرقام الستة ندخل ونحفظ خطتك.',
                  'أول ما تكملين الأرقام الستة ندخل ونحفظ خطتك.',
                )
              : _forProvider
              ? 'بعد الرمز: طلب الانضمام بأربع خطوات.'
              : 'أول ما تكتمل الأرقام الستة ينحفظ حسابك.'
        : purpose == 'LOGIN'
        ? _keptPlan != null
              ? 'بعد الرمز ندخلك حسابك. ولو على هذا الجوال خطة وحسابك فيه خطة، نسأل وين تكون.'
              : 'بعد الرمز ندخلك حسابك.'
        : null;

    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      resizeToAvoidBottomInset: true,
      child: JourneyPage(
        bottom: !stopped
            ? null
            : JourneyEntryActions(
                primary: missingAccountAfterProof
                    ? JourneyButton(
                        key: const ValueKey('otp-go-to-register'),
                        label: 'ابدأ من هنا',
                        expand: true,
                        large: true,
                        onPressed: () {
                          auth.clearError();
                          context.go(AppRouter.welcome);
                        },
                      )
                    : JourneyButton(
                        key: const ValueKey('otp-go-to-login'),
                        label: 'تسجيل الدخول',
                        expand: true,
                        large: true,
                        onPressed: phone.isEmpty
                            ? null
                            : () => _goToLogin(phone),
                      ),
                secondary: existingAccount
                    ? JourneyEntryLink(
                        key: const ValueKey('otp-go-to-password-reset'),
                        label: context.say(
                          'نسيت كلمة المرور؟',
                          'نسيتِ كلمة المرور؟',
                        ),
                        onPressed: phone.isEmpty
                            ? null
                            : () => _goToPasswordReset(phone),
                      )
                    : null,
              ),
        children: [
          JourneyStepBar(onBack: _goBack),
          JourneyEntryQuestion(
            question: heading,
            help: phone.isEmpty
                ? null
                : PhoneNumberUtils.directionalDisplay(phone) ?? phone,
          ),
          if (phone.isNotEmpty)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: JourneyTextAction(
                label: _changeLabel(context, registration: isRegistration),
                color: dark,
                onPressed: _goBack,
              ),
            ),
          if (otpNoticeMessage != null) ...[
            const SizedBox(height: AarastV3Space.x2),
            JourneyEntryNote(
              key: const ValueKey('otp-notice'),
              text: otpNoticeMessage,
              icon: LucideIcons.messageCircle,
            ),
          ],
          const SizedBox(height: AarastV3Space.x3),
          AarastOtpField(
            controller: _codeController,
            length: _codeLength,
            state: _fieldState,
            enabled: !_isVerifying && !stopped,
            fieldKey: const Key('otp-code-field'),
            onChanged: _onCodeChanged,
            onCompleted: (_) => _verifyOtp(),
          ),
          if (wrongCode) ...[
            const SizedBox(height: AarastV3Space.x3),
            Text(
              context.say(
                'الرمز غلط، جرّب مرة ثانية.',
                'الرمز غلط، جرّبي مرة ثانية.',
              ),
              key: const ValueKey('otp-wrong'),
              textAlign: TextAlign.center,
              style: JourneyType.of(
                JourneyType.body,
                weight: JourneyType.bold,
                color: AarastV3Color.danger,
              ),
            ),
          ] else if (stopped) ...[
            const SizedBox(height: AarastV3Space.x4),
            JourneyEntryNote(
              text: existingAccount
                  ? 'هذا الرقم عليه حساب من قبل. ادخل عليه بكلمة المرور.'
                  : missingAccountAfterProof
                  ? 'هذا الرقم ما عليه حساب في اعّرست. ابدأ من البداية، وتسوي خطتك أو تقدم خدمتك.'
                  : auth.errorMessage ?? 'هذا الحساب موقوف.',
              icon: LucideIcons.info,
            ),
          ] else if (auth.errorMessage != null) ...[
            const SizedBox(height: AarastV3Space.x3),
            JourneyNote(
              text: auth.errorMessage!,
              icon: LucideIcons.alertCircle,
              color: AarastV3Color.danger,
              soft: AarastV3Color.dangerSoft,
            ),
          ],
          if (!stopped) ...[
            const SizedBox(height: AarastV3Space.x4),
            JourneyCodeResendRow(
              seconds: _resendSeconds,
              onResend: auth.isSubmitting ? null : _resendOtp,
              onHelp: phone.isEmpty
                  ? null
                  : () => _showCodeHelp(phone, registration: isRegistration),
            ),
            if (after != null) ...[
              const SizedBox(height: AarastV3Space.x1),
              JourneyEntryNote(
                text: after,
                icon: LucideIcons.info,
                tone: JourneyEntryNoteTone.bare,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

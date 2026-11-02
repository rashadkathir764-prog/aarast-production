import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/widgets/aarast_ui.dart' show AarastScreenFrame;
import '../../../core/offline/offline_sync_service.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/utils/arabic_count.dart';
import '../../../core/routing/app_router.dart';
import '../../onboarding/onboarding_api.dart'
    show GuestOnboardingDraft, GuestOnboardingStorage;
import '../providers/auth_controller.dart';
import 'otp_screen.dart';

/// «تسجيل الدخول» (D75): the same number and a WhatsApp code, in words
/// that fit anyone (a groom, a bride, a relative, a provider). A password
/// is the other way, for those who set one.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    this.initialPhone,
    this.sessionExpired = false,
    super.key,
  });

  final String? initialPhone;

  /// x18: the session expired; the same account signs in again and its
  /// unsent changes are sent (C58).
  final bool sessionExpired;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  /// D75: the number and a WhatsApp code; a password only for those who
  /// set one.
  bool _withPassword = false;

  /// After a submit showed errors, fields re-check as they are edited.
  bool _submitAttempted = false;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.initialPhone?.trim() ?? '';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? get _phoneError {
    if (!_submitAttempted) return null;
    return yemeniPhoneInputError(_phoneController.text);
  }

  String? get _passwordError {
    if (!_submitAttempted || !_withPassword) return null;
    return _passwordController.text.isEmpty ? 'كلمة المرور مطلوبة' : null;
  }

  void _edited(String _) {
    final auth = context.read<AuthController>();
    if (auth.errorMessage != null) auth.clearError();
    if (_submitAttempted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    // The expiry heading already says why; an error line returns only with
    // a new attempt.
    final error = widget.sessionExpired && !_submitAttempted
        ? null
        : auth.errorMessage;
    final pending = widget.sessionExpired ? _pendingChanges() : 0;
    return AarastScreenFrame(
      maxWidth: 520,
      backgroundColor: AarastV3Color.canvas,
      resizeToAvoidBottomInset: true,
      child: JourneyPage(
        bottom: JourneyEntryActions(
          above: error == null
              ? null
              : JourneyNote(
                  key: const ValueKey('login-error'),
                  text: auth.failedOffline
                      ? 'ما قدرنا نوصل، النت مقطوع. جرّب مرة ثانية.'
                      : error,
                  icon: auth.failedOffline
                      ? LucideIcons.wifiOff
                      : LucideIcons.alertCircle,
                  color: AarastV3Color.danger,
                  soft: AarastV3Color.dangerSoft,
                ),
          primary: JourneyButton(
            key: const ValueKey('login-submit'),
            label: _withPassword ? 'تسجيل الدخول' : 'أرسل الرمز',
            expand: true,
            large: true,
            loading: auth.isSubmitting,
            onPressed: _withPassword ? _submit : _requestLoginOtp,
          ),
          secondary: JourneyTextAction(
            key: const ValueKey('login-register-action'),
            label: 'ما عندك حساب؟ ابدأ من هنا',
            onPressed: auth.isSubmitting ? null : _start,
            color: context.accent.primaryDark,
          ),
        ),
        children: [
          JourneyStepBar(
            onBack: () => context.canPop()
                ? context.pop()
                : context.go(AppRouter.welcome),
          ),
          JourneyEntryQuestion(
            question: widget.sessionExpired ? 'ادخل مرة ثانية' : 'تسجيل الدخول',
            help: widget.sessionExpired
                ? 'طال الغياب، فقفلنا الدخول للأمان. بعد الدخول ترجع مكانك.'
                : _withPassword
                ? 'برقم جوالك وكلمة المرور.'
                : 'بنفس رقم جوالك، ونرسل رمز على واتساب.',
          ),
          if (pending > 0) ...[
            const SizedBox(height: AarastV3Space.x4),
            JourneyNote(
              text:
                  '${arabicCount(pending, one: 'شي واحد سجّلته بدون نت', two: 'شيئين سجّلتها بدون نت', few: 'أشياء سجّلتها بدون نت', many: 'شي سجّلته بدون نت')}: '
                  'محفوظة في جوالك، وتوصل أول ما تدخل بنفس الحساب.',
              icon: LucideIcons.cloudOff,
              tone: JourneyNoteTone.warn,
            ),
          ],
          const SizedBox(height: AarastV3Space.x5),
          JourneyPhoneField(
            key: const ValueKey('login-phone'),
            controller: _phoneController,
            errorText: _phoneError,
            onChanged: _edited,
            onSubmitted: (_) => _withPassword ? null : _requestLoginOtp(),
          ),
          if (_withPassword) ...[
            const SizedBox(height: AarastV3Field.gap),
            JourneyTextField(
              key: const ValueKey('login-password'),
              label: 'كلمة المرور',
              controller: _passwordController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              errorText: _passwordError,
              onChanged: _edited,
              onSubmitted: (_) => _submit(),
            ),
          ],
          Wrap(
            spacing: AarastV3Space.x2,
            children: [
              JourneyTextAction(
                key: const ValueKey('login-mode'),
                label: _withPassword
                    ? 'الدخول برمز واتساب'
                    : 'الدخول بكلمة المرور',
                color: AarastV3Color.primaryDark,
                onPressed: auth.isSubmitting ? null : _switchMode,
              ),
              if (_withPassword)
                JourneyTextAction(
                  key: const ValueKey('login-forgot-password-action'),
                  label: 'نسيت كلمة المرور؟',
                  onPressed: _openResetPassword,
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _switchMode() {
    context.read<AuthController>().clearError();
    setState(() {
      _withPassword = !_withPassword;
      _submitAttempted = false;
    });
  }

  /// No account: the door, where a plan is made or a service offered.
  Future<void> _start() async {
    context.read<AuthController>().clearError();
    GuestOnboardingDraft? kept;
    try {
      kept = await context.read<GuestOnboardingStorage>().loadDraft();
    } on ProviderNotFoundException {
      kept = null;
    }
    if (!mounted) return;
    // A plan already on this phone is saved with a number, never replaced
    // by starting over.
    final resume = _safeResumeLocation(context);
    // A provider page sent this person: their own sign-up, keeping the way
    // back to it.
    if (resume != null && resume.startsWith('/provider/')) {
      context.go(
        Uri(
          path: AppRouter.register,
          queryParameters: {'type': 'provider', 'resume': resume},
        ).toString(),
      );
      return;
    }
    context.go(
      kept?.isCompleteGuestPlan == true
          ? AppRouter.register
          : AppRouter.welcome,
    );
  }

  int _pendingChanges() {
    try {
      return context.watch<OfflineSyncService>().pendingCount;
    } on ProviderNotFoundException {
      return 0;
    }
  }

  void _openResetPassword() {
    final phone = _phoneController.text.trim();
    final resume = _safeResumeLocation(context);
    final location = Uri.parse(AppRouter.resetPassword)
        .replace(
          queryParameters: {
            if (phone.isNotEmpty) 'phone': phone,
            'resume': ?resume,
          },
        )
        .toString();
    context.push(location);
  }

  Future<void> _submit() async {
    if (!_submitAttempted) setState(() => _submitAttempted = true);
    if (_phoneError != null || _passwordError != null) return;

    final auth = context.read<AuthController>();
    final success = await auth.login(
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
      successLocation: _safeResumeLocation(context),
    );

    if (!mounted || success) return;

    // The backend emits this code only after the application password matched
    // an active account. Continue the same login attempt through phone proof;
    // invalid credentials must never trigger an OTP or reveal account state.
    if (auth.errorCode == 'PHONE_VERIFICATION_REQUIRED') {
      await _requestLoginOtp(validated: true);
    }
  }

  Future<void> _requestLoginOtp({bool validated = false}) async {
    if (!validated) {
      if (!_submitAttempted) setState(() => _submitAttempted = true);
      if (_phoneError != null) return;
    }
    final auth = context.read<AuthController>();
    final phone = normalizeYemeniPhone(_phoneController.text.trim());
    final otp = await auth.requestOtp(phone: phone, purpose: 'LOGIN');
    if (otp == null || !mounted) return;

    context.push(
      AppRouter.otp,
      extra: OtpScreenArgs(
        phone: phone,
        purpose: 'LOGIN',
        otpNoticeMessage: otp.noticeMessage,
        successLocation: _safeResumeLocation(context),
      ),
    );
  }

  String? _safeResumeLocation(BuildContext context) {
    final resume = GoRouterState.of(context).uri.queryParameters['resume'];
    if (resume == null || resume.trim().isEmpty) return null;
    if (!resume.startsWith('/') || resume.startsWith('//')) return null;
    return resume;
  }
}

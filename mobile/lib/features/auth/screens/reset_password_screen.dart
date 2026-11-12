import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/network/api_client.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/widgets/aarast_otp_field.dart';
import '../data/auth_repository.dart';
import '../providers/auth_controller.dart';
import '../utils/application_password_policy.dart';
import '../widgets/auth_wedding_widgets.dart';

enum _ResetStep { phone, code, password, done }

/// w01 «نسيت كلمة المرور»: «رقمك», «الرمز», «كلمة جديدة». The server has no
/// step that checks the code alone, so the code and the new password are
/// sent together on the last step; a wrong code takes the person back to
/// «الرمز». The reset signs every device out, this one too, so the app then
/// signs in again with the new password. The server never says whether the
/// number has an account.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({this.initialPhone, super.key});

  final String? initialPhone;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  static const _resendCooldown = 60;
  static const _codeLength = 6;

  /// The number's error shows once the code was asked for, as in sign-in.
  bool _phoneAsked = false;
  final _passwordFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _ResetStep _step = _ResetStep.phone;
  bool _signingIn = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  AarastOtpFieldState _codeFieldState = AarastOtpFieldState.idle;
  String? _errorMessage;
  String? _errorCode;
  String? _otpNoticeMessage;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.initialPhone?.trim() ?? '';
    _passwordController.addListener(_onPasswordChanged);
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _onPasswordChanged() {
    if (mounted && _step == _ResetStep.password) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final (action, onAction, busy) = switch (_step) {
      _ResetStep.phone => ('أرسل الرمز', _requestCode, _isSubmitting),
      _ResetStep.code => ('التالي', _acceptCode, false),
      _ResetStep.password => (
        'حفظ وتسجيل الدخول',
        _confirmReset,
        _isSubmitting,
      ),
      _ResetStep.done => (
        'تسجيل الدخول',
        () => context.go(_authLocation(AppRouter.login)),
        _signingIn,
      ),
    };
    return AuthWeddingScaffold(
      leading: SizedBox(
        width: double.infinity,
        child: JourneySubHeader(
          title: context.say('نسيت كلمة المرور', 'نسيتِ كلمة المرور'),
          onBack: _back,
        ),
      ),
      bottom: JourneyButton(
        key: const ValueKey('reset-primary-action'),
        label: action,
        expand: true,
        large: true,
        loading: busy,
        onPressed: onAction,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_step != _ResetStep.done) ...[
            _ResetSteps(at: _step.index),
            const SizedBox(height: AarastV3Space.x4),
          ],
          ...switch (_step) {
            _ResetStep.phone => _phoneStep(),
            _ResetStep.code => _codeStep(),
            _ResetStep.password => _passwordStep(),
            _ResetStep.done => _doneStep(),
          },
        ],
      ),
    );
  }

  List<Widget> _phoneStep() {
    return [
      const AuthHeading(
        title: 'اكتب رقمك',
        subtitle: 'نرسل لك رمز على واتساب، وبعده تختار كلمة مرور جديدة.',
      ),
      const SizedBox(height: AarastV3Space.x4),
      // RA-MO-128: the account's own number, in the field sign-in and
      // sign-up ask for it with (the +967 prefix, one hint, one error). It
      // was the contacts field: a picker of other people's numbers and
      // another hint, on the way back into one's own account.
      JourneyPhoneField(
        key: const ValueKey('reset-phone'),
        controller: _phoneController,
        errorText: _phoneAsked
            ? yemeniPhoneInputError(_phoneController.text)
            : null,
        onChanged: (_) {
          if (_phoneAsked) setState(() {});
        },
        onSubmitted: (_) => _requestCode(),
      ),
      if (_errorMessage != null) ...[
        const SizedBox(height: AarastV3Space.x2),
        AuthInlineError(message: _errorMessage!),
      ],
    ];
  }

  List<Widget> _codeStep() {
    final phone = _normalizedPhone;
    final waiting = _resendSeconds > 0;
    return [
      const AuthHeading(title: 'أرسلنا لك رمز على واتساب'),
      if (phone != null) ...[
        const SizedBox(height: AarastV3Space.x1),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          children: [
            Text(
              'إلى الرقم',
              style: JourneyType.of(
                JourneyType.body,
                color: AarastV3Color.textMuted,
              ),
            ),
            Text(
              PhoneNumberUtils.display(phone) ?? phone,
              textDirection: TextDirection.ltr,
              style: JourneyType.of(
                JourneyType.body,
                color: AarastV3Color.textMuted,
              ),
            ),
            JourneyTextAction(
              label: 'تغيير',
              color: context.accent.primary,
              onPressed: _isSubmitting ? null : () => _goTo(_ResetStep.phone),
            ),
          ],
        ),
      ],
      const SizedBox(height: AarastV3Space.x4),
      if (_otpNoticeMessage != null) ...[
        JourneyNote(
          key: const ValueKey('reset-otp-notice'),
          text: _otpNoticeMessage!,
          icon: LucideIcons.messageCircle,
        ),
        const SizedBox(height: AarastV3Space.x4),
      ],
      AarastOtpField(
        controller: _codeController,
        length: _codeLength,
        state: _codeFieldState,
        enabled: !_isSubmitting,
        fieldKey: const Key('reset-otp-field'),
        onChanged: (value) {
          if (value.isEmpty) return;
          if (_codeFieldState == AarastOtpFieldState.error ||
              _errorMessage != null) {
            setState(() {
              _codeFieldState = AarastOtpFieldState.idle;
              _errorMessage = null;
              _errorCode = null;
            });
          }
        },
        onCompleted: (_) => _acceptCode(),
      ),
      const SizedBox(height: AarastV3Space.x4),
      if (_errorMessage != null) ...[
        AuthInlineError(message: _errorMessage!),
        const SizedBox(height: AarastV3Space.x2),
      ],
      Center(
        child: AuthFooterLink(
          key: const ValueKey('reset-otp-resend-button'),
          prefix: 'ما وصلك؟',
          action: waiting
              ? 'نعيد الإرسال بعد ${_clock(_resendSeconds)}'
              : 'أرسل رمز جديد',
          onTap: waiting || _isSubmitting ? null : _requestCodeAgain,
        ),
      ),
    ];
  }

  List<Widget> _passwordStep() {
    final longEnough = _passwordController.text.length >= 6;
    return [
      const AuthHeading(
        title: 'اختر كلمة مرور جديدة',
        subtitle: 'خطتك وكل بياناتك كما هي.',
      ),
      const SizedBox(height: AarastV3Space.x4),
      Form(
        key: _passwordFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              controller: _passwordController,
              label: 'كلمة المرور الجديدة',
              icon: LucideIcons.lock,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              suffixIcon: AuthObscureToggle(
                obscured: _obscurePassword,
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'اكتب كلمة المرور الجديدة';
                }
                if (value.length < 6) {
                  return 'قصيرة. خلّها 6 أحرف أو أكثر';
                }
                if (!isApplicationPasswordWithinByteLimit(value)) {
                  return 'كلمة المرور طويلة جدًا. اختصرها ثم حاول مرة أخرى';
                }
                return null;
              },
            ),
            const SizedBox(height: AarastV3Space.x2),
            AuthTextField(
              controller: _confirmPasswordController,
              label: 'أعد كتابتها',
              icon: LucideIcons.lock,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _confirmReset(),
              validator: (value) {
                if (value != _passwordController.text) {
                  return 'ما تطابقت مع الكلمة الجديدة';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: AarastV3Space.x2),
      _PasswordRule(met: longEnough),
      if (_errorMessage != null) ...[
        const SizedBox(height: AarastV3Space.x3),
        AuthInlineError(message: _errorMessage!),
      ],
      if (_errorCode == 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF')
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: JourneyTextAction(
            key: const ValueKey('reset-create-account-action'),
            label: 'أنشئ حساب جديد بهذا الرقم',
            icon: LucideIcons.userPlus,
            color: context.accent.primary,
            onPressed: _isSubmitting
                ? null
                : () => context.go(_authLocation(AppRouter.register)),
          ),
        ),
      const SizedBox(height: AarastV3Space.x4),
      const JourneyNote(
        icon: LucideIcons.shieldCheck,
        text:
            'بنطلعك من كل الأجهزة، احتياط لو أحد عرف كلمتك القديمة، وندخّلك هنا بالجديدة.',
      ),
    ];
  }

  List<Widget> _doneStep() {
    return [
      const SizedBox(height: AarastV3Space.x5),
      const Center(
        child: JourneyIconTile(
          icon: LucideIcons.checkCircle2,
          color: AarastV3Color.mint,
          soft: AarastV3Color.mintSoft,
          size: 56,
          radius: 20,
        ),
      ),
      const SizedBox(height: AarastV3Space.x4),
      Semantics(
        header: true,
        child: Text(
          'غيّرنا كلمة المرور',
          textAlign: TextAlign.center,
          style: JourneyType.of(JourneyType.display, weight: JourneyType.bold),
        ),
      ),
      const SizedBox(height: AarastV3Space.x1),
      Text(
        _signingIn
            ? 'وطلعناك من كل الأجهزة لحمايتك. ندخّلك الآن بكلمة المرور الجديدة.'
            : 'وطلعناك من كل الأجهزة لحمايتك. ادخل بكلمة المرور الجديدة.',
        textAlign: TextAlign.center,
        style: JourneyType.of(JourneyType.body, color: AarastV3Color.textMuted),
      ),
    ];
  }

  String? get _normalizedPhone {
    final raw = _phoneController.text.trim();
    return isValidYemeniPhoneInput(raw) ? normalizeYemeniPhone(raw) : null;
  }

  void _goTo(_ResetStep step) {
    setState(() {
      _step = step;
      _errorMessage = null;
      _errorCode = null;
    });
  }

  void _back() {
    if (_isSubmitting) return;
    switch (_step) {
      case _ResetStep.code:
        _goTo(_ResetStep.phone);
      case _ResetStep.password:
        _goTo(_ResetStep.code);
      case _ResetStep.phone:
      case _ResetStep.done:
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(_authLocation(AppRouter.login));
        }
    }
  }

  Future<void> _requestCode() async {
    if (_isSubmitting) return;
    setState(() => _phoneAsked = true);
    if (yemeniPhoneInputError(_phoneController.text) != null) return;
    await _sendResetCode(
      onSuccess: () {
        _codeController.clear();
        setState(() {
          _step = _ResetStep.code;
          _codeFieldState = AarastOtpFieldState.idle;
          _errorMessage = null;
          _errorCode = null;
        });
      },
    );
  }

  Future<void> _requestCodeAgain() async {
    if (_isSubmitting || _resendSeconds > 0) return;
    await _sendResetCode(
      onSuccess: () {
        _codeController.clear();
        setState(() {
          _codeFieldState = AarastOtpFieldState.idle;
          _errorMessage = null;
          _errorCode = null;
        });
      },
    );
  }

  Future<void> _sendResetCode({required VoidCallback onSuccess}) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _errorCode = null;
    });
    try {
      final result = await context.read<AuthRepository>().requestPasswordReset(
        phone: _phoneController.text,
      );
      if (!mounted) return;
      _otpNoticeMessage = result.noticeMessage;
      onSuccess();
      _startResendCooldown();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.isNetworkFailure
            ? 'تعذر إرسال رمز الاستعادة الآن. تحقق من الاتصال وحاول مجددًا.'
            : error.message;
        _errorCode = error.serverCode;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذر إرسال الرمز الآن. تحقق من الاتصال وحاول مجددًا.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// «الرمز» only collects the six digits; the server checks them with the
  /// new password.
  void _acceptCode() {
    if (_codeController.text.trim().length < _codeLength) {
      setState(() {
        _codeFieldState = AarastOtpFieldState.error;
        _errorMessage = 'اكتب الرمز كامل';
      });
      return;
    }
    _goTo(_ResetStep.password);
  }

  Future<void> _confirmReset() async {
    if (_isSubmitting) return;
    if (!_passwordFormKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _errorCode = null;
    });
    try {
      await context.read<AuthRepository>().confirmPasswordReset(
        phone: _phoneController.text,
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      _resendTimer?.cancel();
      setState(() => _step = _ResetStep.done);
      await _signInWithNewPassword();
    } on ApiException catch (error) {
      if (!mounted) return;
      final codeRefused =
          error.serverCode != 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF';
      setState(() {
        _errorMessage = error.message;
        _errorCode = error.serverCode;
        // A refused code goes back to «الرمز», where it is typed again.
        if (codeRefused) {
          _step = _ResetStep.code;
          _codeFieldState = AarastOtpFieldState.error;
        }
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذر تغيير كلمة المرور الآن. حاول مرة ثانية.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// w01: the reset closed every session, so the person is signed in again
  /// with the password just chosen. When that fails, «تسجيل الدخول» stays.
  Future<void> _signInWithNewPassword() async {
    final AuthController auth;
    try {
      auth = context.read<AuthController>();
    } on ProviderNotFoundException {
      return;
    }
    final resume = _safeResumeLocation();
    setState(() => _signingIn = true);
    var signedIn = false;
    try {
      signedIn = await auth.login(
        phone: normalizeYemeniPhone(_phoneController.text),
        password: _passwordController.text,
        successLocation: resume,
      );
    } finally {
      // The spinner never outlives the attempt, whatever it ended in.
      if (mounted) setState(() => _signingIn = false);
    }
    if (!signedIn) auth.clearError();
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

  String _authLocation(String path) {
    final rawPhone = _phoneController.text.trim();
    final resume = _safeResumeLocation();
    return Uri.parse(path)
        .replace(
          queryParameters: {
            if (isValidYemeniPhoneInput(rawPhone))
              'phone': normalizeYemeniPhone(rawPhone),
            'resume': ?resume,
          },
        )
        .toString();
  }

  String? _safeResumeLocation() {
    final resume = GoRouterState.of(context).uri.queryParameters['resume'];
    if (resume == null || resume.trim().isEmpty) return null;
    if (!resume.startsWith('/') || resume.startsWith('//')) return null;
    return resume;
  }
}

/// «0:42» for a countdown in seconds.
String _clock(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// w01's three named steps: the current one filled, the ones behind soft.
class _ResetSteps extends StatelessWidget {
  const _ResetSteps({required this.at});

  static const _labels = ['رقمك', 'الرمز', 'كلمة جديدة'];

  final int at;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'الخطوة ${at + 1} من ${_labels.length}: ${_labels[at]}',
      excludeSemantics: true,
      child: Container(
        key: const ValueKey('reset-steps'),
        padding: const EdgeInsets.all(AarastV3Space.x1),
        decoration: BoxDecoration(
          color: AarastV3Color.paper,
          borderRadius: BorderRadius.circular(AarastV3Radius.pill),
          border: Border.all(color: AarastV3Color.line),
        ),
        child: Row(
          children: [
            for (var index = 0; index < _labels.length; index++)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: AarastV3Space.x2,
                  ),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: index == at
                        ? context.accent.primary
                        : index < at
                        ? context.accent.primarySoft
                        : null,
                    borderRadius: BorderRadius.circular(AarastV3Radius.pill),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _labels[index],
                      maxLines: 1,
                      style: JourneyType.of(
                        JourneyType.small,
                        weight: JourneyType.bold,
                        color: index == at
                            ? AarastV3Color.onPrimary
                            : index < at
                            ? context.accent.primary
                            : AarastV3Color.textMuted,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// «6 أحرف أو أكثر», green once the new password is long enough.
class _PasswordRule extends StatelessWidget {
  const _PasswordRule({required this.met});

  final bool met;

  @override
  Widget build(BuildContext context) {
    final color = met ? AarastV3Color.mint : AarastV3Color.textMuted;
    return Row(
      key: const ValueKey('reset-password-rule'),
      children: [
        Icon(
          met ? LucideIcons.checkCircle2 : LucideIcons.circle,
          size: 16,
          color: color,
        ),
        const SizedBox(width: AarastV3Space.x1),
        Text(
          '6 أحرف أو أكثر',
          style: JourneyType.of(
            JourneyType.small,
            weight: JourneyType.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/experience_v3/aarast_v3.dart';
import '../../../core/phone/phone_number_utils.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_otp_field.dart';
import '../../../core/widgets/aarast_toast.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../../provider_portal/provider_portal_api.dart'
    show ProviderDashboardProvider;
import '../models/pending_registration.dart';
import '../providers/auth_controller.dart';
import '../widgets/auth_wedding_widgets.dart';

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

  @override
  void initState() {
    super.initState();
    _otpNoticeMessage = widget.otpNoticeMessage;
    _startResendCooldown();
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
    final providerApplication = registration?.providerApplication;
    final provider = providerApplication == null
        ? null
        : context.read<ProviderDashboardProvider>();
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
            password: registration.password,
            otpCode: code,
            resumeInviteToken: _privateInviteTokenFromLocation(
              widget.successLocation,
            ),
            successLocation: widget.successLocation,
            afterSessionEstablished: providerApplication == null
                ? null
                : () async {
                    final applied = await provider!.applyProvider(
                      businessName: providerApplication.businessName,
                      phone: providerApplication.phone,
                      cityId: providerApplication.cityId,
                      categoryIds: [providerApplication.categoryId],
                      description: providerApplication.description,
                    );
                    if (!applied && mounted) {
                      AarastToast.showError(
                        context,
                        'تم إنشاء الحساب وتوثيق الرقم، لكن تعذر إرسال طلب المزود. يمكنك إعادة الطلب من حسابك.',
                      );
                    }
                    return applied ? AppRouter.providerApplyStatus : null;
                  },
          );

    if (!mounted) return;
    if (!success) {
      setState(() {
        _isVerifying = false;
        _fieldState = AarastOtpFieldState.error;
      });
      return;
    }

    // نجاح: لوحة تأكيد قصيرة قبل المتابعة (تُتخطى مع تقليل الحركة).
    setState(() => _fieldState = AarastOtpFieldState.success);
    await Future<void>.delayed(AarastOtpField.successHold(context));
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

  void _goToRegistration(String phone) {
    context.read<AuthController>().clearError();
    context.go(
      _authLocation(
        AppRouter.register,
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

  /// w03 «الرمز ما وصل؟»: what to check, then resend, sign in with the
  /// password, or fix the number.
  Future<void> _showCodeHelp(String phone) {
    return showAarastBottomSheet<void>(
      context: context,
      builder: (sheetContext) => _CodeHelpSheet(
        phone: phone,
        resendSeconds: () => _resendSeconds,
        onResend: () {
          Navigator.of(sheetContext).pop();
          _resendOtp();
        },
        onPassword: () {
          Navigator.of(sheetContext).pop();
          _goToLogin(phone);
        },
        onChangeNumber: () {
          Navigator.of(sheetContext).pop();
          _goBack();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
    final toNumber = delivered ? 'وصل إلى الرقم' : 'إذا وصلك على الرقم';
    final existingAccount =
        auth.errorCode == 'ACCOUNT_ALREADY_EXISTS' ||
        auth.errorCode == 'ADMIN_APP_PASSWORD_ALREADY_SET';
    final missingAccountAfterProof =
        auth.errorCode == 'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF';
    final disabledAccountAfterProof =
        auth.errorCode == 'ACCOUNT_DISABLED_AFTER_PHONE_PROOF';
    final waiting = _resendSeconds > 0;
    final verifying = _isVerifying || auth.isSubmitting;

    return AuthWeddingScaffold(
      leading: AuthBackButton(onPressed: _goBack),
      bottom: existingAccount || _fieldState == AarastOtpFieldState.success
          ? null
          : missingAccountAfterProof
          ? AarastButton(
              key: const ValueKey('otp-go-to-register'),
              label: 'إنشاء حساب',
              icon: LucideIcons.userPlus,
              onPressed: phone.isEmpty ? null : () => _goToRegistration(phone),
            )
          : disabledAccountAfterProof
          ? AarastButton(
              key: const ValueKey('otp-disabled-go-to-login'),
              label: 'العودة إلى تسجيل الدخول',
              icon: LucideIcons.arrowRight,
              onPressed: phone.isEmpty ? null : () => _goToLogin(phone),
            )
          : AarastButton(
              label: 'تأكيد الرمز',
              icon: LucideIcons.badgeCheck,
              isLoading: verifying,
              onPressed: _verifyOtp,
            ),
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 280),
        child: _fieldState == AarastOtpFieldState.success
            ? const AarastOtpSuccessPanel()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  AuthHeading(title: heading),
                  if (phone.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 10,
                      children: [
                        Text(
                          toNumber,
                          style: JourneyType.of(
                            15.5,
                            color: AarastV3Color.textMuted,
                          ),
                        ),
                        Text(
                          PhoneNumberUtils.display(phone) ?? phone,
                          textDirection: TextDirection.ltr,
                          style: JourneyType.of(
                            15.5,
                            color: AarastV3Color.textMuted,
                          ),
                        ),
                        JourneyTextAction(
                          label: 'تغيير',
                          color: AarastV3Color.primary,
                          onPressed: _goBack,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 22),
                  if (otpNoticeMessage != null) ...[
                    _OtpNotice(message: otpNoticeMessage),
                    const SizedBox(height: 16),
                  ],
                  AarastOtpField(
                    controller: _codeController,
                    length: _codeLength,
                    state: _fieldState,
                    enabled: !_isVerifying,
                    fieldKey: const Key('otp-code-field'),
                    onChanged: _onCodeChanged,
                    onCompleted: (_) => _verifyOtp(),
                  ),
                  const SizedBox(height: 16),
                  if (auth.errorMessage != null && !existingAccount) ...[
                    AuthInlineError(message: auth.errorMessage!),
                    const SizedBox(height: 14),
                  ],
                  if (existingAccount) ...[
                    // w02: the number already has an account, said only
                    // after the code proved the number is theirs.
                    AuthInlineError(message: 'هذا الرقم عليه حساب من قبل'),
                    const SizedBox(height: 12),
                    _ExistingAccountCard(
                      onSignIn: phone.isEmpty ? null : () => _goToLogin(phone),
                    ),
                    const SizedBox(height: 4),
                    Center(
                      child: TextButton.icon(
                        key: const ValueKey('otp-go-to-password-reset'),
                        onPressed: phone.isEmpty
                            ? null
                            : () => _goToPasswordReset(phone),
                        icon: const Icon(LucideIcons.keyRound, size: 18),
                        label: const Text('نسيت كلمة المرور؟'),
                      ),
                    ),
                  ] else ...[
                    Center(
                      child: AuthFooterLink(
                        key: const ValueKey('otp-resend-button'),
                        prefix: 'ما وصلك؟',
                        action: waiting
                            ? 'نعيد الإرسال بعد ${_clock(_resendSeconds)}'
                            : 'أرسل رمز جديد',
                        onTap: waiting || auth.isSubmitting ? null : _resendOtp,
                      ),
                    ),
                    if (phone.isNotEmpty && purpose != 'LOGIN')
                      JourneyBox(
                        padding: EdgeInsets.zero,
                        child: JourneyListRow(
                          icon: LucideIcons.messageSquare,
                          color: AarastV3Color.primary,
                          soft: AarastV3Color.primarySoft,
                          title: 'الرمز ما وصل؟',
                          subtitle: 'شوف ايش تسوي، أو ادخل بكلمة المرور',
                          trailing: const Icon(
                            LucideIcons.chevronLeft,
                            size: 18,
                            color: AarastV3Color.textFaint,
                          ),
                          onTap: () => _showCodeHelp(phone),
                        ),
                      ),
                    if (isRegistration || purpose == 'LOGIN') ...[
                      const SizedBox(height: 14),
                      JourneyNote(
                        text: isRegistration
                            ? 'أول ما يكتمل الرمز ينحفظ حسابك وخطتك وتدخل عليها.'
                            : 'أول ما يكتمل الرمز تدخل على حسابك.',
                        icon: LucideIcons.checkCircle2,
                      ),
                    ],
                  ],
                ],
              ),
      ),
    );
  }
}

/// «0:42» for a countdown in seconds.
String _clock(int seconds) =>
    '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';

/// w02 «هذا حسابك؟»: sign in to the account that holds this number.
class _ExistingAccountCard extends StatelessWidget {
  const _ExistingAccountCard({required this.onSignIn});

  final VoidCallback? onSignIn;

  @override
  Widget build(BuildContext context) {
    return JourneyBox(
      padding: EdgeInsets.zero,
      child: JourneyListRow(
        icon: LucideIcons.logIn,
        color: AarastV3Color.primary,
        soft: AarastV3Color.primarySoft,
        title: 'هذا حسابك؟',
        subtitle: 'ادخل عليه، وخطتك اللي على الجهاز نسألك عنها بعدها',
        trailing: JourneyButton.quiet(
          key: const ValueKey('otp-go-to-login'),
          label: 'ادخل',
          onPressed: onSignIn,
        ),
        onTap: onSignIn,
      ),
    );
  }
}

/// w03 «الرمز ما وصل؟». Codes go by WhatsApp only; no lockout line.
class _CodeHelpSheet extends StatefulWidget {
  const _CodeHelpSheet({
    required this.phone,
    required this.resendSeconds,
    required this.onResend,
    required this.onPassword,
    required this.onChangeNumber,
  });

  final String phone;
  final int Function() resendSeconds;
  final VoidCallback onResend;
  final VoidCallback onPassword;
  final VoidCallback onChangeNumber;

  @override
  State<_CodeHelpSheet> createState() => _CodeHelpSheetState();
}

class _CodeHelpSheetState extends State<_CodeHelpSheet> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Widget _tip(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AarastV3Color.textMuted),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: JourneyType.of(15))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seconds = widget.resendSeconds();
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        children: [
          Semantics(
            header: true,
            child: Text(
              'الرمز ما وصل؟',
              style: JourneyType.of(22, weight: JourneyType.bold),
            ),
          ),
          Text(
            'نرسله على واتساب فقط، وهذا اللي تقدر تسويه',
            style: JourneyType.of(14.5, color: AarastV3Color.textMuted),
          ),
          const SizedBox(height: 14),
          JourneyBox(
            child: Column(
              children: [
                _tip(
                  LucideIcons.smartphone,
                  'تأكد إن واتساب شغّال على '
                  '${PhoneNumberUtils.directionalDisplay(widget.phone) ?? ''}',
                ),
                _tip(LucideIcons.wifi, 'تأكد إن النت واصل للجوال'),
                _tip(LucideIcons.archive, 'شوف المحادثات المؤرشفة في واتساب'),
              ],
            ),
          ),
          const SizedBox(height: 14),
          JourneyButton.quiet(
            label: seconds > 0
                ? 'أعد الإرسال بعد ${_clock(seconds)}'
                : 'أعد الإرسال',
            onPressed: seconds > 0 ? null : widget.onResend,
            expand: true,
          ),
          const SizedBox(height: 10),
          JourneyButton.quiet(
            label: 'الدخول بكلمة المرور',
            icon: LucideIcons.lock,
            onPressed: widget.onPassword,
            expand: true,
          ),
          const SizedBox(height: 6),
          Center(
            child: JourneyTextAction(
              label: 'الرقم غلط؟ غيّره',
              color: AarastV3Color.primary,
              onPressed: widget.onChangeNumber,
            ),
          ),
        ],
      ),
    );
  }
}

class _OtpNotice extends StatelessWidget {
  const _OtpNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.canvas,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w900,
          height: 1.4,
        ),
      ),
    );
  }
}

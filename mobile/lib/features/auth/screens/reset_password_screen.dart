import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/contacts/contact_phone_field_suffix.dart';
import '../../../core/network/api_client.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_otp_field.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../data/auth_repository.dart';
import '../widgets/auth_wedding_widgets.dart';

enum _ResetStep { phone, confirm, done }

/// استعادة كلمة المرور — رمز تحقق على رقم الهاتف ثم كلمة مرور جديدة.
/// الخادم لا يكشف وجود الحساب، ويبطل كل الجلسات بعد نجاح الاستعادة.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({this.initialPhone, super.key});

  final String? initialPhone;

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  static const _resendCooldown = 60;

  final _phoneFormKey = GlobalKey<FormState>();
  final _confirmFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _ResetStep _step = _ResetStep.phone;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  AarastOtpFieldState _codeFieldState = AarastOtpFieldState.idle;
  String? _errorMessage;
  String? _otpNoticeMessage;
  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.initialPhone?.trim() ?? '';
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AuthWeddingScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Text(
            'استعادة كلمة المرور',
            textAlign: TextAlign.center,
            style: textTheme.headlineSmall?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w900,
              height: 1.18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            switch (_step) {
              _ResetStep.phone =>
                'أدخل رقم هاتفك وسنرسل لك رمز تحقق لاستعادة حسابك.',
              _ResetStep.confirm =>
                'أدخل الرمز الذي وصلك ثم اختر كلمة مرور جديدة.',
              _ResetStep.done =>
                'تمت الاستعادة بنجاح — ادخل الآن بكلمة مرورك الجديدة.',
            },
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          switch (_step) {
            _ResetStep.phone => _buildPhoneStep(),
            _ResetStep.confirm => _buildConfirmStep(),
            _ResetStep.done => _buildDoneStep(),
          },
          const SizedBox(height: 18),
          if (_step != _ResetStep.done)
            AuthFooterLink(
              prefix: 'تذكرت كلمة المرور؟',
              action: 'تسجيل الدخول',
              onTap: _isSubmitting ? () {} : () => context.go(AppRouter.login),
            ),
        ],
      ),
    );
  }

  Widget _buildPhoneStep() {
    return AuthPanel(
      child: Form(
        key: _phoneFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthTextField(
              controller: _phoneController,
              label: 'رقم الهاتف',
              hint: 'مثال: 77xxxxxxx',
              icon: LucideIcons.phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _requestCode(),
              suffixIcon: ContactPhoneFieldSuffix(controller: _phoneController),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'رقم الهاتف مطلوب';
                }
                if (!isValidYemeniPhoneInput(value)) {
                  return 'رقم الهاتف غير صحيح';
                }
                return null;
              },
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 14),
              AuthInlineError(message: _errorMessage!),
            ],
            const SizedBox(height: 20),
            AarastButton(
              label: 'إرسال رمز الاستعادة',
              icon: LucideIcons.messageSquare,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _requestCode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmStep() {
    // عند نجاح الرمز تتحوّل البطاقة كاملة إلى لوحة ✓ الخضراء
    // قبل الانتقال لخطوة النجاح النهائية.
    return AuthPanel(
      child: AnimatedSwitcher(
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 280),
        child: _codeFieldState == AarastOtpFieldState.success
            ? const AarastOtpSuccessPanel(subtitle: 'تم التحقق من الرمز.')
            : _buildConfirmForm(),
      ),
    );
  }

  Widget _buildConfirmForm() {
    return Form(
      key: _confirmFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_otpNoticeMessage != null) ...[
            _OtpNotice(message: _otpNoticeMessage!),
            const SizedBox(height: 14),
          ],
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'رمز التحقق',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.ink,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          AarastOtpField(
            controller: _codeController,
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
                });
              }
            },
          ),
          const SizedBox(height: 14),
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
                return 'كلمة المرور الجديدة مطلوبة';
              }
              if (value.length < 6) {
                return 'كلمة المرور 6 أحرف على الأقل';
              }
              return null;
            },
          ),
          const SizedBox(height: 14),
          AuthTextField(
            controller: _confirmPasswordController,
            label: 'تأكيد كلمة المرور',
            icon: LucideIcons.lock,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _confirmReset(),
            validator: (value) {
              if (value != _passwordController.text) {
                return 'كلمتا المرور غير متطابقتين';
              }
              return null;
            },
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 14),
            AuthInlineError(message: _errorMessage!),
          ],
          const SizedBox(height: 20),
          AarastButton(
            label: 'تغيير كلمة المرور',
            icon: LucideIcons.rotateCcw,
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : _confirmReset,
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            key: const ValueKey('reset-otp-resend-button'),
            onPressed: _isSubmitting || _resendSeconds > 0
                ? null
                : _requestCodeAgain,
            icon: const Icon(LucideIcons.refreshCw, size: 18),
            label: Text(
              _resendSeconds > 0
                  ? 'إعادة الإرسال خلال $_resendSeconds ث'
                  : 'إعادة إرسال الرمز',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneStep() {
    return AuthPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppTheme.successSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              LucideIcons.checkCircle,
              color: AppTheme.success,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'تم تغيير كلمة المرور',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppTheme.ink,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'أُغلقت كل الجلسات السابقة لحمايتك. ادخل الآن بكلمة مرورك الجديدة.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          AarastButton(
            label: 'تسجيل الدخول',
            icon: LucideIcons.logIn,
            onPressed: () => context.go(AppRouter.login),
          ),
        ],
      ),
    );
  }

  Future<void> _requestCode() async {
    if (_isSubmitting) return;
    if (!_phoneFormKey.currentState!.validate()) return;
    await _sendResetCode(
      onSuccess: () {
        setState(() {
          _step = _ResetStep.confirm;
          _errorMessage = null;
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
        });
      },
    );
  }

  Future<void> _sendResetCode({required VoidCallback onSuccess}) async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
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

  Future<void> _confirmReset() async {
    if (_isSubmitting) return;
    if (_codeController.text.trim().length < 6) {
      setState(() {
        _codeFieldState = AarastOtpFieldState.error;
        _errorMessage = 'رمز التحقق غير مكتمل';
      });
      return;
    }
    if (!_confirmFormKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _codeFieldState = AarastOtpFieldState.idle;
    });
    try {
      await context.read<AuthRepository>().confirmPasswordReset(
        phone: _phoneController.text,
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      _resendTimer?.cancel();
      setState(() => _codeFieldState = AarastOtpFieldState.success);
      await Future<void>.delayed(AarastOtpField.successHold(context));
      if (!mounted) return;
      setState(() => _step = _ResetStep.done);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _codeFieldState = AarastOtpFieldState.error;
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذر تغيير كلمة المرور الآن. حاول مرة أخرى.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
}

class _OtpNotice extends StatelessWidget {
  const _OtpNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.goldSoft,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.gold.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppTheme.ink,
          fontWeight: FontWeight.w800,
          height: 1.45,
        ),
      ),
    );
  }
}

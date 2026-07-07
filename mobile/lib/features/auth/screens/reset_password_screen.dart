import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/contacts/contact_phone_field_suffix.dart';
import '../../../core/network/api_client.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
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
  final _phoneFormKey = GlobalKey<FormState>();
  final _confirmFormKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  _ResetStep _step = _ResetStep.phone;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _devOtpMessage;

  @override
  void initState() {
    super.initState();
    _phoneController.text = widget.initialPhone?.trim() ?? '';
  }

  @override
  void dispose() {
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
          const SizedBox(height: 12),
          const AuthBrandMark(compact: true),
          const SizedBox(height: 26),
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
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _requestCode(),
              suffixIcon: ContactPhoneFieldSuffix(
                controller: _phoneController,
              ),
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
              icon: Icons.sms_rounded,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _requestCode,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmStep() {
    return AuthPanel(
      child: Form(
        key: _confirmFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_devOtpMessage != null) ...[
              _DevOtpNotice(message: _devOtpMessage!),
              const SizedBox(height: 14),
            ],
            AuthTextField(
              controller: _codeController,
              label: 'رمز التحقق',
              hint: 'الرمز المكوّن من 6 أرقام',
              icon: Icons.pin_rounded,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.isEmpty) return 'رمز التحقق مطلوب';
                if (trimmed.length < 4) return 'رمز التحقق غير مكتمل';
                return null;
              },
            ),
            const SizedBox(height: 14),
            AuthTextField(
              controller: _passwordController,
              label: 'كلمة المرور الجديدة',
              icon: Icons.lock_rounded,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              suffixIcon: IconButton(
                tooltip: _obscurePassword
                    ? 'إظهار كلمة المرور'
                    : 'إخفاء كلمة المرور',
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
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
              icon: Icons.lock_outline_rounded,
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
              icon: Icons.lock_reset_rounded,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _confirmReset,
            ),
            const SizedBox(height: 10),
            TextButton.icon(
              onPressed: _isSubmitting ? null : _requestCodeAgain,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('إعادة إرسال الرمز'),
            ),
          ],
        ),
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
              Icons.check_circle_rounded,
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
            icon: Icons.login_rounded,
            onPressed: () => context.go(AppRouter.login),
          ),
        ],
      ),
    );
  }

  Future<void> _requestCode() async {
    if (!_phoneFormKey.currentState!.validate()) return;
    await _sendResetCode(onSuccess: () {
      setState(() {
        _step = _ResetStep.confirm;
        _errorMessage = null;
      });
    });
  }

  Future<void> _requestCodeAgain() async {
    await _sendResetCode(onSuccess: () {
      setState(() => _errorMessage = null);
    });
  }

  Future<void> _sendResetCode({required VoidCallback onSuccess}) async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final result = await context
          .read<AuthRepository>()
          .requestPasswordReset(phone: _phoneController.text);
      if (!mounted) return;
      _devOtpMessage = result.localDevMessage;
      onSuccess();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
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
    if (!_confirmFormKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      await context.read<AuthRepository>().confirmPasswordReset(
        phone: _phoneController.text,
        code: _codeController.text.trim(),
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      setState(() => _step = _ResetStep.done);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } on Object {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'تعذر تغيير كلمة المرور الآن. حاول مرة أخرى.';
      });
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}

class _DevOtpNotice extends StatelessWidget {
  const _DevOtpNotice({required this.message});

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

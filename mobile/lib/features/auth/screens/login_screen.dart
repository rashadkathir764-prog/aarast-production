import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/contacts/contact_phone_field_suffix.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../providers/auth_controller.dart';
import '../widgets/auth_wedding_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final textTheme = Theme.of(context).textTheme;

    return AuthWeddingScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            const AuthBrandMark(compact: true),
            const SizedBox(height: 26),
            Text(
              'تسجيل الدخول',
              textAlign: TextAlign.center,
              style: textTheme.headlineSmall?.copyWith(
                color: AppTheme.dInk,
                fontWeight: FontWeight.w900,
                height: 1.18,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ادخلي بحسابك لمتابعة تنظيم زفافك بسهولة.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppTheme.dInkSoft,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            AuthPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthTextField(
                    controller: _phoneController,
                    label: 'رقم الهاتف',
                    hint: 'مثال: 77xxxxxxx',
                    icon: Icons.phone_rounded,
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
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
                  const SizedBox(height: 14),
                  AuthTextField(
                    controller: _passwordController,
                    label: 'كلمة المرور',
                    icon: Icons.lock_rounded,
                    obscureText: _obscurePassword,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
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
                        return 'كلمة المرور مطلوبة';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'نسيت كلمة المرور؟',
                      style: textTheme.labelMedium?.copyWith(
                        color: AppTheme.dGoldDeep,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (auth.errorMessage != null) ...[
                    const SizedBox(height: 14),
                    AuthInlineError(message: auth.errorMessage!),
                  ],
                  const SizedBox(height: 20),
                  PrimaryActionButton(
                    label: 'تسجيل الدخول',
                    icon: Icons.login_rounded,
                    isLoading: auth.isSubmitting,
                    onPressed: _submit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            AuthFooterLink(
              prefix: 'ليس لديك حساب؟',
              action: 'إنشاء حساب',
              onTap: () {
                if (auth.isSubmitting) return;
                auth.clearError();
                context.go(AppRouter.register);
              },
            ),
            const SizedBox(height: 12),
            Text(
              'أعرسِت يساعدك ترتبين الميزانية، المهام، الديون، والمشاركات من مكان واحد.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: AppTheme.dMuted,
                fontWeight: FontWeight.w700,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    final success = await auth.login(
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
    );

    if (success && mounted) {
      context.go(AppRouter.home);
    }
  }
}

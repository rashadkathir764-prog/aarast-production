import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/auth_form_shell.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../providers/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return AuthFormShell(
      title: 'تسجيل الدخول',
      subtitle: 'ادخل بحسابك لمتابعة تنظيم زواجك بوضوح.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _phoneController,
                textAlign: TextAlign.right,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'رقم الهاتف مطلوب'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                textAlign: TextAlign.right,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة المرور'),
                validator: (value) => value == null || value.isEmpty
                    ? 'كلمة المرور مطلوبة'
                    : null,
              ),
              if (auth.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  auth.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.right,
                ),
              ],
              const SizedBox(height: 20),
              PrimaryActionButton(
                label: 'تسجيل الدخول',
                isLoading: auth.isSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: auth.isSubmitting
                    ? null
                    : () {
                        auth.clearError();
                        context.go(AppRouter.register);
                      },
                child: const Text('ليس لديك حساب؟ إنشاء حساب'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthController>();
    final success = await auth.login(
      phone: _phoneController.text,
      password: _passwordController.text,
    );
    if (success && mounted) {
      context.go(AppRouter.home);
    }
  }
}

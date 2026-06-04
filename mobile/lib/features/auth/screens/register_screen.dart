import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/widgets/auth_form_shell.dart';
import '../../../core/widgets/primary_action_button.dart';
import '../providers/auth_controller.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();

    return AuthFormShell(
      title: 'إنشاء حساب',
      subtitle: 'ابدأ بحساب بسيط، وبعدها نكمل إعداد خطة الزواج.',
      children: [
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                textAlign: TextAlign.right,
                decoration: const InputDecoration(labelText: 'الاسم الكامل'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'الاسم مطلوب'
                    : null,
              ),
              const SizedBox(height: 14),
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
                controller: _emailController,
                textAlign: TextAlign.right,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني اختياري',
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordController,
                textAlign: TextAlign.right,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'كلمة المرور'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'كلمة المرور مطلوبة';
                  }
                  if (value.length < 6) {
                    return 'كلمة المرور يجب أن تكون 6 أحرف على الأقل';
                  }
                  return null;
                },
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
                label: 'إنشاء حساب',
                isLoading: auth.isSubmitting,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: auth.isSubmitting
                    ? null
                    : () {
                        auth.clearError();
                        context.go(AppRouter.login);
                      },
                child: const Text('لديك حساب بالفعل؟ تسجيل الدخول'),
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
    final success = await auth.register(
      name: _nameController.text,
      phone: _phoneController.text,
      email: _emailController.text,
      password: _passwordController.text,
    );
    if (success && mounted) {
      context.go(AppRouter.home);
    }
  }
}

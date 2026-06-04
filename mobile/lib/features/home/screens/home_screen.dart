import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/providers/auth_controller.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final user = auth.user;

    return Scaffold(
      appBar: AppBar(
        title: const Text('اعّرست'),
        actions: [
          TextButton(
            onPressed: () async {
              await context.read<AuthController>().logout();
              if (context.mounted) context.go(AppRouter.login);
            },
            child: const Text('تسجيل الخروج'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'تم تسجيل الدخول بنجاح',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.deepBurgundy,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        user?.name ?? 'مستخدم اعّرست',
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.right,
                      ),
                      if (user?.phone != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          user!.phone!,
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.right,
                        ),
                      ],
                      const SizedBox(height: 16),
                      const Text(
                        'هذه شاشة مؤقتة لتأكيد جاهزية تسجيل الدخول فقط. شاشة لوحة التحكم وخطة الزواج ستأتي في المرحلة التالية.',
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

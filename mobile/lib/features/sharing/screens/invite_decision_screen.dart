import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/shared_member.dart';
import '../providers/sharing_provider.dart';

class InviteDecisionScreen extends StatefulWidget {
  const InviteDecisionScreen({required this.token, super.key});

  final String token;

  @override
  State<InviteDecisionScreen> createState() => _InviteDecisionScreenState();
}

class _InviteDecisionScreenState extends State<InviteDecisionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SharingProvider>().loadInvite(widget.token);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SharingProvider>();
    final invite = provider.selectedInvite;
    return AarastPageScaffold(
      title: 'دعوة مشاركة',
      subtitle: 'راجع الخطة والدور قبل القبول أو الرفض.',
      child: _body(provider, invite),
    );
  }

  Widget _body(SharingProvider provider, PlanInvite? invite) {
    if (provider.isLoading && invite == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (provider.errorMessage != null && invite == null) {
      return AarastEmptyState(
        icon: Icons.error_outline,
        title: 'تعذر فتح الدعوة',
        message: provider.errorMessage!,
      );
    }
    if (invite == null) {
      return const AarastEmptyState(
        icon: Icons.mark_email_unread_outlined,
        title: 'الدعوة غير متاحة',
        message: 'قد تكون الدعوة منتهية أو ملغاة.',
      );
    }

    return ListView(
      children: [
        AarastCard(
          color: AppTheme.ivory,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                invite.weddingPlanTitle ?? 'خطة زفاف مشتركة',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppTheme.ink,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'الدور: ${sharedMemberRoleLabel(invite.role)}',
                style: const TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'البيانات المالية لا تظهر إلا إذا كانت صلاحيات الدعوة تسمح بذلك.',
                style: TextStyle(
                  color: AppTheme.muted,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (invite.isPending)
          Row(
            children: [
              Expanded(
                child: AarastButton(
                  label: 'رفض الدعوة',
                  variant: AarastButtonVariant.secondary,
                  onPressed: provider.isSubmitting
                      ? null
                      : () => _respond(provider, accept: false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AarastButton(
                  label: 'قبول الدعوة',
                  onPressed: provider.isSubmitting
                      ? null
                      : () => _respond(provider, accept: true),
                ),
              ),
            ],
          )
        else
          AarastEmptyState(
            icon: invite.status == 'ACCEPTED'
                ? Icons.check_circle_outline
                : Icons.info_outline,
            title: invite.status == 'ACCEPTED'
                ? 'تم قبول الدعوة'
                : 'تم إغلاق الدعوة',
            message: 'حالة الدعوة الحالية: ${invite.status}',
          ),
      ],
    );
  }

  Future<void> _respond(
    SharingProvider provider, {
    required bool accept,
  }) async {
    final ok = await provider.respondToInvite(widget.token, accept: accept);
    if (!mounted || !ok) return;
    final invite = provider.selectedInvite;
    if (accept && invite != null) {
      context.go(AppRouter.planCenter(invite.weddingPlanId));
    }
  }
}

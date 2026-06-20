import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../providers/sharing_provider.dart';
import '../widgets/shared_member_card.dart';

class SharingScreen extends StatefulWidget {
  const SharingScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<SharingScreen> createState() => _SharingScreenState();
}

class _SharingScreenState extends State<SharingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<SharingProvider>().loadMembers(widget.weddingPlanId);
    });
  }

  @override
  void didUpdateWidget(covariant SharingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.weddingPlanId != widget.weddingPlanId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<SharingProvider>().loadMembers(widget.weddingPlanId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SharingProvider>();

    return AarastPageScaffold(
      title: 'المشاركة والصلاحيات',
      subtitle: 'شارك الخطة وحدد ما يمكن لكل عضو رؤيته أو إدارته',
      showBack: true,
      child: RefreshIndicator(
        color: AppTheme.dMaroon,
        onRefresh: () => provider.loadMembers(widget.weddingPlanId),
        child: _SharingContent(
          provider: provider,
          weddingPlanId: widget.weddingPlanId,
        ),
      ),
    );
  }
}

class _SharingContent extends StatelessWidget {
  const _SharingContent({required this.provider, required this.weddingPlanId});

  final SharingProvider provider;
  final String weddingPlanId;

  @override
  Widget build(BuildContext context) {
    if (provider.isLoading && provider.members.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && provider.members.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: 120),
          Text(
            provider.errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => provider.loadMembers(weddingPlanId),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      );
    }

    return ListView(
      children: [
        const _PrivacyNotice(),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: provider.isSubmitting
              ? null
              : () => context.push(AppRouter.addSharedMember(weddingPlanId)),
          icon: const Icon(Icons.person_add),
          label: const Text('إضافة عضو'),
        ),
        if (provider.errorMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            provider.errorMessage!,
            textAlign: TextAlign.right,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 18),
        Text(
          'الأعضاء المشاركون',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.deepBurgundy,
            fontWeight: FontWeight.w800,
          ),
          textAlign: TextAlign.right,
        ),
        if (provider.members.isEmpty) ...[
          const SizedBox(height: 10),
          const AarastEmptyState(
            icon: Icons.group_add_outlined,
            title: 'الخطة خاصة بك الآن',
            message: 'أضف شخصًا موثوقًا وحدد صلاحياته بوضوح.',
          ),
        ],
        const SizedBox(height: 8),
        for (final member in provider.members)
          SharedMemberCard(
            member: member,
            onTap: () {
              provider.selectMember(member);
              context.push(AppRouter.editSharedMember(member.id));
            },
          ),
      ],
    );
  }
}

class _PrivacyNotice extends StatelessWidget {
  const _PrivacyNotice();

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.dCreamBg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'إدارة الخصوصية',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.deepBurgundy,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.right,
          ),
          const SizedBox(height: 8),
          const Text(
            'هذه الشاشة مخصصة لمالك الخطة. البيانات المالية مثل الميزانية والمصاريف والديون لا تظهر للأعضاء إلا بصلاحية واضحة.',
            textAlign: TextAlign.right,
          ),
        ],
      ),
    );
  }
}

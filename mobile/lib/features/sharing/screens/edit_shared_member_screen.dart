import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../models/shared_member.dart';
import '../providers/sharing_provider.dart';

class EditSharedMemberScreen extends StatefulWidget {
  const EditSharedMemberScreen({required this.sharedMemberId, super.key});

  final String sharedMemberId;

  @override
  State<EditSharedMemberScreen> createState() => _EditSharedMemberScreenState();
}

class _EditSharedMemberScreenState extends State<EditSharedMemberScreen> {
  String _role = 'VIEWER';
  bool _canViewBudget = false;
  bool _canViewExpenses = false;
  bool _canViewDebts = false;
  bool _canManageTasks = false;
  bool _canManageFinancialRecords = false;
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SharingProvider>();
    final member =
        provider.selectedMember ?? provider.findMember(widget.sharedMemberId);

    if (member == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تعديل عضو المشاركة')),
        body: const SafeArea(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                'افتح العضو من شاشة المشاركة حتى يمكن تعديل صلاحياته.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );
    }

    if (!_initialized) {
      _syncFromMember(member);
    }
    final subtitle = member.displaySubtitle;

    return Scaffold(
      appBar: AppBar(title: const Text('تعديل عضو المشاركة')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'العضو: ${member.displayName}',
                      textAlign: TextAlign.right,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'الدور'),
              items: const [
                DropdownMenuItem(value: 'VIEWER', child: Text('مشاهد')),
                DropdownMenuItem(value: 'CONTRIBUTOR', child: Text('مساهم')),
                DropdownMenuItem(value: 'MANAGER', child: Text('مدير')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _role = value);
                }
              },
            ),
            const SizedBox(height: 12),
            Card(
              child: Column(
                children: [
                  SwitchListTile(
                    value: _canViewBudget,
                    onChanged: (value) =>
                        setState(() => _canViewBudget = value),
                    title: const Text(
                      'يمكنه رؤية الميزانية',
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SwitchListTile(
                    value: _canViewExpenses,
                    onChanged: (value) =>
                        setState(() => _canViewExpenses = value),
                    title: const Text(
                      'يمكنه رؤية المصاريف',
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SwitchListTile(
                    value: _canViewDebts,
                    onChanged: (value) => setState(() => _canViewDebts = value),
                    title: const Text(
                      'يمكنه رؤية الديون والأقساط',
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SwitchListTile(
                    value: _canManageTasks,
                    onChanged: (value) =>
                        setState(() => _canManageTasks = value),
                    title: const Text(
                      'يمكنه إدارة المهام',
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SwitchListTile(
                    value: _canManageFinancialRecords,
                    onChanged: (value) =>
                        setState(() => _canManageFinancialRecords = value),
                    title: const Text(
                      'يمكنه إدارة السجلات المالية',
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
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
            ElevatedButton(
              onPressed: provider.isSubmitting ? null : () => _save(member),
              child: const Text('حفظ التغييرات'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: provider.isSubmitting
                  ? null
                  : () => _confirmRemove(member),
              icon: const Icon(Icons.delete_outline),
              label: const Text('إزالة العضو'),
            ),
          ],
        ),
      ),
    );
  }

  void _syncFromMember(SharedMember member) {
    _role = member.role;
    _canViewBudget = member.canViewBudget;
    _canViewExpenses = member.canViewExpenses;
    _canViewDebts = member.canViewDebts;
    _canManageTasks = member.canManageTasks;
    _canManageFinancialRecords = member.canManageFinancialRecords;
    _initialized = true;
  }

  Future<void> _save(SharedMember member) async {
    final provider = context.read<SharingProvider>();
    final updated = await provider.updateMember(
      id: member.id,
      role: _role,
      canViewBudget: _canViewBudget,
      canViewExpenses: _canViewExpenses,
      canViewDebts: _canViewDebts,
      canManageTasks: _canManageTasks,
      canManageFinancialRecords: _canManageFinancialRecords,
    );

    if (!mounted) {
      return;
    }

    if (updated) {
      context.go(AppRouter.sharing(member.weddingPlanId));
    }
  }

  Future<void> _confirmRemove(SharedMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إزالة العضو'),
        content: const Text('هل تريد إزالة هذا العضو من الخطة؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('إزالة'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    if (!mounted) {
      return;
    }

    final provider = context.read<SharingProvider>();
    final removed = await provider.removeMember(member.id);

    if (!mounted) {
      return;
    }

    if (removed) {
      context.go(AppRouter.sharing(member.weddingPlanId));
    }
  }
}

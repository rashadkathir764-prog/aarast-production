import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/routing/app_router.dart';
import '../providers/sharing_provider.dart';

class AddSharedMemberScreen extends StatefulWidget {
  const AddSharedMemberScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<AddSharedMemberScreen> createState() => _AddSharedMemberScreenState();
}

class _AddSharedMemberScreenState extends State<AddSharedMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _userIdController = TextEditingController();
  String _role = 'VIEWER';
  bool _canViewBudget = false;
  bool _canViewExpenses = false;
  bool _canViewDebts = false;
  bool _canManageTasks = false;
  bool _canManageFinancialRecords = false;

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SharingProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('إضافة عضو مشاركة')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _PrivacyHint(),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _userIdController,
                    textAlign: TextAlign.right,
                    decoration: const InputDecoration(
                      labelText: 'معرف المستخدم',
                      helperText: 'أدخل userId للعضو المراد إضافته.',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'معرف المستخدم مطلوب';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _RoleDropdown(
                    value: _role,
                    onChanged: (value) => setState(() => _role = value),
                  ),
                  const SizedBox(height: 12),
                  _PermissionSwitches(
                    canViewBudget: _canViewBudget,
                    canViewExpenses: _canViewExpenses,
                    canViewDebts: _canViewDebts,
                    canManageTasks: _canManageTasks,
                    canManageFinancialRecords: _canManageFinancialRecords,
                    onViewBudgetChanged: (value) =>
                        setState(() => _canViewBudget = value),
                    onViewExpensesChanged: (value) =>
                        setState(() => _canViewExpenses = value),
                    onViewDebtsChanged: (value) =>
                        setState(() => _canViewDebts = value),
                    onManageTasksChanged: (value) =>
                        setState(() => _canManageTasks = value),
                    onManageFinancialRecordsChanged: (value) =>
                        setState(() => _canManageFinancialRecords = value),
                  ),
                  if (provider.errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  ElevatedButton(
                    onPressed: provider.isSubmitting ? null : _submit,
                    child: provider.isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('إضافة العضو'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final provider = context.read<SharingProvider>();
    final created = await provider.createMember(
      weddingPlanId: widget.weddingPlanId,
      userId: _userIdController.text,
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

    if (created) {
      context.go(AppRouter.sharing(widget.weddingPlanId));
    }
  }
}

class _RoleDropdown extends StatelessWidget {
  const _RoleDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'الدور'),
      items: const [
        DropdownMenuItem(value: 'VIEWER', child: Text('مشاهد')),
        DropdownMenuItem(value: 'CONTRIBUTOR', child: Text('مساهم')),
        DropdownMenuItem(value: 'MANAGER', child: Text('مدير')),
      ],
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

class _PermissionSwitches extends StatelessWidget {
  const _PermissionSwitches({
    required this.canViewBudget,
    required this.canViewExpenses,
    required this.canViewDebts,
    required this.canManageTasks,
    required this.canManageFinancialRecords,
    required this.onViewBudgetChanged,
    required this.onViewExpensesChanged,
    required this.onViewDebtsChanged,
    required this.onManageTasksChanged,
    required this.onManageFinancialRecordsChanged,
  });

  final bool canViewBudget;
  final bool canViewExpenses;
  final bool canViewDebts;
  final bool canManageTasks;
  final bool canManageFinancialRecords;
  final ValueChanged<bool> onViewBudgetChanged;
  final ValueChanged<bool> onViewExpensesChanged;
  final ValueChanged<bool> onViewDebtsChanged;
  final ValueChanged<bool> onManageTasksChanged;
  final ValueChanged<bool> onManageFinancialRecordsChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            value: canViewBudget,
            onChanged: onViewBudgetChanged,
            title: const Text(
              'يمكنه رؤية الميزانية',
              textAlign: TextAlign.right,
            ),
          ),
          SwitchListTile(
            value: canViewExpenses,
            onChanged: onViewExpensesChanged,
            title: const Text(
              'يمكنه رؤية المصاريف',
              textAlign: TextAlign.right,
            ),
          ),
          SwitchListTile(
            value: canViewDebts,
            onChanged: onViewDebtsChanged,
            title: const Text(
              'يمكنه رؤية الديون والأقساط',
              textAlign: TextAlign.right,
            ),
          ),
          SwitchListTile(
            value: canManageTasks,
            onChanged: onManageTasksChanged,
            title: const Text('يمكنه إدارة المهام', textAlign: TextAlign.right),
          ),
          SwitchListTile(
            value: canManageFinancialRecords,
            onChanged: onManageFinancialRecordsChanged,
            title: const Text(
              'يمكنه إدارة السجلات المالية',
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyHint extends StatelessWidget {
  const _PrivacyHint();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Text(
          'فعّل الصلاحيات المالية فقط عند الحاجة. الخصوصية المالية هي الوضع الافتراضي.',
          textAlign: TextAlign.right,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/contacts/contact_phone_field_suffix.dart';
import '../../../core/phone/yemeni_phone_normalizer.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/aarast_ui.dart';
import '../models/shared_member.dart';
import '../providers/sharing_provider.dart';

class AddSharedMemberScreen extends StatefulWidget {
  const AddSharedMemberScreen({required this.weddingPlanId, super.key});

  final String weddingPlanId;

  @override
  State<AddSharedMemberScreen> createState() => _AddSharedMemberScreenState();
}

class _AddSharedMemberScreenState extends State<AddSharedMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  String _role = 'VIEWER';
  bool _canViewBudget = false;
  bool _canViewExpenses = false;
  bool _canViewDebts = false;
  bool _canManageTasks = true;
  bool _canManageFinancialRecords = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SharingProvider>();
    final foundUser = provider.lookupUser;

    return AarastPageScaffold(
      title: 'إضافة عضو',
      subtitle: 'ابحثي برقم الهاتف ثم حددي الصلاحيات قبل المشاركة.',
      resizeToAvoidBottomInset: true,
      actions: [
        IconButton(
          onPressed: () {
            if (context.canPop()) context.pop();
          },
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
      child: Form(
        key: _formKey,
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            const _PrivacyHint(),
            const SizedBox(height: 14),
            _PhoneLookupCard(
              controller: _phoneController,
              isLookingUp: provider.isLookingUp,
              errorMessage: provider.lookupErrorMessage,
              foundUser: foundUser,
              onChanged: (_) => provider.clearLookup(),
              onLookup: _lookupUser,
            ),
            const SizedBox(height: 14),
            _RoleDropdown(
              value: _role,
              onChanged: (value) => setState(() => _role = value),
            ),
            const SizedBox(height: 14),
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
              _InlineError(message: provider.errorMessage!),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: provider.isSubmitting || foundUser == null
                  ? null
                  : _submit,
              icon: provider.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('إضافة العضو'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _lookupUser() async {
    if (!_formKey.currentState!.validate()) return;
    await context.read<SharingProvider>().lookupUserByPhone(
      _phoneController.text,
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<SharingProvider>();
    final foundUser = provider.lookupUser;
    if (foundUser == null) {
      await provider.lookupUserByPhone(_phoneController.text);
      if (!mounted || provider.lookupUser == null) return;
    }

    final created = await provider.createMember(
      weddingPlanId: widget.weddingPlanId,
      userId: provider.lookupUser?.id ?? foundUser?.id,
      role: _role,
      canViewBudget: _canViewBudget,
      canViewExpenses: _canViewExpenses,
      canViewDebts: _canViewDebts,
      canManageTasks: _canManageTasks,
      canManageFinancialRecords: _canManageFinancialRecords,
    );

    if (!mounted) return;

    if (created) {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go(AppRouter.sharing(widget.weddingPlanId));
      }
    }
  }
}

class _PhoneLookupCard extends StatelessWidget {
  const _PhoneLookupCard({
    required this.controller,
    required this.isLookingUp,
    required this.onChanged,
    required this.onLookup,
    this.errorMessage,
    this.foundUser,
  });

  final TextEditingController controller;
  final bool isLookingUp;
  final String? errorMessage;
  final SharedUserLookup? foundUser;
  final ValueChanged<String> onChanged;
  final VoidCallback onLookup;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.dCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastSectionHeader(
            title: 'البحث عن العضو',
            icon: Icons.phone_iphone_rounded,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: controller,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.search,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            onChanged: onChanged,
            onFieldSubmitted: (_) => onLookup(),
            decoration: InputDecoration(
              labelText: 'رقم هاتف العضو',
              hintText: 'مثال: 77xxxxxxx',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: isLookingUp
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : ContactPhoneFieldSuffix(
                      controller: controller,
                      onPhoneSelected: onChanged,
                    ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'رقم هاتف العضو مطلوب';
              }
              if (!isValidYemeniPhoneInput(value)) {
                return 'أدخلي رقم هاتف صحيح';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isLookingUp ? null : onLookup,
            icon: const Icon(Icons.manage_search_rounded),
            label: const Text('بحث عن المستخدم'),
          ),
          if (foundUser != null) ...[
            const SizedBox(height: 14),
            _FoundUserCard(user: foundUser!),
          ] else if (errorMessage != null) ...[
            const SizedBox(height: 14),
            _LookupEmpty(message: errorMessage!),
          ],
        ],
      ),
    );
  }
}

class _FoundUserCard extends StatelessWidget {
  const _FoundUserCard({required this.user});

  final SharedUserLookup user;

  @override
  Widget build(BuildContext context) {
    final phone = user.phone?.trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dGreenBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dGreen.withAlpha(50)),
      ),
      child: Row(
        children: [
          _LookupAvatar(user: user),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AarastStatusPill(
                  label: 'مستخدم مسجل',
                  icon: Icons.verified_rounded,
                  color: AppTheme.dGreen,
                  backgroundColor: Colors.white,
                ),
                const SizedBox(height: 8),
                Text(
                  user.name.trim().isEmpty ? 'عضو أعرست' : user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppTheme.dInk,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (phone != null && phone.isNotEmpty)
                  Text(
                    phone,
                    textDirection: TextDirection.ltr,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.dInkSoft,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LookupAvatar extends StatelessWidget {
  const _LookupAvatar({required this.user});

  final SharedUserLookup user;

  @override
  Widget build(BuildContext context) {
    final imageUrl = user.avatarUrl?.trim();
    final initial = user.name.trim().isEmpty ? 'ع' : user.name.trim()[0];

    return ClipOval(
      child: Container(
        width: 54,
        height: 54,
        color: AppTheme.dCard,
        child: imageUrl == null || imageUrl.isEmpty
            ? Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: AppTheme.dMaroon,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              )
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: AppTheme.dMaroon,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _LookupEmpty extends StatelessWidget {
  const _LookupEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.dCreamBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.dGold.withAlpha(60)),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.dGoldDeep),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.dInk,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleDropdown extends StatelessWidget {
  const _RoleDropdown({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.dCard,
      child: DropdownButtonFormField<String>(
        initialValue: value,
        decoration: const InputDecoration(
          labelText: 'الدور',
          prefixIcon: Icon(Icons.admin_panel_settings_outlined),
        ),
        items: const [
          DropdownMenuItem(value: 'VIEWER', child: Text('مشاهد')),
          DropdownMenuItem(value: 'CONTRIBUTOR', child: Text('مساهم')),
          DropdownMenuItem(value: 'MANAGER', child: Text('مدير')),
        ],
        onChanged: (value) {
          if (value != null) onChanged(value);
        },
      ),
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
    return AarastCard(
      color: AppTheme.dCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AarastSectionHeader(
            title: 'الصلاحيات',
            icon: Icons.privacy_tip_outlined,
          ),
          const SizedBox(height: 8),
          _PermissionTile(
            value: canManageTasks,
            onChanged: onManageTasksChanged,
            title: 'إدارة المهام',
            subtitle: 'إضافة وتعديل مهام الخطة.',
            icon: Icons.checklist_rtl_rounded,
          ),
          _PermissionTile(
            value: canViewBudget,
            onChanged: onViewBudgetChanged,
            title: 'عرض الميزانية',
            subtitle: 'إظهار ملخص الميزانية فقط.',
            icon: Icons.account_balance_wallet_outlined,
          ),
          _PermissionTile(
            value: canViewExpenses,
            onChanged: onViewExpensesChanged,
            title: 'عرض المصاريف',
            subtitle: 'السماح بقراءة المصاريف المسجلة.',
            icon: Icons.receipt_long_outlined,
          ),
          _PermissionTile(
            value: canViewDebts,
            onChanged: onViewDebtsChanged,
            title: 'عرض الديون والأقساط',
            subtitle: 'بيانات مالية خاصة، فعليها عند الحاجة فقط.',
            icon: Icons.credit_card_rounded,
          ),
          _PermissionTile(
            value: canManageFinancialRecords,
            onChanged: onManageFinancialRecordsChanged,
            title: 'إدارة السجلات المالية',
            subtitle: 'إضافة وتعديل المصاريف والديون.',
            icon: Icons.edit_note_rounded,
          ),
        ],
      ),
    );
  }
}

class _PermissionTile extends StatelessWidget {
  const _PermissionTile({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      value: value,
      onChanged: onChanged,
      secondary: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: value ? AppTheme.dPinkBg : AppTheme.dCard2,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(
          icon,
          color: value ? AppTheme.dMaroon : AppTheme.dInkSoft,
          size: 21,
        ),
      ),
      title: Text(
        title,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: AppTheme.dInk,
          fontWeight: FontWeight.w900,
        ),
      ),
      subtitle: Text(
        subtitle,
        textAlign: TextAlign.right,
        style: const TextStyle(
          color: AppTheme.dInkSoft,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PrivacyHint extends StatelessWidget {
  const _PrivacyHint();

  @override
  Widget build(BuildContext context) {
    return const AarastCard(
      color: AppTheme.dCreamBg,
      child: Row(
        children: [
          Icon(Icons.lock_outline_rounded, color: AppTheme.dGoldDeep),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'الخصوصية المالية مغلقة افتراضياً. فعلي صلاحيات الميزانية والمصاريف والديون فقط للعضو المناسب.',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: AppTheme.dInk,
                fontWeight: FontWeight.w800,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AarastCard(
      color: AppTheme.dPinkBg,
      border: Border.all(color: AppTheme.danger.withAlpha(50)),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTheme.danger,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

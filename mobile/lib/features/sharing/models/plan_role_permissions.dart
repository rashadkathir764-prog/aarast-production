class PlanRolePermissions {
  const PlanRolePermissions({
    required this.canViewMoney,
    required this.canManageMoney,
    required this.canEditPlan,
    required this.canManageTasks,
    required this.canManageGuests,
    required this.canManageProviders,
    required this.canInviteMembers,
    required this.receiveNotifications,
  });

  factory PlanRolePermissions.forRole(String role) {
    switch (role) {
      case 'GROOM':
      case 'BRIDE':
        return const PlanRolePermissions(
          canViewMoney: true,
          canManageMoney: true,
          canEditPlan: true,
          canManageTasks: true,
          canManageGuests: true,
          canManageProviders: true,
          canInviteMembers: false,
          receiveNotifications: true,
        );
      case 'FAMILY':
        return const PlanRolePermissions(
          canViewMoney: false,
          canManageMoney: false,
          canEditPlan: false,
          canManageTasks: true,
          canManageGuests: true,
          canManageProviders: false,
          canInviteMembers: false,
          receiveNotifications: true,
        );
      case 'HELPER':
        return const PlanRolePermissions(
          canViewMoney: false,
          canManageMoney: false,
          canEditPlan: false,
          canManageTasks: true,
          canManageGuests: true,
          canManageProviders: true,
          canInviteMembers: false,
          receiveNotifications: true,
        );
      default:
        return const PlanRolePermissions(
          canViewMoney: false,
          canManageMoney: false,
          canEditPlan: false,
          canManageTasks: false,
          canManageGuests: false,
          canManageProviders: false,
          canInviteMembers: false,
          receiveNotifications: true,
        );
    }
  }

  final bool canViewMoney;
  final bool canManageMoney;
  final bool canEditPlan;
  final bool canManageTasks;
  final bool canManageGuests;
  final bool canManageProviders;
  final bool canInviteMembers;
  final bool receiveNotifications;

  bool get hasFinancialAccess => canViewMoney;

  PlanRolePermissions copyWith({
    bool? canViewMoney,
    bool? canManageMoney,
    bool? canEditPlan,
    bool? canManageTasks,
    bool? canManageGuests,
    bool? canManageProviders,
    bool? canInviteMembers,
    bool? receiveNotifications,
  }) {
    final manageMoney = canManageMoney ?? this.canManageMoney;
    return PlanRolePermissions(
      canViewMoney: manageMoney || (canViewMoney ?? this.canViewMoney),
      canManageMoney: manageMoney,
      canEditPlan: canEditPlan ?? this.canEditPlan,
      canManageTasks: canManageTasks ?? this.canManageTasks,
      canManageGuests: canManageGuests ?? this.canManageGuests,
      canManageProviders: canManageProviders ?? this.canManageProviders,
      canInviteMembers: canInviteMembers ?? this.canInviteMembers,
      receiveNotifications: receiveNotifications ?? this.receiveNotifications,
    );
  }

  String get summaryLabel {
    final manage = <String>[
      if (canManageTasks) 'المهام',
      if (canManageGuests) 'الضيوف',
      if (canManageProviders) 'المزودين',
      if (canEditPlan) 'تعديل الخطة',
      if (canInviteMembers) 'الدعوات',
    ];
    final managePart = manage.isEmpty
        ? 'عرض فقط'
        : manage.length <= 2
        ? manage.join(' و')
        : '${manage.take(2).join(' و')} +${manage.length - 2}';
    final moneyPart = canManageMoney
        ? 'يدير المال'
        : canViewMoney
        ? 'يشاهد المال'
        : 'بلا وصول مالي';
    return '$managePart · $moneyPart';
  }
}

class PlanAccessPermissions {
  const PlanAccessPermissions({
    required this.weddingPlanId,
    required this.isOwner,
    required this.canViewMoney,
    required this.canManageMoney,
    this.canManageMembers = false,
  });

  const PlanAccessPermissions.owner({required String weddingPlanId})
    : this(
        weddingPlanId: weddingPlanId,
        isOwner: true,
        canViewMoney: true,
        canManageMoney: true,
        canManageMembers: true,
      );

  const PlanAccessPermissions.denied({required String weddingPlanId})
    : this(
        weddingPlanId: weddingPlanId,
        isOwner: false,
        canViewMoney: false,
        canManageMoney: false,
        canManageMembers: false,
      );

  factory PlanAccessPermissions.fromJson(Map<String, dynamic> json) {
    final canManage = json['canManageMoney'] == true;
    return PlanAccessPermissions(
      weddingPlanId: json['weddingPlanId']?.toString() ?? '',
      isOwner: json['isOwner'] == true,
      canViewMoney: json['canViewMoney'] == true || canManage,
      canManageMoney: canManage,
      canManageMembers: json['canManageMembers'] == true,
    );
  }

  final String weddingPlanId;
  final bool isOwner;
  final bool canViewMoney;
  final bool canManageMoney;
  final bool canManageMembers;

  bool get hasAnyFinanceAccess => canViewMoney;
}

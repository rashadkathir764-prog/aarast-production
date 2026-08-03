import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';

Map<String, dynamic> accountContextJson({
  required AccountContextRole role,
  String planId = 'plan-1',
  String providerId = 'provider-1',
  String? membershipId,
  int membershipAuthorityVersion = 1,
  String? displayName,
  String? lifecycle,
  AccountContextPersona? persona,
  AccountContextAccessMode? accessMode,
  bool isAvailable = true,
  String? unavailableReason,
}) {
  final isProvider = role == AccountContextRole.provider;
  final resolvedLifecycle = lifecycle ?? (isProvider ? 'ACTIVE' : 'PLANNING');
  final resolvedAccessMode =
      accessMode ??
      (resolvedLifecycle == 'PLANNING' || resolvedLifecycle == 'ACTIVE'
          ? AccountContextAccessMode.full
          : AccountContextAccessMode.readOnly);
  final roleSuffix = switch (role) {
    AccountContextRole.owner => 'owner',
    AccountContextRole.contributor => 'contributor',
    AccountContextRole.provider => null,
  };
  final canManageProvider =
      isProvider &&
      resolvedLifecycle != 'SUSPENDED' &&
      resolvedLifecycle != 'REJECTED';
  final canUseProvider = isProvider && resolvedLifecycle == 'ACTIVE';

  return {
    'contextKey': isProvider
        ? 'provider:$providerId'
        : 'plan:$planId:$roleSuffix',
    'role': role.name.toUpperCase(),
    'weddingPlanId': isProvider ? null : planId,
    'providerId': isProvider ? providerId : null,
    'membershipId': role == AccountContextRole.contributor
        ? membershipId ?? 'member-$planId'
        : null,
    'membershipAuthorityVersion': role == AccountContextRole.contributor
        ? membershipAuthorityVersion
        : null,
    'persona': isProvider ? null : persona?.name.toUpperCase(),
    'displayName':
        displayName ?? (isProvider ? 'Provider $providerId' : 'Plan $planId'),
    'lifecycle': resolvedLifecycle,
    'accessMode': resolvedAccessMode.name
        .replaceAllMapped(RegExp(r'[A-Z]'), (match) => '_${match.group(0)}')
        .toUpperCase(),
    'capabilities': {
      'canViewProviderProfile': isProvider,
      'canManageProviderProfile': canManageProvider,
      'canUseProviderOperations': canUseProvider,
    },
    'permissions': {
      'canViewPlan': !isProvider,
      'canEditPlan': role == AccountContextRole.owner && isAvailable,
      'canManageTasks': !isProvider && isAvailable,
      'canManageGuests': !isProvider && isAvailable,
      'canManageProviders': role == AccountContextRole.owner && isAvailable,
      'canInviteMembers': role == AccountContextRole.owner && isAvailable,
      'canViewMoney': role == AccountContextRole.owner,
      'canManageMoney': role == AccountContextRole.owner && isAvailable,
      'canManageProviderProfile': canManageProvider,
    },
    'isAvailable': isAvailable,
    'unavailableReason': unavailableReason,
  };
}

AccountContext accountContext({
  required AccountContextRole role,
  String planId = 'plan-1',
  String providerId = 'provider-1',
  String? membershipId,
  int membershipAuthorityVersion = 1,
  String? displayName,
  String? lifecycle,
  AccountContextPersona? persona,
  AccountContextAccessMode? accessMode,
  bool isAvailable = true,
  String? unavailableReason,
}) {
  return AccountContext.fromJson(
    accountContextJson(
      role: role,
      planId: planId,
      providerId: providerId,
      membershipId: membershipId,
      membershipAuthorityVersion: membershipAuthorityVersion,
      displayName: displayName,
      lifecycle: lifecycle,
      persona: persona,
      accessMode: accessMode,
      isAvailable: isAvailable,
      unavailableReason: unavailableReason,
    ),
  );
}

enum AccountContextRole { owner, contributor, provider }

enum AccountContextAccessMode { full, limited, readOnly }

enum AccountContextPersona { groom, bride, helper }

class AccountContextCapabilities {
  const AccountContextCapabilities({
    required this.canViewProviderProfile,
    required this.canManageProviderProfile,
    required this.canUseProviderOperations,
  });

  factory AccountContextCapabilities.fromJson(Map<String, dynamic> json) {
    return AccountContextCapabilities(
      canViewProviderProfile: _requiredBool(json, 'canViewProviderProfile'),
      canManageProviderProfile: _requiredBool(json, 'canManageProviderProfile'),
      canUseProviderOperations: _requiredBool(json, 'canUseProviderOperations'),
    );
  }

  final bool canViewProviderProfile;
  final bool canManageProviderProfile;
  final bool canUseProviderOperations;

  Map<String, dynamic> toJson() => {
    'canViewProviderProfile': canViewProviderProfile,
    'canManageProviderProfile': canManageProviderProfile,
    'canUseProviderOperations': canUseProviderOperations,
  };
}

class AccountContextPermissions {
  const AccountContextPermissions({
    required this.canViewPlan,
    required this.canEditPlan,
    required this.canManageTasks,
    required this.canManageGuests,
    required this.canManageProviders,
    required this.canInviteMembers,
    required this.canViewMoney,
    required this.canManageMoney,
    required this.canManageProviderProfile,
  });

  factory AccountContextPermissions.fromJson(Map<String, dynamic> json) {
    return AccountContextPermissions(
      canViewPlan: _requiredBool(json, 'canViewPlan'),
      canEditPlan: _requiredBool(json, 'canEditPlan'),
      canManageTasks: _requiredBool(json, 'canManageTasks'),
      canManageGuests: _requiredBool(json, 'canManageGuests'),
      canManageProviders: _requiredBool(json, 'canManageProviders'),
      canInviteMembers: _requiredBool(json, 'canInviteMembers'),
      canViewMoney: _requiredBool(json, 'canViewMoney'),
      canManageMoney: _requiredBool(json, 'canManageMoney'),
      canManageProviderProfile: _requiredBool(json, 'canManageProviderProfile'),
    );
  }

  final bool canViewPlan;
  final bool canEditPlan;
  final bool canManageTasks;
  final bool canManageGuests;
  final bool canManageProviders;
  final bool canInviteMembers;
  final bool canViewMoney;
  final bool canManageMoney;
  final bool canManageProviderProfile;

  Map<String, dynamic> toJson() => {
    'canViewPlan': canViewPlan,
    'canEditPlan': canEditPlan,
    'canManageTasks': canManageTasks,
    'canManageGuests': canManageGuests,
    'canManageProviders': canManageProviders,
    'canInviteMembers': canInviteMembers,
    'canViewMoney': canViewMoney,
    'canManageMoney': canManageMoney,
    'canManageProviderProfile': canManageProviderProfile,
  };
}

/// q12: what the plan's owner opened or closed for a participant since this
/// phone last saw the same membership. The server sends no notice of it, so
/// the phone compares the path it kept with the one just returned.
class AccountContextPermissionChange {
  const AccountContextPermissionChange({
    required this.contextKey,
    required this.before,
    required this.after,
  });

  final String contextKey;
  final AccountContextPermissions before;
  final AccountContextPermissions after;

  /// The change between the kept path and the returned one, or null when
  /// they are not the same participant membership or nothing changed.
  static AccountContextPermissionChange? between(
    AccountContext? kept,
    AccountContext? returned,
  ) {
    if (kept == null ||
        returned == null ||
        returned.role != AccountContextRole.contributor ||
        kept.contextKey != returned.contextKey ||
        kept.membershipId != returned.membershipId) {
      return null;
    }
    final change = AccountContextPermissionChange(
      contextKey: returned.contextKey,
      before: kept.permissions,
      after: returned.permissions,
    );
    return change.isEmpty ? null : change;
  }

  bool get moneyChanged =>
      before.canViewMoney != after.canViewMoney ||
      before.canManageMoney != after.canManageMoney;

  bool get isEmpty =>
      !moneyChanged &&
      before.canManageTasks == after.canManageTasks &&
      before.canManageGuests == after.canManageGuests &&
      before.canManageProviders == after.canManageProviders &&
      before.canInviteMembers == after.canInviteMembers &&
      before.canEditPlan == after.canEditPlan;
}

class AccountContext {
  const AccountContext({
    required this.contextKey,
    required this.role,
    required this.weddingPlanId,
    required this.providerId,
    required this.membershipId,
    required this.membershipAuthorityVersion,
    required this.persona,
    required this.readerFeminine,
    required this.displayName,
    required this.lifecycle,
    required this.accessMode,
    required this.capabilities,
    required this.permissions,
    required this.isAvailable,
    required this.unavailableReason,
  });

  factory AccountContext.fromJson(Map<String, dynamic> json) {
    final contextKey = _requiredString(json, 'contextKey');
    final role = _parseRole(_requiredString(json, 'role'));
    final weddingPlanId = _requiredNullableString(json, 'weddingPlanId');
    final providerId = _requiredNullableString(json, 'providerId');
    final membershipId = _requiredNullableString(json, 'membershipId');
    final membershipAuthorityVersion = _requiredNullableInt(
      json,
      'membershipAuthorityVersion',
    );
    final persona = _parsePersona(_requiredNullableString(json, 'persona'));
    final readerFeminine = _parseReaderForm(
      _requiredNullableString(json, 'readerForm'),
    );
    final displayName = _requiredString(json, 'displayName');
    final lifecycle = _requiredString(json, 'lifecycle');
    final accessMode = _parseAccessMode(_requiredString(json, 'accessMode'));
    final capabilities = AccountContextCapabilities.fromJson(
      _requiredMap(json, 'capabilities'),
    );
    final permissions = AccountContextPermissions.fromJson(
      _requiredMap(json, 'permissions'),
    );
    final isAvailable = _requiredBool(json, 'isAvailable');
    final unavailableReason = _requiredNullableString(
      json,
      'unavailableReason',
    );

    final context = AccountContext(
      contextKey: contextKey,
      role: role,
      weddingPlanId: weddingPlanId,
      providerId: providerId,
      membershipId: membershipId,
      membershipAuthorityVersion: membershipAuthorityVersion,
      persona: persona,
      readerFeminine: readerFeminine,
      displayName: displayName,
      lifecycle: lifecycle,
      accessMode: accessMode,
      capabilities: capabilities,
      permissions: permissions,
      isAvailable: isAvailable,
      unavailableReason: unavailableReason,
    );
    context._validateContract();
    return context;
  }

  final String contextKey;
  final AccountContextRole role;
  final String? weddingPlanId;
  final String? providerId;
  final String? membershipId;
  final int? membershipAuthorityVersion;
  final AccountContextPersona? persona;

  /// B5/D59: whether this reader is spoken to in the feminine in this plan,
  /// as the server resolved it once (`readerForm`: the account's persona,
  /// else the member's partner role, else the plan's side). Null for a
  /// provider context.
  final bool? readerFeminine;
  final String displayName;
  final String lifecycle;
  final AccountContextAccessMode accessMode;
  final AccountContextCapabilities capabilities;
  final AccountContextPermissions permissions;
  final bool isAvailable;
  final String? unavailableReason;

  bool get isPlan => role != AccountContextRole.provider;
  bool get isProvider => role == AccountContextRole.provider;

  /// How a plan names its owner to a participant («العريس», «العروسة»):
  /// the server sends the plan's persona, not the owner's name.
  String get planOwnerWord => switch (persona) {
    AccountContextPersona.bride => 'العروسة',
    AccountContextPersona.groom => 'العريس',
    _ => 'صاحب العرس',
  };

  /// The server's wire shape, so a kept copy reads back through [fromJson]
  /// and its contract checks.
  Map<String, dynamic> toJson() => {
    'contextKey': contextKey,
    'role': switch (role) {
      AccountContextRole.owner => 'OWNER',
      AccountContextRole.contributor => 'CONTRIBUTOR',
      AccountContextRole.provider => 'PROVIDER',
    },
    'weddingPlanId': weddingPlanId,
    'providerId': providerId,
    'membershipId': membershipId,
    'membershipAuthorityVersion': membershipAuthorityVersion,
    'persona': switch (persona) {
      null => null,
      AccountContextPersona.groom => 'GROOM',
      AccountContextPersona.bride => 'BRIDE',
      AccountContextPersona.helper => 'HELPER',
    },
    'readerForm': switch (readerFeminine) {
      null => null,
      true => 'FEMININE',
      false => 'MASCULINE',
    },
    'displayName': displayName,
    'lifecycle': lifecycle,
    'accessMode': switch (accessMode) {
      AccountContextAccessMode.full => 'FULL',
      AccountContextAccessMode.limited => 'LIMITED',
      AccountContextAccessMode.readOnly => 'READ_ONLY',
    },
    'capabilities': capabilities.toJson(),
    'permissions': permissions.toJson(),
    'isAvailable': isAvailable,
    'unavailableReason': unavailableReason,
  };

  void _validateContract() {
    if (role == AccountContextRole.provider) {
      if (persona != null || readerFeminine != null) {
        throw const FormatException(
          'Provider context cannot expose a wedding persona',
        );
      }
      _validateProviderContract();
      return;
    }
    if (readerFeminine == null) {
      throw const FormatException('Plan context requires the reader form');
    }
    _validatePlanContract();
  }

  void _validatePlanContract() {
    final planId = weddingPlanId;
    if (planId == null || providerId != null) {
      throw const FormatException(
        'Plan context identifiers do not match the context role',
      );
    }
    final suffix = role == AccountContextRole.owner ? 'owner' : 'contributor';
    if (contextKey != 'plan:$planId:$suffix') {
      throw const FormatException('Plan context key is not canonical');
    }
    if (lifecycle != 'PLANNING' && lifecycle != 'ARCHIVED') {
      throw const FormatException('Unknown plan context lifecycle');
    }
    final isPlanning = lifecycle == 'PLANNING';
    if (accessMode !=
            (isPlanning
                ? AccountContextAccessMode.full
                : AccountContextAccessMode.readOnly) ||
        isAvailable != isPlanning ||
        unavailableReason != (isPlanning ? null : 'PLAN_ARCHIVED')) {
      throw const FormatException('Plan context lifecycle is inconsistent');
    }
    if (capabilities.canViewProviderProfile ||
        capabilities.canManageProviderProfile ||
        capabilities.canUseProviderOperations ||
        permissions.canManageProviderProfile) {
      throw const FormatException(
        'Plan context exposes provider-only capabilities',
      );
    }
    if (role == AccountContextRole.owner) {
      if (membershipId != null || membershipAuthorityVersion != null) {
        throw const FormatException(
          'Owner context cannot expose contributor membership identity',
        );
      }
    } else if (membershipId == null ||
        membershipAuthorityVersion == null ||
        membershipAuthorityVersion! < 1) {
      throw const FormatException(
        'Contributor context requires a valid membership identity',
      );
    }
    if (!isPlanning &&
        (!permissions.canViewPlan ||
            permissions.canEditPlan ||
            permissions.canManageTasks ||
            permissions.canManageGuests ||
            permissions.canManageProviders ||
            permissions.canInviteMembers ||
            permissions.canManageMoney)) {
      throw const FormatException(
        'Archived plan context permissions are not read-only',
      );
    }
  }

  void _validateProviderContract() {
    final currentProviderId = providerId;
    if (currentProviderId == null || weddingPlanId != null) {
      throw const FormatException(
        'Provider context identifiers do not match the context role',
      );
    }
    if (contextKey != 'provider:$currentProviderId') {
      throw const FormatException('Provider context key is not canonical');
    }
    if (membershipId != null || membershipAuthorityVersion != null) {
      throw const FormatException(
        'Provider context cannot expose contributor membership identity',
      );
    }
    final expected = switch (lifecycle) {
      'ACTIVE' => (
        mode: AccountContextAccessMode.full,
        canManage: true,
        canOperate: true,
      ),
      'PENDING' || 'NEEDS_CHANGES' => (
        mode: AccountContextAccessMode.limited,
        canManage: true,
        canOperate: false,
      ),
      'SUSPENDED' || 'REJECTED' => (
        mode: AccountContextAccessMode.readOnly,
        canManage: false,
        canOperate: false,
      ),
      _ => throw const FormatException('Unknown provider context lifecycle'),
    };
    if (!isAvailable ||
        unavailableReason != null ||
        accessMode != expected.mode ||
        !capabilities.canViewProviderProfile ||
        capabilities.canManageProviderProfile != expected.canManage ||
        capabilities.canUseProviderOperations != expected.canOperate ||
        permissions.canManageProviderProfile != expected.canManage) {
      throw const FormatException('Provider context lifecycle is inconsistent');
    }
    if (permissions.canViewPlan ||
        permissions.canEditPlan ||
        permissions.canManageTasks ||
        permissions.canManageGuests ||
        permissions.canManageProviders ||
        permissions.canInviteMembers ||
        permissions.canViewMoney ||
        permissions.canManageMoney) {
      throw const FormatException(
        'Provider context exposes plan-only permissions',
      );
    }
  }
}

AccountContextPersona? _parsePersona(String? value) {
  return switch (value) {
    null => null,
    'GROOM' => AccountContextPersona.groom,
    'BRIDE' => AccountContextPersona.bride,
    'HELPER' => AccountContextPersona.helper,
    _ => throw const FormatException('Unknown account context persona'),
  };
}

bool? _parseReaderForm(String? value) {
  return switch (value) {
    null => null,
    'MASCULINE' => false,
    'FEMININE' => true,
    _ => throw const FormatException('Unknown account context reader form'),
  };
}

AccountContextRole _parseRole(String value) {
  return switch (value) {
    'OWNER' => AccountContextRole.owner,
    'CONTRIBUTOR' => AccountContextRole.contributor,
    'PROVIDER' => AccountContextRole.provider,
    _ => throw const FormatException('Unknown account context role'),
  };
}

AccountContextAccessMode _parseAccessMode(String value) {
  return switch (value) {
    'FULL' => AccountContextAccessMode.full,
    'LIMITED' => AccountContextAccessMode.limited,
    'READ_ONLY' => AccountContextAccessMode.readOnly,
    _ => throw const FormatException('Unknown account context access mode'),
  };
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw FormatException('Invalid $key');
  }
  return value;
}

String? _requiredNullableString(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Missing $key');
  }
  final value = json[key];
  if (value == null) return null;
  if (value is! String || value.isEmpty || value.trim() != value) {
    throw FormatException('Invalid $key');
  }
  return value;
}

int? _requiredNullableInt(Map<String, dynamic> json, String key) {
  if (!json.containsKey(key)) {
    throw FormatException('Missing $key');
  }
  final value = json[key];
  if (value == null) return null;
  if (value is! int) throw FormatException('Invalid $key');
  return value;
}

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('Invalid $key');
  return value;
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  throw FormatException('Invalid $key');
}

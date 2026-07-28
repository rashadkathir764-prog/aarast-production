import 'package:aarast_mobile/features/account_contexts/models/account_context.dart';
import 'package:flutter_test/flutter_test.dart';

import 'account_context_test_data.dart';

void main() {
  group('AccountContext strict additive contract', () {
    test('parses an owner context and ignores additive server fields', () {
      final json = accountContextJson(role: AccountContextRole.owner)
        ..['futureServerField'] = {'version': 2};

      final context = AccountContext.fromJson(json);

      expect(context.contextKey, 'plan:plan-1:owner');
      expect(context.role, AccountContextRole.owner);
      expect(context.weddingPlanId, 'plan-1');
      expect(context.providerId, isNull);
      expect(context.lifecycle, 'PLANNING');
      expect(context.accessMode, AccountContextAccessMode.full);
      expect(context.permissions.canManageMoney, isTrue);
      expect(context.capabilities.canUseProviderOperations, isFalse);
      expect(context.isAvailable, isTrue);
    });

    test('parses contributor and every provider lifecycle additively', () {
      final contributor = AccountContext.fromJson(
        accountContextJson(role: AccountContextRole.contributor),
      );
      expect(contributor.role, AccountContextRole.contributor);
      expect(contributor.contextKey, 'plan:plan-1:contributor');

      final expected = <String, AccountContextAccessMode>{
        'PENDING': AccountContextAccessMode.limited,
        'NEEDS_CHANGES': AccountContextAccessMode.limited,
        'ACTIVE': AccountContextAccessMode.full,
        'SUSPENDED': AccountContextAccessMode.readOnly,
        'REJECTED': AccountContextAccessMode.readOnly,
      };
      for (final entry in expected.entries) {
        final context = AccountContext.fromJson(
          accountContextJson(
            role: AccountContextRole.provider,
            lifecycle: entry.key,
            accessMode: entry.value,
          ),
        );
        expect(context.lifecycle, entry.key);
        expect(context.accessMode, entry.value);
        expect(context.capabilities.canViewProviderProfile, isTrue);
      }
    });

    test('rejects malformed or internally inconsistent contract fields', () {
      final invalidPayloads = <Map<String, dynamic>>[
        {...accountContextJson(role: AccountContextRole.owner)}
          ..remove('capabilities'),
        {
          ...accountContextJson(role: AccountContextRole.owner),
          'isAvailable': 'yes',
        },
        {
          ...accountContextJson(role: AccountContextRole.owner),
          'role': 'ADMIN',
        },
        {
          ...accountContextJson(role: AccountContextRole.owner),
          'lifecycle': 'ACTIVE',
        },
        {
          ...accountContextJson(role: AccountContextRole.provider),
          'accessMode': 'UNKNOWN',
        },
        {
          ...accountContextJson(role: AccountContextRole.owner),
          'contextKey': 'plan:plan-1:contributor',
        },
        {
          ...accountContextJson(role: AccountContextRole.provider),
          'weddingPlanId': 'plan-1',
        },
      ];

      for (final payload in invalidPayloads) {
        expect(
          () => AccountContext.fromJson(payload),
          throwsFormatException,
          reason: payload.toString(),
        );
      }
    });

    test(
      'rejects archived plans that cannot be viewed or retain a write permission',
      () {
        final archived = accountContextJson(
          role: AccountContextRole.owner,
          lifecycle: 'ARCHIVED',
          accessMode: AccountContextAccessMode.readOnly,
          isAvailable: false,
          unavailableReason: 'PLAN_ARCHIVED',
        );
        final cannotView = Map<String, dynamic>.from(archived)
          ..['permissions'] = {
            ...Map<String, dynamic>.from(archived['permissions'] as Map),
            'canViewPlan': false,
          };

        expect(
          () => AccountContext.fromJson(cannotView),
          throwsFormatException,
        );

        const writePermissions = [
          'canEditPlan',
          'canManageTasks',
          'canManageGuests',
          'canManageProviders',
          'canInviteMembers',
          'canManageMoney',
          'canManageProviderProfile',
        ];
        for (final permission in writePermissions) {
          final payload = Map<String, dynamic>.from(archived)
            ..['permissions'] = {
              ...Map<String, dynamic>.from(archived['permissions'] as Map),
              permission: true,
            };
          expect(
            () => AccountContext.fromJson(payload),
            throwsFormatException,
            reason: 'archived context retained $permission',
          );
        }
      },
    );
  });
}

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class PendingPlanCleanupRecord {
  const PendingPlanCleanupRecord({
    required this.installationId,
    required this.userId,
    required this.planId,
    required this.expectedMemberId,
    required this.expectedAuthorityVersion,
    required this.clientRequestId,
    required this.createdAt,
  });

  factory PendingPlanCleanupRecord.fromJson(Map<String, dynamic> json) {
    final installationId = _requiredString(
      json['installationId'],
      'installationId',
    );
    final userId = _requiredString(json['userId'], 'userId');
    final planId = _requiredString(json['planId'], 'planId');
    final expectedMemberId = _requiredString(
      json['expectedMemberId'],
      'expectedMemberId',
    );
    final expectedAuthorityVersion = _requiredPositiveInt(
      json['expectedAuthorityVersion'],
      'expectedAuthorityVersion',
    );
    final clientRequestId = _requiredString(
      json['clientRequestId'],
      'clientRequestId',
    );
    final createdAtRaw = _requiredString(json['createdAt'], 'createdAt');
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null) {
      throw const FormatException(
        'Pending plan cleanup has an invalid createdAt',
      );
    }
    return PendingPlanCleanupRecord(
      installationId: installationId,
      userId: userId,
      planId: planId,
      expectedMemberId: expectedMemberId,
      expectedAuthorityVersion: expectedAuthorityVersion,
      clientRequestId: clientRequestId,
      createdAt: createdAt.toUtc(),
    );
  }

  final String installationId;
  final String userId;
  final String planId;
  final String expectedMemberId;
  final int expectedAuthorityVersion;
  final String clientRequestId;
  final DateTime createdAt;

  String get identity =>
      '$installationId:$userId:$planId:$expectedMemberId:$expectedAuthorityVersion';

  Map<String, dynamic> toJson() => {
    'installationId': installationId,
    'userId': userId,
    'planId': planId,
    'expectedMemberId': expectedMemberId,
    'expectedAuthorityVersion': expectedAuthorityVersion,
    'clientRequestId': clientRequestId,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}

/// Installation-scoped durable intent store for contributor plan leaves.
///
/// This intentionally lives outside the offline account cache. A logout or a
/// cache-owner switch may wipe SQLite/cache metadata, but it must not erase an
/// ambiguous membership-removal request before the same user can replay it.
class PendingPlanCleanupStore {
  PendingPlanCleanupStore(this._preferences);

  static const storageKey = 'aarast.pending_plan_cleanups.v2';
  static const _version = 2;

  final SharedPreferences _preferences;
  Future<void> _operationTail = Future<void>.value();

  Future<List<PendingPlanCleanupRecord>> readAll() {
    return _serialize(() async => (await _readStateUnlocked()).records);
  }

  Future<PendingPlanCleanupRecord> putIfAbsent({
    required String userId,
    required String planId,
    required String expectedMemberId,
    required int expectedAuthorityVersion,
    required String clientRequestId,
    DateTime? createdAt,
  }) {
    return _serialize(() async {
      final state = await _readStateUnlocked();
      final candidate = PendingPlanCleanupRecord(
        installationId: state.installationId,
        userId: _requiredString(userId, 'userId'),
        planId: _requiredString(planId, 'planId'),
        expectedMemberId: _requiredString(expectedMemberId, 'expectedMemberId'),
        expectedAuthorityVersion: _requiredPositiveInt(
          expectedAuthorityVersion,
          'expectedAuthorityVersion',
        ),
        clientRequestId: _requiredString(clientRequestId, 'clientRequestId'),
        createdAt: (createdAt ?? DateTime.now()).toUtc(),
      );
      for (final existing in state.records) {
        if (existing.identity == candidate.identity) return existing;
      }
      await _writeAndVerify(
        state.copyWith(records: [...state.records, candidate]),
        expectedIdentity: candidate.identity,
      );
      return candidate;
    });
  }

  Future<void> remove(PendingPlanCleanupRecord record) {
    return _serialize(() async {
      final state = await _readStateUnlocked();
      if (record.installationId != state.installationId) {
        throw StateError(
          'Pending plan cleanup belongs to another installation',
        );
      }
      final updated = state.records
          .where((candidate) => candidate.identity != record.identity)
          .toList(growable: false);
      if (updated.length == state.records.length) return;
      // Keep the empty envelope so this installation keeps one stable id.
      await _writeAndVerify(
        state.copyWith(records: updated),
        removedIdentity: record.identity,
      );
    });
  }

  /// Removes every durable leave intent owned by a permanently deleted
  /// account. Ordinary logout must not call this: unresolved requests need to
  /// survive until that same account signs in and replays them.
  Future<void> removeForUser(String userId) {
    final normalizedUserId = _requiredString(userId, 'userId');
    return _serialize(() async {
      final state = await _readStateUnlocked();
      final updated = state.records
          .where((record) => record.userId != normalizedUserId)
          .toList(growable: false);
      if (updated.length == state.records.length) return;
      await _writeAndVerify(
        state.copyWith(records: updated),
        removedUserId: normalizedUserId,
      );
    });
  }

  Future<Set<String>> planIdsForUser(String userId) async {
    final normalizedUserId = _requiredString(userId, 'userId');
    final records = await readAll();
    return {
      for (final record in records)
        if (record.userId == normalizedUserId) record.planId,
    };
  }

  Future<_PendingPlanCleanupState> _readStateUnlocked() async {
    final raw = _preferences.getString(storageKey);
    if (raw == null) {
      return _PendingPlanCleanupState(
        installationId: _newInstallationId(),
        records: const [],
      );
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['version'] != _version) {
      throw const FormatException('Invalid pending plan cleanup store');
    }
    final installationId = _requiredString(
      decoded['installationId'],
      'installationId',
    );
    final rawRecords = decoded['records'];
    if (rawRecords is! List) {
      throw const FormatException('Invalid pending plan cleanup records');
    }
    final records = <PendingPlanCleanupRecord>[];
    final identities = <String>{};
    for (var index = 0; index < rawRecords.length; index += 1) {
      final rawRecord = rawRecords[index];
      if (rawRecord is! Map) {
        throw FormatException(
          'Invalid pending plan cleanup record at index $index',
        );
      }
      final record = PendingPlanCleanupRecord.fromJson(
        Map<String, dynamic>.from(rawRecord),
      );
      if (record.installationId != installationId) {
        throw FormatException(
          'Pending plan cleanup installation mismatch at index $index',
        );
      }
      if (!identities.add(record.identity)) {
        throw FormatException(
          'Duplicate pending plan cleanup record for ${record.identity}',
        );
      }
      records.add(record);
    }
    return _PendingPlanCleanupState(
      installationId: installationId,
      records: List.unmodifiable(records),
    );
  }

  Future<void> _writeAndVerify(
    _PendingPlanCleanupState state, {
    String? expectedIdentity,
    String? removedIdentity,
    String? removedUserId,
  }) async {
    final written = await _preferences.setString(
      storageKey,
      jsonEncode({
        'version': _version,
        'installationId': state.installationId,
        'records': state.records.map((record) => record.toJson()).toList(),
      }),
    );
    if (!written) {
      throw StateError('Pending plan cleanup store rejected the write');
    }
    final persisted = await _readStateUnlocked();
    if (persisted.installationId != state.installationId) {
      throw StateError('Pending plan cleanup installation id changed');
    }
    if (expectedIdentity != null &&
        !persisted.records.any(
          (record) => record.identity == expectedIdentity,
        )) {
      throw StateError('Pending plan cleanup was not persisted');
    }
    if (removedIdentity != null &&
        persisted.records.any((record) => record.identity == removedIdentity)) {
      throw StateError('Pending plan cleanup was not removed');
    }
    if (removedUserId != null &&
        persisted.records.any((record) => record.userId == removedUserId)) {
      throw StateError('Pending plan cleanups for user were not removed');
    }
  }

  Future<T> _serialize<T>(Future<T> Function() operation) {
    final completer = Completer<T>();
    Future<void> run() async {
      try {
        completer.complete(await operation());
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }

    _operationTail = _operationTail.then<void>(
      (_) => run(),
      onError: (_, _) => run(),
    );
    return completer.future;
  }
}

@immutable
class _PendingPlanCleanupState {
  const _PendingPlanCleanupState({
    required this.installationId,
    required this.records,
  });

  final String installationId;
  final List<PendingPlanCleanupRecord> records;

  _PendingPlanCleanupState copyWith({List<PendingPlanCleanupRecord>? records}) {
    return _PendingPlanCleanupState(
      installationId: installationId,
      records: records ?? this.records,
    );
  }
}

String _requiredString(Object? value, String field) {
  if (value is! String) {
    throw FormatException('Pending plan cleanup has invalid $field');
  }
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw FormatException('Pending plan cleanup is missing $field');
  }
  return normalized;
}

int _requiredPositiveInt(Object? value, String field) {
  if (value is! int || value < 1) {
    throw FormatException('Pending plan cleanup has invalid $field');
  }
  return value;
}

String _newInstallationId() {
  final random = Random.secure();
  return List<int>.generate(
    16,
    (_) => random.nextInt(256),
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

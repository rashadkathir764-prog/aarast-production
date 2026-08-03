import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../storage/sensitive_value_vault.dart';

@immutable
class PendingAccountDeletion {
  const PendingAccountDeletion({
    required this.userId,
    required this.clientRequestId,
    required this.createdAt,
  });

  factory PendingAccountDeletion.fromJson(Map<String, dynamic> json) {
    final userId = _requiredString(json['userId'], 'userId');
    final clientRequestId = _requiredString(
      json['clientRequestId'],
      'clientRequestId',
    );
    final createdAt = DateTime.tryParse(
      _requiredString(json['createdAt'], 'createdAt'),
    );
    if (createdAt == null) {
      throw const FormatException('Invalid pending account deletion createdAt');
    }
    return PendingAccountDeletion(
      userId: userId,
      clientRequestId: clientRequestId,
      createdAt: createdAt.toUtc(),
    );
  }

  final String userId;
  final String clientRequestId;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
    'version': 1,
    'userId': userId,
    'clientRequestId': clientRequestId,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };
}

/// Keystore-backed deletion intent that survives process death and logout.
class PendingAccountDeletionStore {
  PendingAccountDeletionStore(this._vault);

  static const storageKey = 'aarast.pending_account_deletion.v1';

  final SensitiveValueVault _vault;
  Future<void> _tail = Future<void>.value();

  Future<PendingAccountDeletion?> read() => _serialize(_readUnlocked);

  Future<PendingAccountDeletion> putIfAbsent(String userId) {
    return _serialize(() async {
      final normalizedUserId = _requiredString(userId, 'userId');
      final existing = await _readUnlocked();
      if (existing != null) {
        if (existing.userId != normalizedUserId) {
          throw StateError(
            'A pending account deletion belongs to another account',
          );
        }
        return existing;
      }
      final record = PendingAccountDeletion(
        userId: normalizedUserId,
        clientRequestId: _newClientRequestId(),
        createdAt: DateTime.now().toUtc(),
      );
      await _vault.write(storageKey, jsonEncode(record.toJson()));
      final persisted = await _readUnlocked();
      if (persisted?.userId != record.userId ||
          persisted?.clientRequestId != record.clientRequestId) {
        throw StateError('Pending account deletion was not persisted');
      }
      return record;
    });
  }

  /// Called only by the confirmed deleted-account teardown stage.
  Future<void> removeForDeletedUser(String userId) {
    return _serialize(() async {
      final normalizedUserId = _requiredString(userId, 'userId');
      final existing = await _readUnlocked();
      if (existing == null || existing.userId != normalizedUserId) return;
      await _vault.delete(storageKey);
      if (await _readUnlocked() != null) {
        throw StateError('Pending account deletion was not removed');
      }
    });
  }

  /// A definitive server-side rejection proves no deletion committed.
  Future<void> removeAfterDefinitiveRejection(PendingAccountDeletion record) {
    return _serialize(() async {
      final existing = await _readUnlocked();
      if (existing == null) return;
      if (existing.userId != record.userId ||
          existing.clientRequestId != record.clientRequestId) {
        throw StateError('Pending account deletion identity changed');
      }
      await _vault.delete(storageKey);
      if (await _readUnlocked() != null) {
        throw StateError('Pending account deletion was not removed');
      }
    });
  }

  Future<PendingAccountDeletion?> _readUnlocked() async {
    final raw = await _vault.read(storageKey);
    if (raw == null) return null;
    final decoded = jsonDecode(raw);
    if (decoded is! Map || decoded['version'] != 1) {
      throw const FormatException('Invalid pending account deletion marker');
    }
    return PendingAccountDeletion.fromJson(Map<String, dynamic>.from(decoded));
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

    _tail = _tail.then<void>((_) => run(), onError: (_, _) => run());
    return completer.future;
  }
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid pending account deletion $field');
  }
  return value.trim();
}

String _newClientRequestId() {
  final random = Random.secure();
  return List<int>.generate(
    16,
    (_) => random.nextInt(256),
  ).map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
}

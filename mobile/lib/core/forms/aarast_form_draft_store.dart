import 'dart:async';
import 'dart:convert';

import '../storage/auth_storage.dart';
import '../storage/sensitive_value_vault.dart';

/// Persists unfinished form values in the platform keystore/keychain.
///
/// Guest contacts and money values are private product data, so form drafts
/// must never fall back to plaintext preferences. Drafts are account-scoped,
/// listed in a secure manifest, and removed after a successful submit or full
/// account teardown.
class AarastFormDraftStore {
  AarastFormDraftStore({
    required SensitiveValueVault vault,
    required AuthStorage authStorage,
  }) : _vault = vault,
       _authStorage = authStorage;

  static const _manifestKey = 'aarast.form-drafts.manifest.v1';
  static const _version = 1;

  final SensitiveValueVault _vault;
  final AuthStorage _authStorage;
  Future<void> _mutationTail = Future<void>.value();

  Future<Map<String, dynamic>?> read(String scope) async {
    await _mutationTail;
    final identity = _identity;
    final normalizedScope = _normalizeScope(scope);
    final raw = await _vault.read(_storageKey(identity, normalizedScope));
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final envelope = Map<String, dynamic>.from(decoded);
      if (envelope['version'] != _version ||
          envelope['identity'] != identity ||
          envelope['scope'] != normalizedScope ||
          envelope['data'] is! Map) {
        return null;
      }
      return Map<String, dynamic>.from(envelope['data'] as Map);
    } on FormatException {
      return null;
    }
  }

  Future<void> write(String scope, Map<String, dynamic> data) {
    final identity = _identity;
    final normalizedScope = _normalizeScope(scope);
    final key = _storageKey(identity, normalizedScope);
    return _enqueue(() async {
      await _vault.write(
        key,
        jsonEncode({
          'version': _version,
          'identity': identity,
          'scope': normalizedScope,
          'savedAt': DateTime.now().toUtc().toIso8601String(),
          'data': data,
        }),
      );
      final keys = await _readManifest();
      if (keys.add(key)) await _writeManifest(keys);
    });
  }

  Future<void> clear(String scope) {
    final key = _storageKey(_identity, _normalizeScope(scope));
    return _enqueue(() async {
      await _vault.delete(key);
      final keys = await _readManifest();
      if (keys.remove(key)) await _writeManifest(keys);
    });
  }

  Future<void> clearAll() {
    return _enqueue(() async {
      final keys = await _readManifest();
      for (final key in keys) {
        await _vault.delete(key);
      }
      await _vault.delete(_manifestKey);
    });
  }

  String get _identity {
    final userId = _authStorage.readUser()?.id.trim();
    return userId == null || userId.isEmpty ? 'guest' : 'account:$userId';
  }

  String _storageKey(String identity, String scope) {
    final bytes = utf8.encode('$identity|$scope');
    return 'aarast.form-draft.${base64Url.encode(bytes)}';
  }

  String _normalizeScope(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(value, 'scope', 'must not be empty');
    }
    return normalized;
  }

  Future<Set<String>> _readManifest() async {
    final raw = await _vault.read(_manifestKey);
    if (raw == null || raw.isEmpty) return <String>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>{};
      return decoded
          .whereType<String>()
          .where((value) => value.startsWith('aarast.form-draft.'))
          .toSet();
    } on FormatException {
      return <String>{};
    }
  }

  Future<void> _writeManifest(Set<String> keys) {
    if (keys.isEmpty) return _vault.delete(_manifestKey);
    final sorted = keys.toList()..sort();
    return _vault.write(_manifestKey, jsonEncode(sorted));
  }

  Future<void> _enqueue(Future<void> Function() mutation) {
    final completer = Completer<void>();
    _mutationTail = _mutationTail.then((_) async {
      try {
        await mutation();
        completer.complete();
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }
}

enum AarastFormDraftStatus { idle, saving, saved, failed }

/// Debounces autosave writes while exposing one small status for the form UI.
class AarastFormDraftCoordinator {
  AarastFormDraftCoordinator({
    required this.store,
    required this.scope,
    this.onStatusChanged,
    this.debounce = const Duration(milliseconds: 500),
  });

  final AarastFormDraftStore? store;
  final String scope;
  final void Function()? onStatusChanged;
  final Duration debounce;

  Timer? _timer;
  Map<String, dynamic>? _pending;
  AarastFormDraftStatus _status = AarastFormDraftStatus.idle;

  AarastFormDraftStatus get status => _status;

  Future<Map<String, dynamic>?> restore() =>
      store?.read(scope) ?? Future<Map<String, dynamic>?>.value();

  void schedule(Map<String, dynamic> data) {
    if (store == null) return;
    _pending = Map<String, dynamic>.from(data);
    _timer?.cancel();
    _setStatus(AarastFormDraftStatus.saving);
    _timer = Timer(debounce, () => unawaited(flush()));
  }

  Future<void> flush() async {
    _timer?.cancel();
    _timer = null;
    final data = _pending;
    if (store == null || data == null) return;
    _pending = null;
    try {
      await store!.write(scope, data);
      _setStatus(AarastFormDraftStatus.saved);
    } on Object {
      _setStatus(AarastFormDraftStatus.failed);
    }
  }

  Future<void> clear() async {
    _timer?.cancel();
    _timer = null;
    _pending = null;
    if (store != null) await store!.clear(scope);
    _setStatus(AarastFormDraftStatus.idle);
  }

  void dispose() {
    _timer?.cancel();
    if (_pending != null) unawaited(flush());
  }

  void _setStatus(AarastFormDraftStatus value) {
    if (_status == value) return;
    _status = value;
    onStatusChanged?.call();
  }
}

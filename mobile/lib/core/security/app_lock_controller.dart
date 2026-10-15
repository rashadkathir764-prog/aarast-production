import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/widgets.dart';

import '../storage/sensitive_value_vault.dart';

/// Optional app lock with a 4-digit code (V1 checklist 4.15). A phone in
/// Yemen often passes between family members and the money in a plan is
/// private, so an account may require its code whenever the app opens or
/// returns after a minute in the background.
///
/// The code is per account (a guest has none) and only a salted, iterated
/// SHA-256 of it is kept, in the device's secure storage. Wrong codes wait
/// longer and longer; a forgotten code is solved by signing in again with
/// WhatsApp, which clears it.
class AppLockController extends ChangeNotifier with WidgetsBindingObserver {
  AppLockController({
    required SensitiveValueVault vault,
    required this.userId,
    DateTime Function()? clock,
    Random? random,
  }) : _vault = vault,
       _clock = clock ?? DateTime.now,
       _random = random ?? Random.secure();

  static const codeLength = 4;
  static const relockAfter = Duration(minutes: 1);
  static const freeAttempts = 5;
  static const _iterations = 10000;

  final SensitiveValueVault _vault;
  final DateTime Function() _clock;
  final Random _random;

  /// The signed-in account, or null for a guest (no lock).
  final String? userId;

  bool _loaded = false;
  bool _enabled = false;
  bool _locked = false;
  bool _observing = false;
  int _failedAttempts = 0;
  DateTime? _blockedUntil;
  DateTime? _backgroundedAt;

  bool get isEnabled => _enabled;
  bool get isLocked => _locked;

  /// Until the stored setting is read, an account's content stays hidden.
  bool get isPending => userId != null && !_loaded;
  int get failedAttempts => _failedAttempts;

  /// How long until another code may be tried; zero when one may.
  Duration get waitRemaining {
    final until = _blockedUntil;
    if (until == null) return Duration.zero;
    final remaining = until.difference(_clock());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  String get _hashKey => 'app_lock.$userId.hash';
  String get _saltKey => 'app_lock.$userId.salt';
  String get _failuresKey => 'app_lock.$userId.failures';
  String get _blockedKey => 'app_lock.$userId.blocked_until';

  Future<void> load() async {
    if (userId == null) {
      _loaded = true;
      return;
    }
    final hash = await _vault.read(_hashKey);
    _enabled = hash != null;
    _locked = _enabled;
    _failedAttempts = int.tryParse(await _vault.read(_failuresKey) ?? '') ?? 0;
    _blockedUntil = DateTime.tryParse(await _vault.read(_blockedKey) ?? '');
    _loaded = true;
    if (!_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    notifyListeners();
  }

  static bool isValidCode(String code) =>
      code.length == codeLength && RegExp(r'^[0-9]+$').hasMatch(code);

  /// Turns the lock on (or changes the code).
  Future<void> setCode(String code) async {
    if (userId == null || !isValidCode(code)) {
      throw ArgumentError('The app lock needs a $codeLength-digit code');
    }
    final salt = base64Encode(
      List<int>.generate(16, (_) => _random.nextInt(256)),
    );
    await _vault.write(_saltKey, salt);
    await _vault.write(_hashKey, _digest(salt, code));
    await _clearFailures();
    _enabled = true;
    _locked = false;
    notifyListeners();
  }

  Future<void> disable() async {
    await _forgetCode();
    notifyListeners();
  }

  /// Tries a code. True unlocks; false counts a wrong code (or a code
  /// tried while still waiting, which is not even checked).
  Future<bool> unlock(String code) async {
    if (!_locked) return true;
    if (waitRemaining > Duration.zero) return false;
    final salt = await _vault.read(_saltKey);
    final hash = await _vault.read(_hashKey);
    if (salt != null && hash != null && _digest(salt, code) == hash) {
      await _clearFailures();
      _locked = false;
      notifyListeners();
      return true;
    }
    _failedAttempts += 1;
    await _vault.write(_failuresKey, '$_failedAttempts');
    if (_failedAttempts >= freeAttempts) {
      final extra = _failedAttempts - freeAttempts;
      final seconds = min(30 * pow(2, extra).toInt(), 15 * 60);
      _blockedUntil = _clock().add(Duration(seconds: seconds));
      await _vault.write(_blockedKey, _blockedUntil!.toIso8601String());
    }
    notifyListeners();
    return false;
  }

  /// The owner forgot the code: it is cleared, and the caller signs out so
  /// only a fresh WhatsApp sign-in reopens the account.
  Future<void> forgetForSignOut() => _forgetCode();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_enabled) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _backgroundedAt ??= _clock();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundedAt;
      _backgroundedAt = null;
      if (since != null && _clock().difference(since) >= relockAfter) {
        _locked = true;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _forgetCode() async {
    if (userId == null) return;
    await _vault.delete(_hashKey);
    await _vault.delete(_saltKey);
    await _clearFailures();
    _enabled = false;
    _locked = false;
  }

  Future<void> _clearFailures() async {
    _failedAttempts = 0;
    _blockedUntil = null;
    await _vault.delete(_failuresKey);
    await _vault.delete(_blockedKey);
  }

  static String _digest(String salt, String code) {
    List<int> digest = utf8.encode('$salt:$code');
    for (var round = 0; round < _iterations; round += 1) {
      digest = sha256.convert([...digest, ...utf8.encode(salt)]).bytes;
    }
    return base64Encode(digest);
  }
}

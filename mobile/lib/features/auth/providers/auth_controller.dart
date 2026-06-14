import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/offline/cache_policy.dart';
import '../../../core/offline/offline_sync_service.dart';
import '../data/auth_repository.dart';
import '../models/safe_user.dart';

enum AuthStatus { checking, authenticated, unauthenticated }

class AuthController extends ChangeNotifier {
  AuthController(this._authRepository, {OfflineSyncService? offlineSyncService})
    : _offlineSyncService = offlineSyncService;

  final AuthRepository _authRepository;
  final OfflineSyncService? _offlineSyncService;

  AuthStatus _status = AuthStatus.checking;
  SafeUser? _user;
  bool _isSubmitting = false;
  String? _errorMessage;

  AuthStatus get status => _status;
  SafeUser? get user => _user;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  Future<void> restoreSession() async {
    _status = AuthStatus.checking;
    _user = _authRepository.readCachedUser();
    notifyListeners();

    final token = await _authRepository.readAccessToken();
    if (token == null || token.isEmpty) {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }

    try {
      _user = await _authRepository.me();
      if (_user != null) {
        await _offlineSyncService?.cacheCurrentUser(_user!);
      }
      _status = AuthStatus.authenticated;
      unawaited(_offlineSyncService?.syncPendingChanges());
    } on ApiException catch (error) {
      if (CachePolicy.shouldUseCache(error) && _user != null) {
        _status = AuthStatus.authenticated;
        await _offlineSyncService?.noteNetworkFailure(error.message);
      } else {
        await _authRepository.logout();
        _user = null;
        _status = AuthStatus.unauthenticated;
      }
    }
    notifyListeners();
  }

  Future<bool> login({required String phone, required String password}) async {
    return _submit(() async {
      final response = await _authRepository.login(
        phone: phone.trim(),
        password: password,
      );
      _user = response.user;
      await _offlineSyncService?.cacheCurrentUser(response.user);
      _status = AuthStatus.authenticated;
      unawaited(_offlineSyncService?.syncPendingChanges());
    });
  }

  Future<bool> register({
    required String name,
    required String phone,
    required String password,
    String? email,
  }) async {
    return _submit(() async {
      final response = await _authRepository.register(
        name: name.trim(),
        phone: phone.trim(),
        email: email,
        password: password,
      );
      _user = response.user;
      await _offlineSyncService?.cacheCurrentUser(response.user);
      _status = AuthStatus.authenticated;
      unawaited(_offlineSyncService?.syncPendingChanges());
    });
  }

  Future<void> logout() async {
    await _authRepository.logout();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<bool> _submit(Future<void> Function() action) async {
    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await action();
      return true;
    } on ApiException catch (error) {
      _errorMessage = error.isNetworkFailure && _user == null
          ? CachePolicy.firstLoginNeedsInternet
          : error.message;
      return false;
    } catch (_) {
      _errorMessage = 'حدث خطأ، يرجى المحاولة مرة أخرى.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}

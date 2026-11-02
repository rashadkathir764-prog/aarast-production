part of 'auth_controller.dart';

// Sign-in, registration, OTP and profile updates.
mixin _AuthSignIn on _AuthControllerCore {
  Future<bool> login({
    required String phone,
    required String password,
    String? successLocation,
  }) async {
    if (_status != AuthStatus.unauthenticated) {
      appLogEvent(
        'LOGIN_FAILED',
        category: AppLogCategory.auth,
        level: AppLogLevel.warning,
        reason: 'session_not_unauthenticated',
        source: 'AuthController.login',
        attributes: {'authStatus': _status.name},
      );
      return false;
    }
    AppLogger.global?.startSessionCorrelation();
    final operation = ++_sessionOperationGeneration;
    appLogEvent(
      'LOGIN_STARTED',
      category: AppLogCategory.auth,
      reason: 'password_login_requested',
      source: 'AuthController.login',
    );
    final success = await _submit(() async {
      final response = await _authRepository.login(
        phone: phone.trim(),
        password: password,
      );
      if (!_isCurrentSessionOperation(operation)) return;
      _user = response.user;
      _authRepository.bindClientSession(response.user.id);
      await _offlineSyncService?.ensureCacheOwner(response.user.id);
      if (!_isCurrentSessionOperation(operation)) return;
      await _offlineSyncService?.cacheCurrentUser(response.user);
      if (!_isCurrentSessionOperation(operation)) return;
      _status = AuthStatus.authenticated;
      _accountJustCreated = false;
      _signUpFoundAccount = false;
      _loginRequestedAfterLogout = false;
      _queueAuthenticatedEntry(successLocation);
      unawaited(_offlineSyncService?.syncPendingChanges());
    }, unauthorizedMessage: _safeLoginFailureMessage);
    final completed = success && _isCurrentSessionOperation(operation);
    appLogEvent(
      completed ? 'LOGIN_SUCCEEDED' : 'LOGIN_FAILED',
      category: AppLogCategory.auth,
      level: completed ? AppLogLevel.info : AppLogLevel.warning,
      userId: completed ? _user?.id : null,
      reason: completed
          ? 'authenticated_session_established'
          : success
          ? 'stale_session_operation'
          : 'authentication_rejected',
      source: 'AuthController.login',
      attributes: {'authStatus': _status.name, 'errorCode': ?_errorCode},
    );
    return completed;
  }

  Future<bool> register({
    required String name,
    required String phone,
    required String otpCode,
    String? resumeInviteToken,
    String? successLocation,
    bool savesKeptPlan = false,
  }) async {
    if (_status != AuthStatus.unauthenticated) {
      return false;
    }
    AppLogger.global?.startSessionCorrelation();
    final cleanResumeToken = _validInviteToken(resumeInviteToken);
    final operation = ++_sessionOperationGeneration;
    final success = await _submit(() async {
      final response = await _authRepository.register(
        name: name.trim(),
        phone: phone.trim(),
        otpCode: otpCode,
      );
      if (!_isCurrentSessionOperation(operation)) return;
      _user = response.user;
      _authRepository.bindClientSession(response.user.id);
      await _offlineSyncService?.ensureCacheOwner(response.user.id);
      if (!_isCurrentSessionOperation(operation)) return;
      await _offlineSyncService?.cacheCurrentUser(response.user);
      if (!_isCurrentSessionOperation(operation)) return;
      _status = AuthStatus.authenticated;
      // A number that already had an account signed in to it (D75).
      // Saved at once only when this new account was made to save the plan
      // on this phone; a provider's sign-up never takes it in (D75).
      _accountJustCreated = savesKeptPlan && !response.existingAccount;
      _signUpFoundAccount = response.existingAccount;
      _loginRequestedAfterLogout = false;
      if (cleanResumeToken != null) {
        _pendingInviteResumeToken = cleanResumeToken;
        _pendingInviteRouteClaimed = false;
      } else {
        _clearPendingInviteResume();
        _queueAuthenticatedEntry(successLocation);
      }
      unawaited(_offlineSyncService?.syncPendingChanges());
    });
    return success && _isCurrentSessionOperation(operation);
  }

  Future<OtpRequestResult?> startRegistration({
    required String name,
    required String phone,
  }) async {
    OtpRequestResult? result;
    final success = await _submit(
      () async {
        result = await _authRepository.startRegistration(
          name: name.trim(),
          phone: phone.trim(),
        );
        _otpRequest = result;
      },
      networkFailureMessage:
          'تعذر إرسال رمز إنشاء الحساب الآن. تحقق من الاتصال وحاول مرة أخرى.',
    );
    return success ? result : null;
  }

  Future<OtpRequestResult?> requestOtp({
    required String phone,
    required String purpose,
  }) async {
    OtpRequestResult? result;
    final success = await _submit(
      () async {
        result = await _authRepository.requestOtp(
          phone: phone.trim(),
          purpose: purpose,
        );
        _otpRequest = result;
      },
      networkFailureMessage:
          'تعذر إرسال رمز التحقق الآن. تحقق من الاتصال وحاول مرة أخرى.',
    );
    return success ? result : null;
  }

  Future<OtpRequestResult?> requestInviteOtp({
    required String token,
    required String phone,
  }) async {
    OtpRequestResult? result;
    final success = await _submit(
      () async {
        result = await _authRepository.requestInviteOtp(
          token: token.trim(),
          phone: phone.trim(),
        );
        _otpRequest = result;
      },
      networkFailureMessage:
          'تعذر التحقق من الدعوة الآن. تحقق من الاتصال وحاول مرة أخرى.',
    );
    return success ? result : null;
  }

  Future<bool> verifyOtp({
    required String phone,
    required String purpose,
    required String code,
    String? resumeInviteToken,
    String? accountName,
    String? accountPassword,
    String? successLocation,
  }) async {
    final cleanResumeToken = _validInviteToken(resumeInviteToken);
    final establishesSession = purpose == 'LOGIN' || cleanResumeToken != null;
    final privateInviteAccountSwitch =
        cleanResumeToken != null && _status == AuthStatus.authenticated;
    if (establishesSession &&
        _status != AuthStatus.unauthenticated &&
        !privateInviteAccountSwitch) {
      return false;
    }
    if (establishesSession) {
      AppLogger.global?.startSessionCorrelation();
    }
    final operation = ++_sessionOperationGeneration;
    final success = await _submit(() async {
      final response = cleanResumeToken == null
          ? await _authRepository.verifyOtp(
              phone: phone.trim(),
              purpose: purpose,
              code: code,
            )
          : await _authRepository.verifyInviteOtp(
              token: cleanResumeToken,
              phone: phone.trim(),
              code: code,
              name: accountName,
              password: accountPassword,
            );
      if (!_isCurrentSessionOperation(operation)) return;
      if (response.user != null) {
        _user = response.user;
        _authRepository.bindClientSession(response.user!.id);
        await _offlineSyncService?.ensureCacheOwner(response.user!.id);
        if (!_isCurrentSessionOperation(operation)) return;
        await _offlineSyncService?.cacheCurrentUser(response.user!);
        if (!_isCurrentSessionOperation(operation)) return;
      }
      if (response.accessToken != null) {
        _status = AuthStatus.authenticated;
        _loginRequestedAfterLogout = false;
        if (purpose == 'LOGIN' && cleanResumeToken != null) {
          _pendingInviteResumeToken = cleanResumeToken;
          _pendingInviteRouteClaimed = false;
        } else {
          _clearPendingInviteResume();
          _queueAuthenticatedEntry(successLocation);
        }
        unawaited(_offlineSyncService?.syncPendingChanges());
      }
    });
    return success && _isCurrentSessionOperation(operation);
  }

  Future<bool> updateAvatar({
    required Uint8List bytes,
    required String fileName,
    required String contentType,
  }) {
    return _submit(() async {
      _user = await _authRepository.updateAvatar(
        bytes: bytes,
        fileName: fileName,
        contentType: contentType,
      );
      if (_user != null) {
        _authRepository.bindClientSession(_user!.id);
        await _offlineSyncService?.cacheCurrentUser(_user!);
      }
    });
  }

  Future<bool> _submit(
    Future<void> Function() action, {
    String? unauthorizedMessage,
    String? networkFailureMessage,
  }) async {
    _isSubmitting = true;
    _errorMessage = null;
    _errorCode = null;
    _failedOffline = false;
    notifyListeners();

    try {
      await action();
      return true;
    } on FormatException catch (error) {
      appLogEvent(
        'AUTH_INPUT_REJECTED',
        category: AppLogCategory.auth,
        level: AppLogLevel.warning,
        reason: 'invalid_phone_format',
        source: 'AuthController.submit',
        attributes: {'errorType': error.runtimeType.toString()},
      );
      _errorMessage = 'رقم الهاتف غير صحيح';
      return false;
    } on ApiException catch (error) {
      _errorCode = error.serverCode;
      final translatedMessage = _messageForServerCode(error.serverCode);
      if (translatedMessage != null) {
        _errorMessage = translatedMessage;
      } else if (error.isUnauthorized && unauthorizedMessage != null) {
        _errorMessage = unauthorizedMessage;
      } else if (error.isNetworkFailure) {
        _failedOffline = true;
        _errorMessage =
            networkFailureMessage ??
            'تعذر تسجيل الدخول الآن. تحقق من الاتصال وحاول مرة أخرى.';
      } else {
        _errorMessage = error.message;
      }
      return false;
    } catch (error) {
      appLogEvent(
        'AUTH_UNEXPECTED_FAILURE',
        category: AppLogCategory.auth,
        level: AppLogLevel.error,
        reason: 'unexpected_auth_exception',
        source: 'AuthController.submit',
        attributes: {'errorType': error.runtimeType.toString()},
      );
      _errorMessage = 'حدث خطأ، يرجى المحاولة مرة أخرى.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  static const _safeLoginFailureMessage =
      'تعذر تسجيل الدخول بهذه البيانات. تأكد منها، أو استخدم «نسيت كلمة المرور؟» أو أنشئ حسابًا جديدًا.';

  static String? _messageForServerCode(String? code) {
    return switch (code) {
      'INVALID_CREDENTIALS' => _safeLoginFailureMessage,
      'OTP_DELIVERY_UNAVAILABLE' => aarastOtpDeliveryUnavailableMessage,
      'PHONE_VERIFICATION_REQUIRED' =>
        'يحتاج حساب التطبيق إلى تأكيد رقم الهاتف. استخدم «الدخول برمز تحقق» للمتابعة.',
      'ACCOUNT_ALREADY_EXISTS' =>
        'هذا الرقم عليه حساب من قبل. الدخول له برمز واتساب من «تسجيل الدخول».',
      'ADMIN_APP_PASSWORD_ALREADY_SET' =>
        'تم إعداد حساب التطبيق لهذا الرقم بالفعل. انتقل إلى تسجيل الدخول أو استعد كلمة مرور التطبيق.',
      'OTP_INVALID_OR_EXPIRED' =>
        'الرمز غلط أو انتهى وقته. اكتبه مرة ثانية أو اطلب رمز جديد.',
      'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF' =>
        'تم التحقق من الرقم، ولا يوجد حساب تطبيق مرتبط به. أنشئ حسابًا جديدًا للمتابعة.',
      'ACCOUNT_DISABLED_AFTER_PHONE_PROOF' =>
        'تم التحقق من الرقم، لكن الحساب معطل حاليًا. تواصل مع الدعم.',
      'INVITE_NOT_FOUND_FOR_PHONE' =>
        'لا توجد دعوة فعّالة مرتبطة بهذا الرقم. تأكد من الرقم أو اطلب دعوة جديدة.',
      'INVITE_ACCOUNT_SETUP_REQUIRED' =>
        'أول مرة تدخل اعّرست: اكتب اسمك، ونفس الرمز يسوي لك حساب.',
      'ADMIN_APP_PASSWORD_REQUIRED' => adminAppPasswordRequiredMessage,
      _ => null,
    };
  }
}

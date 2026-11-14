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
      _signUpFoundAccountNoticePending = false;
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

  /// [otpCode] is the sign-up code; or [phoneProof], what a sign-in code
  /// for this number proved (D75), so no second code is sent.
  Future<bool> register({
    required String name,
    required String phone,
    String? otpCode,
    String? phoneProof,
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
        phoneProof: phoneProof,
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
      // The server answers with the account it signed in to, so its name
      // is the one on that account, not the one typed here.
      final foundName = response.user.name.trim();
      _signUpFoundAccountName = response.existingAccount && foundName.isNotEmpty
          ? foundName
          : null;
      _signUpFoundAccountNoticePending = response.existingAccount;
      _loginRequestedAfterLogout = false;
      if (cleanResumeToken != null) {
        _pendingInviteResumeToken = cleanResumeToken;
        _pendingInviteRouteClaimed = false;
      } else {
        _clearPendingInviteResume();
        _queueAuthenticatedEntry(successLocation);
      }
      unawaited(_offlineSyncService?.syncPendingChanges());
    }, networkFailureMessage: _signUpOfflineMessage);
    // RA-MO-308: the sign-up code was taken; it opens nothing again.
    if (success && otpCode != null) _forgetCodeSent();
    return success && _isCurrentSessionOperation(operation);
  }

  /// A lost connection while the account is being made is not a failed
  /// sign-in. The screens say it in the reader's own words.
  static const _signUpOfflineMessage =
      'ما قدرنا ننشئ حسابك الحين، تأكد من النت وجرّب.';

  Future<OtpRequestResult?> startRegistration({
    required String name,
    required String phone,
  }) {
    return _requestCode(
      phone: phone,
      purpose: 'REGISTER',
      send: () => _authRepository.startRegistration(
        name: name.trim(),
        phone: phone.trim(),
      ),
      networkFailureMessage:
          'ما قدرنا نرسل رمز الحساب الجديد. تأكد من النت وجرّب مرة ثانية.',
    );
  }

  /// Every flow that asks for a code: the request is noted on this phone
  /// before it is sent ([AuthRepository.noteCodeRequest]), so a code that
  /// reached WhatsApp can still be typed when its answer did not reach the
  /// phone.
  ///
  /// RA-MO-109: the system closed the app while the person was in WhatsApp
  /// reading the code, and the server refused a second code within the
  /// minute (`OTP_LIMIT_COOLDOWN`), though the first was still good. That
  /// refusal opens the code screen for the code already sent; a new one can
  /// be asked there once the minute is over. RA-MO-308: only for a code this
  /// phone itself asked for, for the same number and purpose, within the
  /// minute ([CodeRequestNote.settle]); otherwise the server's refusal is
  /// shown as it is, as the screen would refuse the code in WhatsApp.
  ///
  /// A request that left without an answer opens the code screen with a
  /// notice that the code may have arrived; one that never left says so.
  Future<OtpRequestResult?> _requestCode({
    required String phone,
    required String purpose,
    required Future<OtpRequestResult> Function() send,
    required String networkFailureMessage,

    /// What the server ties the code to beyond number and purpose (an
    /// invite): the cooldown never reopens it for another one.
    String? boundTo,
  }) async {
    final typed = phone.trim();
    final earlierResult = _otpRequest;
    CodeRequestNote? note;
    Object? failure;
    OtpRequestResult? result;
    final success = await _submit(() async {
      note = _authRepository.noteCodeRequest(
        phone: typed,
        purpose: purpose,
        at: _now(),
        boundTo: boundTo,
      );
      try {
        result = await send();
      } on Object catch (error) {
        failure = error;
        rethrow;
      }
      _otpRequest = result;
    }, networkFailureMessage: networkFailureMessage);
    if (success) return result;
    final sent = note;
    final error = failure;
    // A second tap while the first waits: nothing was sent.
    if (sent == null || error == null) return null;
    final reopened = sent.settle(error, earlierResult: earlierResult);
    if (reopened == null) return null;
    _errorMessage = null;
    _errorCode = null;
    _failedOffline = false;
    _otpRequest = reopened;
    notifyListeners();
    return reopened;
  }

  /// The server took the code: nothing reopens it again (RA-MO-308).
  void _forgetCodeSent() {
    unawaited(_authRepository.forgetCodeRequest());
  }

  Future<OtpRequestResult?> requestOtp({
    required String phone,
    required String purpose,
  }) {
    return _requestCode(
      phone: phone,
      purpose: purpose,
      send: () =>
          _authRepository.requestOtp(phone: phone.trim(), purpose: purpose),
      networkFailureMessage:
          'ما قدرنا نرسل الرمز. تأكد من النت وجرّب مرة ثانية.',
    );
  }

  /// RA-MO-98: an invite opened with another number, on a phone signed in to
  /// an account, signs the phone in as that other account, and the phone
  /// then drops everything of the first account, its unsent changes with it.
  /// While such changes wait, the switch is refused with its reason, before
  /// any code is sent; null when nothing would be lost.
  ///
  /// D112 (Q-9), the owner's word: the phone never changes its account
  /// under the person. An invite for another number always asks them to
  /// sign out first; with changes waiting, it says those would be lost.
  ({String message, String code})? _inviteSwitchRefusal(String phone) {
    if (_status != AuthStatus.authenticated) return null;
    String digits(String? value) =>
        (value ?? '').replaceAll(RegExp(r'[^0-9]'), '');
    final current = digits(_user?.phone);
    final entered = digits(phone);
    // The same person, written with or without the country code.
    final same =
        current.isNotEmpty &&
        entered.isNotEmpty &&
        (current.endsWith(entered) || entered.endsWith(current));
    if (same) return null;
    if ((_offlineSyncService?.unsyncedCount ?? 0) > 0) {
      return (
        message:
            'على هذا الجوال تغييرات لحسابك لسا ما انرسلت، والدخول برقم ثاني '
            'يمسحها. خلّها تنرسل أول، وبعدها اطلع من حسابك من «حسابي» '
            'وافتح الدعوة.',
        code: 'INVITE_SWITCH_WOULD_DROP_UNSENT',
      );
    }
    return (
      message:
          'هذي الدعوة لرقم غير رقم الحساب المفتوح على هذا الجوال. '
          'اطلع من الحساب من «حسابي» أول، وبعدها افتح الدعوة.',
      code: 'INVITE_NEEDS_SIGN_OUT',
    );
  }

  Future<OtpRequestResult?> requestInviteOtp({
    required String token,
    required String phone,
  }) async {
    final refusal = _inviteSwitchRefusal(phone);
    if (refusal != null) {
      _errorMessage = refusal.message;
      _errorCode = refusal.code;
      notifyListeners();
      return null;
    }
    return _requestCode(
      phone: phone,
      // The server's purpose for an invite's code, which is this invite's
      // alone.
      purpose: 'INVITE_ACCESS',
      boundTo: token.trim(),
      send: () => _authRepository.requestInviteOtp(
        token: token.trim(),
        phone: phone.trim(),
      ),
      networkFailureMessage:
          'ما قدرنا نتأكد من الدعوة. تأكد من النت وجرّب مرة ثانية.',
    );
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
    if (privateInviteAccountSwitch) {
      final refusal = _inviteSwitchRefusal(phone);
      if (refusal != null) {
        _errorMessage = refusal.message;
        _errorCode = refusal.code;
        notifyListeners();
        return false;
      }
    }
    if (establishesSession) {
      AppLogger.global?.startSessionCorrelation();
    }
    final operation = ++_sessionOperationGeneration;
    final proofBefore = _phoneProofAt;
    // An invite's first code with a name makes the account (D75).
    final offline = accountName != null ? _signUpOfflineMessage : null;
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
    }, networkFailureMessage: offline);
    // RA-MO-308: the server took the code; it opens nothing again.
    if (success) _forgetCodeSent();
    // The number this code proved goes with its proof (D75): only a proof
    // this code brought; one kept from another number is never given to
    // this one (RA-MO-111 keeps a proof across a failed request).
    if (_phoneProofAt != proofBefore) {
      _phoneProofPhone = _phoneProof == null ? null : phone.trim();
    }
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
    // One request at a time, whichever button or key asked for it: a second
    // tap, the keyboard's done, or the proof button never sends twice.
    if (_isSubmitting) return false;
    _isSubmitting = true;
    _errorMessage = null;
    _errorCode = null;
    _failedOffline = false;
    // RA-MO-111: the proof that a code proved this number stays until a
    // request goes through. It was dropped as every request began, so a
    // save that failed (a password refused, the network) took it with it,
    // and «احفظ خطتي بهذا الرقم» left for a new code.
    notifyListeners();

    try {
      await action();
      _phoneProof = null;
      _phoneProofAt = null;
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
      _errorMessage = 'رقم الجوال غير صحيح';
      return false;
    } on ApiException catch (error) {
      _errorCode = error.serverCode;
      // A new proof replaces the old; a refusal without one keeps it.
      // Its age is counted from when the phone got it (J1-06).
      if (error.phoneProof case final proof?) {
        _phoneProof = proof;
        _phoneProofAt = _now();
      }
      final translatedMessage = _messageForServerCode(error.serverCode);
      if (translatedMessage != null) {
        _errorMessage = translatedMessage;
      } else if (error.isUnauthorized && unauthorizedMessage != null) {
        _errorMessage = unauthorizedMessage;
      } else if (error.isNetworkFailure) {
        _failedOffline = true;
        _errorMessage =
            networkFailureMessage ??
            'ما قدرنا نسجّل دخولك. تأكد من النت وجرّب مرة ثانية.';
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
      _errorMessage = 'صار خطأ عندنا. جرّب مرة ثانية.';
      return false;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }

  static const _safeLoginFailureMessage =
      'الرقم أو كلمة المرور غلط. تأكد منهم، أو استعمل «نسيت كلمة المرور؟»، أو سوّ حساب جديد.';

  static String? _messageForServerCode(String? code) {
    return switch (code) {
      'INVALID_CREDENTIALS' => _safeLoginFailureMessage,
      'OTP_DELIVERY_UNAVAILABLE' => aarastOtpDeliveryUnavailableMessage,
      'PHONE_VERIFICATION_REQUIRED' =>
        // The button's own name on the sign-in screen («الدخول برمز
        // تحقق», which this said before, is on no screen).
        'حساب التطبيق يحتاج تأكيد رقم الجوال. استعمل «الدخول برمز واتساب» وكمّل.',
      'ACCOUNT_ALREADY_EXISTS' =>
        'هذا الرقم عليه حساب من قبل. الدخول له برمز واتساب من «تسجيل الدخول».',
      'ADMIN_APP_PASSWORD_ALREADY_SET' =>
        'حساب التطبيق لهذا الرقم جاهز من قبل. سجّل دخول، أو استرجع كلمة مرور التطبيق.',
      'OTP_INVALID_OR_EXPIRED' =>
        'الرمز غلط أو انتهى وقته. اكتبه مرة ثانية أو اطلب رمز جديد.',
      'ACCOUNT_NOT_FOUND_AFTER_PHONE_PROOF' =>
        'تأكدنا من رقمك، وما عليه حساب في التطبيق. سوّ حساب جديد وكمّل.',
      'ACCOUNT_DISABLED_AFTER_PHONE_PROOF' =>
        'تأكدنا من رقمك، لكن الحساب موقوف الحين. تواصل مع الدعم.',
      'INVITE_NOT_FOUND_FOR_PHONE' =>
        'ما في دعوة شغالة على هذا الرقم. تأكد من الرقم، أو اطلب دعوة جديدة.',
      'INVITE_ACCOUNT_SETUP_REQUIRED' =>
        'أول مرة تدخل اعّرست: اكتب اسمك، ونفس الرمز يسوي لك حساب.',
      'ADMIN_APP_PASSWORD_REQUIRED' => adminAppPasswordRequiredMessage,
      _ => null,
    };
  }
}

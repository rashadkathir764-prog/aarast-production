import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../utils/app_clock.dart';

/// D84: why the server could not be reached, measured from the failure
/// itself, never assumed. «بدون نت» is claimed only when the phone's own
/// network refused the connection; a slow or down server says so.
enum ReachabilityCause {
  /// The phone has no route to the internet (network unreachable).
  noNetwork,

  /// The server's name could not be resolved on this network.
  dns,

  /// The secure connection did not complete (certificate or handshake).
  tls,

  /// The server refused the connection (nothing listening, or blocked).
  refused,

  /// The server did not answer in time.
  timeout,

  /// The connection broke before the answer arrived.
  interrupted,

  /// The server answered with its own error (5xx).
  serverError,

  /// A transport failure of a kind not recognised here.
  unknown,
}

/// One failure to reach the server: its cause, when, on which path, and
/// the raw detail for the connection report.
class ReachabilityFailure {
  const ReachabilityFailure({
    required this.cause,
    required this.at,
    this.path,
    this.detail,
  });

  final ReachabilityCause cause;
  final DateTime at;
  final String? path;
  final String? detail;
}

/// The cause of a transport failure, or null when the server answered
/// (any HTTP status) or the request was cancelled by the app itself.
ReachabilityCause? classifyTransportFailure(DioException error) {
  if (error.response != null) return null;
  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
      return ReachabilityCause.timeout;
    case DioExceptionType.badCertificate:
      return ReachabilityCause.tls;
    case DioExceptionType.cancel:
    case DioExceptionType.badResponse:
    case DioExceptionType.transformTimeout:
      return null;
    case DioExceptionType.connectionError:
    case DioExceptionType.unknown:
      return _classifyError(error.error) ??
          (error.type == DioExceptionType.connectionError
              ? ReachabilityCause.unknown
              : null);
  }
}

ReachabilityCause? _classifyError(Object? error) {
  if (error == null) return null;
  if (error is HandshakeException ||
      error is TlsException ||
      error is CertificateException) {
    return ReachabilityCause.tls;
  }
  if (error is SocketException) {
    final code = error.osError?.errorCode;
    final text = '${error.message} ${error.osError?.message ?? ''}'
        .toLowerCase();
    if (text.contains('failed host lookup') ||
        text.contains('no address associated') ||
        text.contains('name or service not known') ||
        text.contains('nodename nor servname')) {
      return ReachabilityCause.dns;
    }
    if (const {101, 113, 50, 51, 64, 65}.contains(code) ||
        text.contains('network is unreachable') ||
        text.contains('network unreachable') ||
        text.contains('no route to host') ||
        text.contains('network is down')) {
      return ReachabilityCause.noNetwork;
    }
    if (const {111, 61}.contains(code) || text.contains('connection refused')) {
      return ReachabilityCause.refused;
    }
    if (text.contains('connection reset') ||
        text.contains('broken pipe') ||
        text.contains('connection abort') ||
        text.contains('connection closed')) {
      return ReachabilityCause.interrupted;
    }
    if (text.contains('timed out')) return ReachabilityCause.timeout;
    return ReachabilityCause.unknown;
  }
  if (error is HttpException) return ReachabilityCause.interrupted;
  final text = error.toString().toLowerCase();
  if (text.contains('handshake') || text.contains('certificate')) {
    return ReachabilityCause.tls;
  }
  if (text.contains('failed host lookup')) return ReachabilityCause.dns;
  if (text.contains('network is unreachable')) {
    return ReachabilityCause.noNetwork;
  }
  if (text.contains('connection refused')) return ReachabilityCause.refused;
  if (text.contains('connection reset') || text.contains('connection closed')) {
    return ReachabilityCause.interrupted;
  }
  return null;
}

/// What happened, in the reader's words.
String reachabilityCauseLabel(ReachabilityCause cause) => switch (cause) {
  ReachabilityCause.noNetwork => 'ما فيه نت في الجوال الحين',
  // Q-32, critique ع3: the app's name, never «الخادم».
  ReachabilityCause.dns => 'ما لقينا عنوان اعّرست على هذي الشبكة',
  ReachabilityCause.tls => 'الاتصال الآمن ما اكتمل',
  ReachabilityCause.refused => 'اعّرست ما يرد الحين',
  ReachabilityCause.timeout => 'الرد تأخر',
  ReachabilityCause.interrupted => 'الاتصال انقطع قبل ما يكمل',
  ReachabilityCause.serverError => 'صار خطأ عندنا',
  ReachabilityCause.unknown => 'ما قدرنا نوصل لاعّرست',
};

/// What to do about it.
// Critique ط2: the network layer does not know who reads, so the step is
// said without a verb to a man or a woman.
String reachabilityCauseAdvice(ReachabilityCause cause) => switch (cause) {
  ReachabilityCause.noNetwork => 'لما يرجع النت تمشي.',
  ReachabilityCause.dns => 'شبكة ثانية أو بعد شوي تمشي غالبًا.',
  ReachabilityCause.tls => 'تحديث التطبيق أو شبكة ثانية يحلّها غالبًا.',
  ReachabilityCause.refused ||
  ReachabilityCause.timeout ||
  ReachabilityCause.interrupted ||
  ReachabilityCause.serverError => 'بعد شوي تمشي.',
  ReachabilityCause.unknown => 'لما يرجع النت تمشي.',
};

/// The one place that knows whether the server answered last. Every
/// response from it (any status) marks it reachable; every transport
/// failure marks it unreachable with its measured cause. The sync service
/// and the banner read this instead of guessing from a single failure.
class ServerReachability extends ChangeNotifier {
  ServerReachability({DateTime Function()? clock}) : _clock = clock ?? appNow;

  final DateTime Function() _clock;
  bool _reachable = true;
  ReachabilityFailure? _lastFailure;
  DateTime? _lastReachedAt;

  bool get reachable => _reachable;
  ReachabilityFailure? get lastFailure => _lastFailure;
  DateTime? get lastReachedAt => _lastReachedAt;

  /// The server answered (even with an error): the transport works.
  void noteReached() {
    _lastReachedAt = _clock();
    if (_reachable) return;
    _reachable = true;
    notifyListeners();
  }

  void noteFailure(ReachabilityFailure failure) {
    _lastFailure = failure;
    final changed = _reachable;
    _reachable = false;
    notifyListeners();
    if (!changed) return;
  }

  /// Reads one request outcome: answered, or failed in transport.
  void observe(DioException error) {
    if (error.response != null) {
      noteReached();
      return;
    }
    final cause = classifyTransportFailure(error);
    if (cause == null) return;
    noteFailure(
      ReachabilityFailure(
        cause: cause,
        at: _clock(),
        path: error.requestOptions.path,
        detail: error.error?.toString() ?? error.message,
      ),
    );
  }
}

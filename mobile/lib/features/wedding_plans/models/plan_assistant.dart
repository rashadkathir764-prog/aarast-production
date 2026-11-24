import 'package:flutter/widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// What the planning assistant is asked to do (V1 checklist 4.12).
enum PlanAssistantKind {
  plan('PLAN', 'خطة عمل حتى يوم العرس', LucideIcons.calendarCheck),
  budgetSplit('BUDGET_SPLIT', 'وزّع لي الميزانية', LucideIcons.pieChart),
  compareQuotes('COMPARE_QUOTES', 'قارن عروض الأسعار', LucideIcons.scale),
  cheaper('CHEAPER', 'فين أوفر؟', LucideIcons.piggyBank),
  forgotten('FORGOTTEN', 'ايش نسيت؟', LucideIcons.listChecks),
  negotiation('NEGOTIATION', 'اكتب رسالة تفاوض', LucideIcons.messageCircle),
  question('QUESTION', 'سؤال آخر', LucideIcons.helpCircle);

  const PlanAssistantKind(this.apiValue, this.label, this.icon);

  final String apiValue;
  final String label;
  final IconData icon;
}

class PlanAssistantStatus {
  const PlanAssistantStatus({
    required this.enabled,
    required this.allowed,
    required this.dailyLimit,
    required this.remainingToday,
    this.consentedAt,
  });

  factory PlanAssistantStatus.fromJson(Map<String, dynamic> json) {
    return PlanAssistantStatus(
      enabled: json['enabled'] == true,
      allowed: json['allowed'] == true,
      dailyLimit: _int(json['dailyLimit']),
      remainingToday: _int(json['remainingToday']),
      consentedAt: DateTime.tryParse(json['consentedAt']?.toString() ?? ''),
    );
  }

  /// The service is set up.
  final bool enabled;

  /// The reader is the plan's owner or partner.
  final bool allowed;
  final int dailyLimit;
  final int remainingToday;

  /// RA-BE-161: when the reader agreed (w36), as the server keeps it; null
  /// before, or after w40 took it back.
  final DateTime? consentedAt;

  bool get available => enabled && allowed;

  PlanAssistantStatus copyWith({
    int? remainingToday,
    DateTime? Function()? consentedAt,
  }) => PlanAssistantStatus(
    enabled: enabled,
    allowed: allowed,
    dailyLimit: dailyLimit,
    remainingToday: remainingToday ?? this.remainingToday,
    consentedAt: consentedAt == null ? this.consentedAt : consentedAt(),
  );
}

class PlanAssistantAnswer {
  const PlanAssistantAnswer({
    required this.answerId,
    required this.answer,
    required this.declined,
    required this.marketDataAvailable,
    required this.remainingToday,
    this.truncated = false,
  });

  factory PlanAssistantAnswer.fromJson(Map<String, dynamic> json) {
    return PlanAssistantAnswer(
      answerId: json['answerId']?.toString() ?? '',
      answer: json['answer']?.toString() ?? '',
      declined: json['declined'] == true,
      truncated: json['truncated'] == true,
      marketDataAvailable: json['marketDataAvailable'] == true,
      remainingToday: _int(json['remainingToday']),
    );
  }

  /// RA-BE-166: the server's id of this answer; a report carries it, so
  /// the team reads what the assistant wrote.
  final String answerId;
  final String answer;
  final bool declined;

  /// RA-BE-163: the model stopped at its limit; [answer] is only a start.
  final bool truncated;
  final bool marketDataAvailable;
  final int remainingToday;
}

int _int(Object? value) =>
    value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

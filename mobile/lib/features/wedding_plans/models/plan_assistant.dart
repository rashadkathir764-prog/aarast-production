import 'package:flutter/widgets.dart';
import 'package:lucide_icons/lucide_icons.dart';

/// What the planning assistant is asked to do (V1 checklist 4.12).
enum PlanAssistantKind {
  plan('PLAN', 'خطة عمل حتى يوم العرس', LucideIcons.calendarCheck),
  budgetSplit('BUDGET_SPLIT', 'وزّع لي الميزانية', LucideIcons.pieChart),
  compareQuotes('COMPARE_QUOTES', 'قارن عروض الأسعار', LucideIcons.scale),
  cheaper('CHEAPER', 'وين أوفر؟', LucideIcons.piggyBank),
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
  });

  factory PlanAssistantStatus.fromJson(Map<String, dynamic> json) {
    return PlanAssistantStatus(
      enabled: json['enabled'] == true,
      allowed: json['allowed'] == true,
      dailyLimit: _int(json['dailyLimit']),
      remainingToday: _int(json['remainingToday']),
    );
  }

  /// The service is set up.
  final bool enabled;

  /// The reader is the plan's owner or partner.
  final bool allowed;
  final int dailyLimit;
  final int remainingToday;

  bool get available => enabled && allowed;
}

class PlanAssistantAnswer {
  const PlanAssistantAnswer({
    required this.answer,
    required this.declined,
    required this.marketDataAvailable,
    required this.remainingToday,
  });

  factory PlanAssistantAnswer.fromJson(Map<String, dynamic> json) {
    return PlanAssistantAnswer(
      answer: json['answer']?.toString() ?? '',
      declined: json['declined'] == true,
      marketDataAvailable: json['marketDataAvailable'] == true,
      remainingToday: _int(json['remainingToday']),
    );
  }

  final String answer;
  final bool declined;
  final bool marketDataAvailable;
  final int remainingToday;
}

int _int(Object? value) =>
    value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;

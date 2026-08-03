import 'package:flutter/foundation.dart';

@immutable
class ContributionHistoryResponse {
  const ContributionHistoryResponse({
    required this.historyCoverageStartsAt,
    required this.events,
    required this.total,
  });

  factory ContributionHistoryResponse.fromJson(Map<String, dynamic> json) {
    final rawCoverage = json['historyCoverageStartsAt'];
    final rawEvents = json['events'];
    final rawTotal = json['total'];
    if (rawCoverage is! String || rawEvents is! List || rawTotal is! num) {
      throw const FormatException('Invalid contribution history response');
    }
    final coverage = DateTime.tryParse(rawCoverage);
    final total = rawTotal.toInt();
    if (coverage == null || total < 0 || rawTotal != total) {
      throw const FormatException('Invalid contribution history response');
    }
    final events = <ContributionHistoryEvent>[];
    final eventIds = <String>{};
    for (var index = 0; index < rawEvents.length; index += 1) {
      final rawEvent = rawEvents[index];
      if (rawEvent is! Map) {
        throw FormatException(
          'Invalid contribution history event at index $index',
        );
      }
      final event = ContributionHistoryEvent.fromJson(
        _strictStringMap(rawEvent, 'event at index $index'),
      );
      if (!eventIds.add(event.id)) {
        throw FormatException(
          'Duplicate contribution history event at index $index',
        );
      }
      events.add(event);
    }
    if (events.length > total) {
      throw const FormatException('Contribution history page exceeds total');
    }
    return ContributionHistoryResponse(
      historyCoverageStartsAt: coverage.toUtc(),
      events: List.unmodifiable(events),
      total: total,
    );
  }

  final DateTime historyCoverageStartsAt;
  final List<ContributionHistoryEvent> events;
  final int total;
}

@immutable
class ContributionHistoryEvent {
  const ContributionHistoryEvent({
    required this.id,
    required this.section,
    required this.entityType,
    required this.action,
    required this.snapshot,
    required this.occurredAt,
    required this.capturedAt,
    this.provenance,
  });

  factory ContributionHistoryEvent.fromJson(Map<String, dynamic> json) {
    final rawSnapshot = json['snapshot'];
    if (json['id'] is! String ||
        json['section'] is! String ||
        json['entityType'] is! String ||
        json['action'] is! String ||
        rawSnapshot is! Map ||
        json['capturedAt'] is! String) {
      throw const FormatException('Invalid contribution history event');
    }
    final id = json['id'] as String;
    final section = json['section'] as String;
    final entityType = json['entityType'] as String;
    final action = json['action'] as String;
    if (id.trim().isEmpty ||
        section.trim().isEmpty ||
        entityType.trim().isEmpty ||
        action.trim().isEmpty) {
      throw const FormatException('Invalid contribution history event');
    }
    final capturedAt = DateTime.tryParse(json['capturedAt'] as String);
    final rawOccurredAt = json['occurredAt'];
    final occurredAt = rawOccurredAt == null
        ? null
        : rawOccurredAt is String
        ? DateTime.tryParse(rawOccurredAt)
        : null;
    if (capturedAt == null || (rawOccurredAt != null && occurredAt == null)) {
      throw const FormatException('Invalid contribution history event date');
    }
    return ContributionHistoryEvent(
      id: id,
      section: section,
      entityType: entityType,
      action: action,
      snapshot: Map<String, dynamic>.unmodifiable(
        _strictStringMap(rawSnapshot, 'snapshot'),
      ),
      occurredAt: occurredAt?.toUtc(),
      capturedAt: capturedAt.toUtc(),
      provenance: json['provenance'] is String
          ? json['provenance'] as String
          : null,
    );
  }

  final String id;
  final String section;
  final String entityType;
  final String action;
  final Map<String, dynamic> snapshot;
  final DateTime? occurredAt;
  final DateTime capturedAt;
  final String? provenance;
}

Map<String, dynamic> _strictStringMap(Map<dynamic, dynamic> raw, String name) {
  if (raw.keys.any((key) => key is! String)) {
    throw FormatException('Invalid contribution history $name');
  }
  return Map<String, dynamic>.from(raw);
}

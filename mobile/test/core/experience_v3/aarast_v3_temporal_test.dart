import 'package:aarast_mobile/core/experience_v3/aarast_v3.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 8, 9, 12);

  test('deadline sections use one now today week later completed grammar', () {
    expect(
      aarastDeadlineSection(
        dueDate: DateTime(2026, 8, 8),
        completed: false,
        now: now,
      ),
      AarastTemporalSection.now,
    );
    expect(
      aarastDeadlineSection(dueDate: now, completed: false, now: now),
      AarastTemporalSection.today,
    );
    expect(
      aarastDeadlineSection(
        dueDate: DateTime(2026, 8, 14),
        completed: false,
        now: now,
      ),
      AarastTemporalSection.week,
    );
    expect(
      aarastDeadlineSection(
        dueDate: DateTime(2026, 9, 1),
        completed: false,
        now: now,
      ),
      AarastTemporalSection.later,
    );
    expect(
      aarastDeadlineSection(dueDate: now, completed: true, now: now),
      AarastTemporalSection.completed,
    );
  });

  test('activity sections prioritize unread urgency then recency', () {
    expect(
      aarastActivitySection(
        occurredAt: DateTime(2026, 8, 1),
        completed: false,
        urgent: true,
        now: now,
      ),
      AarastTemporalSection.now,
    );
    expect(
      aarastActivitySection(
        occurredAt: DateTime(2026, 8, 9, 8),
        completed: false,
        now: now,
      ),
      AarastTemporalSection.today,
    );
    expect(
      aarastActivitySection(
        occurredAt: DateTime(2026, 8, 5),
        completed: false,
        now: now,
      ),
      AarastTemporalSection.week,
    );
    expect(
      aarastActivitySection(
        occurredAt: DateTime(2026, 7, 1),
        completed: true,
        now: now,
      ),
      AarastTemporalSection.completed,
    );
  });
}

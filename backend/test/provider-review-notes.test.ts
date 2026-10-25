import assert from 'node:assert/strict';
import test from 'node:test';
import {
  ProviderReviewEventKind,
  ProviderReviewField,
  ProviderStatus,
} from '@prisma/client';
import { currentProviderReviewNotes } from '../src/modules/marketplace/public/provider-review';

const changes = {
  kind: ProviderReviewEventKind.CHANGES_REQUESTED,
  notes: [
    { field: ProviderReviewField.SERVICE, note: 'اكتب سعر الليلة.' },
    { field: ProviderReviewField.GENERAL, note: 'ملفك قريب.' },
    { field: ProviderReviewField.BUSINESS_NAME, note: 'الاسم اللي يعرفونك فيه.' },
  ],
};

test('the provider reads the latest request for changes: the general note and one per field, in the profile order (B-01)', () => {
  assert.deepEqual(
    currentProviderReviewNotes(ProviderStatus.NEEDS_CHANGES, changes),
    {
      reviewNote: 'ملفك قريب.',
      fieldNotes: [
        { field: ProviderReviewField.BUSINESS_NAME, note: 'الاسم اللي يعرفونك فيه.' },
        { field: ProviderReviewField.SERVICE, note: 'اكتب سعر الليلة.' },
      ],
    },
  );
});

test('a reopened refusal keeps its reason as the first note until the next decision (B-02)', () => {
  const refusal = {
    kind: ProviderReviewEventKind.REJECTED,
    notes: [{ field: ProviderReviewField.GENERAL, note: 'وضّحي الخدمة.' }],
  };
  assert.equal(
    currentProviderReviewNotes(ProviderStatus.NEEDS_CHANGES, refusal).reviewNote,
    'وضّحي الخدمة.',
  );
  assert.equal(
    currentProviderReviewNotes(ProviderStatus.REJECTED, refusal).reviewNote,
    'وضّحي الخدمة.',
  );
});

test('no note shows once the profile went back to review, was approved, or was never decided', () => {
  const none = { reviewNote: null, fieldNotes: [] };
  assert.deepEqual(currentProviderReviewNotes(ProviderStatus.PENDING, changes), none);
  assert.deepEqual(currentProviderReviewNotes(ProviderStatus.ACTIVE, changes), none);
  assert.deepEqual(currentProviderReviewNotes(ProviderStatus.NEEDS_CHANGES, null), none);
  assert.deepEqual(
    currentProviderReviewNotes(ProviderStatus.SUSPENDED, {
      kind: ProviderReviewEventKind.APPROVED,
      notes: [],
    }),
    none,
  );
});

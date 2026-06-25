import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { ConflictException } from '@nestjs/common';
import { QuoteRequestStatus } from '@prisma/client';
import {
  assertQuoteRequestTransition,
  quoteLifecycleStatus,
} from '../src/marketplace/quote-lifecycle';

test('maps persisted quote states to truthful product lifecycle states', () => {
  assert.equal(
    quoteLifecycleStatus(QuoteRequestStatus.SENT),
    'PENDING_PROVIDER',
  );
  assert.equal(
    quoteLifecycleStatus(QuoteRequestStatus.VIEWED),
    'PENDING_PROVIDER',
  );
  assert.equal(
    quoteLifecycleStatus(QuoteRequestStatus.RESPONDED),
    'RECEIVED',
  );
  assert.equal(
    quoteLifecycleStatus(QuoteRequestStatus.ACCEPTED),
    'ACCEPTED',
  );
});

test('only a real provider offer can move a pending request to received', () => {
  assert.doesNotThrow(() =>
    assertQuoteRequestTransition(
      QuoteRequestStatus.SENT,
      QuoteRequestStatus.RESPONDED,
      'provider_offer',
    ),
  );
  assert.throws(
    () =>
      assertQuoteRequestTransition(
        QuoteRequestStatus.SENT,
        QuoteRequestStatus.RESPONDED,
        'provider',
      ),
    ConflictException,
  );
});

test('accept and reject require a received quote', () => {
  assert.doesNotThrow(() =>
    assertQuoteRequestTransition(
      QuoteRequestStatus.RESPONDED,
      QuoteRequestStatus.ACCEPTED,
      'requester',
    ),
  );
  assert.doesNotThrow(() =>
    assertQuoteRequestTransition(
      QuoteRequestStatus.RESPONDED,
      QuoteRequestStatus.REJECTED,
      'requester',
    ),
  );
  assert.throws(
    () =>
      assertQuoteRequestTransition(
        QuoteRequestStatus.SENT,
        QuoteRequestStatus.ACCEPTED,
        'requester',
      ),
    ConflictException,
  );
});

test('terminal quote states reject further lifecycle changes', () => {
  for (const status of [
    QuoteRequestStatus.ACCEPTED,
    QuoteRequestStatus.REJECTED,
    QuoteRequestStatus.CANCELLED,
  ]) {
    assert.throws(
      () =>
        assertQuoteRequestTransition(
          status,
          QuoteRequestStatus.CANCELLED,
          'requester',
        ),
      ConflictException,
    );
  }
});

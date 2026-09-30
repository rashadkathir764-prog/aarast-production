import assert from 'node:assert/strict';
import test from 'node:test';
import {
  lockQuoteOfferTransitionRows,
  lockQuoteRequestTransitionRow,
} from '../src/marketplace/quote-lifecycle';

test('quote request transition locks conversation before request', async () => {
  const order: string[] = [];
  const tx = {
    quoteRequest: {
      findUnique: async () => {
        order.push('request-seed');
        return { conversationId: 'conversation-1' };
      },
    },
    $queryRaw: async (query: { sql: string }) => {
      assert.match(query.sql, /FROM "QuoteRequest"[\s\S]*FOR UPDATE/);
      order.push('request-lock');
      return [{ id: 'request-1' }];
    },
  } as any;
  const lifecycle = {
    lockConversationForUpdateInTransaction: async (_tx: unknown, id: string) => {
      assert.equal(id, 'conversation-1');
      order.push('conversation-lock');
      return true;
    },
  } as any;

  assert.equal(await lockQuoteRequestTransitionRow(tx, lifecycle, 'request-1'), true);
  assert.deepEqual(order, ['request-seed', 'conversation-lock', 'request-lock']);
});

test('quote offer transition locks conversation, request, then offer', async () => {
  const order: string[] = [];
  const tx = {
    quoteOffer: {
      findUnique: async () => {
        order.push('offer-seed');
        return { quoteRequest: { conversationId: 'conversation-1' } };
      },
    },
    $queryRaw: async (query: { sql: string }) => {
      if (query.sql.includes('FOR UPDATE OF qr')) {
        order.push('request-lock');
        return [{ quoteRequestId: 'request-1' }];
      }
      assert.match(query.sql, /FROM "QuoteOffer"[\s\S]*FOR UPDATE/);
      order.push('offer-lock');
      return [{ id: 'offer-1' }];
    },
  } as any;
  const lifecycle = {
    lockConversationForUpdateInTransaction: async () => {
      order.push('conversation-lock');
      return true;
    },
  } as any;

  assert.deepEqual(
    await lockQuoteOfferTransitionRows(tx, lifecycle, 'offer-1'),
    { quoteRequestId: 'request-1' },
  );
  assert.deepEqual(order, ['offer-seed', 'conversation-lock', 'request-lock', 'offer-lock']);
});

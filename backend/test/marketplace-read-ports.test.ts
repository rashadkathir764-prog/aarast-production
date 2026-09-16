import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { MODULE_METADATA } from '@nestjs/common/constants';
import type { Prisma } from '@prisma/client';
import {
  MarketplaceReadInternalModule,
  PROVIDER_READ_IMPLEMENTATION,
  QUOTE_READ_IMPLEMENTATION,
} from '../src/modules/marketplace/internal/marketplace-read.internal.module';
import { ProviderReadService } from '../src/modules/marketplace/internal/provider-read.service';
import { QuoteReadService } from '../src/modules/marketplace/internal/quote-read.service';
import { ProviderReadPublicModule } from '../src/modules/marketplace/public/provider-read-public.module';
import { PROVIDER_READ_PORT } from '../src/modules/marketplace/public/provider-read.port';
import { QuoteReadPublicModule } from '../src/modules/marketplace/public/quote-read-public.module';
import { QUOTE_READ_PORT } from '../src/modules/marketplace/public/quote-read.port';

function sqlText(query: unknown): string {
  const strings = (query as { strings?: readonly string[] }).strings;
  assert.ok(Array.isArray(strings));
  return strings.join('?').replace(/\s+/g, ' ').trim();
}

test('the provider read port runs the owner queries and locks on the client it is given', async () => {
  const calls: Array<[string, unknown]> = [];
  const statements: string[] = [];
  const provider = { id: 'provider-1', userId: 'user-1', businessName: 'Hall' };
  const client = {
    provider: {
      findUnique: async (args: unknown) => { calls.push(['findUnique', args]); return provider; },
      findMany: async (args: unknown) => { calls.push(['findMany', args]); return [provider]; },
    },
    $queryRaw: async (query: unknown) => { statements.push(sqlText(query)); return [{ id: 'provider-1' }]; },
  } as unknown as Prisma.TransactionClient;
  const service = new ProviderReadService();

  assert.equal(await service.getProvider(client, 'provider-1'), provider);
  assert.equal(await service.getProviderByUserId(client, 'user-1'), provider);
  assert.deepEqual(await service.getProviders(client, ['provider-1', 'provider-2']), [provider]);
  assert.deepEqual(await service.getProviders(client, []), []);
  assert.deepEqual(await service.filterProviderIdsByBusinessName(client, ['provider-1'], 'hal'), ['provider-1']);
  assert.deepEqual(await service.filterProviderIdsByBusinessName(client, [], 'hal'), []);
  assert.deepEqual(await service.lockProviderRowsForShareInTransaction(client, ['provider-2', 'provider-1', 'provider-1']), [{ id: 'provider-1' }]);
  assert.deepEqual(await service.lockProviderRowsForShareInTransaction(client, []), []);

  assert.deepEqual(calls, [
    ['findUnique', { where: { id: 'provider-1' } }],
    ['findUnique', { where: { userId: 'user-1' } }],
    ['findMany', { where: { id: { in: ['provider-1', 'provider-2'] } } }],
    ['findMany', {
      where: { id: { in: ['provider-1'] }, businessName: { contains: 'hal', mode: 'insensitive' } },
      select: { id: true },
    }],
  ]);
  assert.deepEqual(statements, [
    'SELECT "id" FROM "Provider" WHERE "id" IN (?,?) ORDER BY "id" ASC FOR SHARE',
  ]);
});

test('the quote read port reads offers with their request and locks offer rows for update', async () => {
  const calls: Array<[string, unknown]> = [];
  const statements: string[] = [];
  const offer = { id: 'offer-1', providerId: 'provider-1', quoteRequest: { id: 'request-1' } };
  const client = {
    quoteOffer: {
      findUnique: async (args: unknown) => { calls.push(['findUnique', args]); return offer; },
      findMany: async (args: unknown) => { calls.push(['findMany', args]); return [{ id: 'offer-1', providerId: 'provider-1' }]; },
    },
    $queryRaw: async (query: unknown) => { statements.push(sqlText(query)); return [{ id: 'offer-1', providerId: 'provider-1' }]; },
  } as unknown as Prisma.TransactionClient;
  const service = new QuoteReadService();

  assert.equal(await service.getQuoteOfferWithRequest(client, 'offer-1'), offer);
  assert.deepEqual(await service.getQuoteOfferProviders(client, ['offer-1']), [{ id: 'offer-1', providerId: 'provider-1' }]);
  assert.deepEqual(await service.getQuoteOfferProviders(client, []), []);
  assert.deepEqual(await service.lockQuoteOfferRowsForUpdateInTransaction(client, ['offer-1']), [{ id: 'offer-1', providerId: 'provider-1' }]);
  assert.deepEqual(await service.lockQuoteOfferRowsForUpdateInTransaction(client, []), []);

  assert.deepEqual(calls, [
    ['findUnique', { where: { id: 'offer-1' }, include: { quoteRequest: true } }],
    ['findMany', { where: { id: { in: ['offer-1'] } }, select: { id: true, providerId: true } }],
  ]);
  assert.deepEqual(statements, [
    'SELECT "id", "providerId" FROM "QuoteOffer" WHERE "id" IN (?) ORDER BY "id" ASC FOR UPDATE',
  ]);
});

test('the marketplace read public modules expose only their port tokens bound to the internal implementations', () => {
  const metadata = (module: unknown, key: string) => Reflect.getMetadata(key, module as object);
  assert.deepEqual(metadata(ProviderReadPublicModule, MODULE_METADATA.PROVIDERS), [
    { provide: PROVIDER_READ_PORT, useExisting: PROVIDER_READ_IMPLEMENTATION },
  ]);
  assert.deepEqual(metadata(ProviderReadPublicModule, MODULE_METADATA.EXPORTS), [PROVIDER_READ_PORT]);
  assert.deepEqual(metadata(ProviderReadPublicModule, MODULE_METADATA.IMPORTS), [MarketplaceReadInternalModule]);
  assert.deepEqual(metadata(QuoteReadPublicModule, MODULE_METADATA.PROVIDERS), [
    { provide: QUOTE_READ_PORT, useExisting: QUOTE_READ_IMPLEMENTATION },
  ]);
  assert.deepEqual(metadata(QuoteReadPublicModule, MODULE_METADATA.EXPORTS), [QUOTE_READ_PORT]);
  assert.deepEqual(metadata(QuoteReadPublicModule, MODULE_METADATA.IMPORTS), [MarketplaceReadInternalModule]);
  assert.deepEqual(metadata(MarketplaceReadInternalModule, MODULE_METADATA.PROVIDERS), [
    ProviderReadService,
    QuoteReadService,
    { provide: PROVIDER_READ_IMPLEMENTATION, useExisting: ProviderReadService },
    { provide: QUOTE_READ_IMPLEMENTATION, useExisting: QuoteReadService },
  ]);
});

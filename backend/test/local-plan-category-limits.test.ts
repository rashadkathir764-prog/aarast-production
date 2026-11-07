import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { plainToInstance } from 'class-transformer';
import { validate } from 'class-validator';
import { CompleteOnboardingDto } from '../src/onboarding/dto/complete-onboarding.dto';
import { ImportLocalPlanDto } from '../src/onboarding/dto/import-local-plan.dto';
import { WeddingPlansService } from '../src/wedding-plans/wedding-plans.service';
import { collaborationHistory, planningOwnerPorts } from './support/owner-ports';

// J1-13: a phone plan carries every starter item it picked (the managed
// catalogue offers up to 26 per persona) plus the items its owner added; the
// account must take all of them, never reject the plan nor drop an item.

const names = (count: number, prefix = 'بند') =>
  Array.from({ length: count }, (_, index) => `${prefix} ${index + 1}`);

async function selectedCategoryErrors(
  Dto: typeof CompleteOnboardingDto | typeof ImportLocalPlanDto,
  selectedCategories: string[],
) {
  const errors = await validate(
    plainToInstance(Dto, {
      clientMigrationId: 'local-import-limits',
      selectedCategories,
    }),
  );
  return errors.filter((error) => error.property === 'selectedCategories');
}

for (const Dto of [CompleteOnboardingDto, ImportLocalPlanDto]) {
  test(`${Dto.name} takes a full starter catalogue plus added items (40 and 60), not 61`, async () => {
    assert.deepEqual(await selectedCategoryErrors(Dto, names(40)), []);
    assert.deepEqual(await selectedCategoryErrors(Dto, names(60)), []);
    const [tooMany] = await selectedCategoryErrors(Dto, names(61));
    assert.ok(tooMany?.constraints?.arrayMaxSize, ' 61 items are refused');
  });

  test(`${Dto.name} takes an item name as long as a budget item's (120), not 121`, async () => {
    assert.deepEqual(
      await selectedCategoryErrors(Dto, ['ب'.repeat(120)]),
      [],
    );
    const [tooLong] = await selectedCategoryErrors(Dto, ['ب'.repeat(121)]);
    // RA-BE-16: the rule is `maxCharacters` now, counted as the phone counts;
    // the old `maxLength` counted marks and refused names the phone took.
    assert.ok(tooLong?.constraints?.maxCharacters, 'a 121-character name is refused');
  });
}

// J1-09: an imported agreement's title obeys the same limit as one made in
// the account (160), so what the import takes can be edited afterwards.
test('an imported agreement title is capped like an agreement made later (160), not 200', async () => {
  const errorsFor = async (title: string) => {
    const errors = await validate(
      plainToInstance(ImportLocalPlanDto, {
        clientMigrationId: 'local-import-title',
        selectedCategories: ['القاعة'],
        costs: [{ title, totalAmount: '1000', categoryName: 'القاعة' }],
      }),
    );
    return errors.filter((error) => error.property === 'costs');
  };
  assert.deepEqual(await errorsFor('ع'.repeat(160)), []);
  assert.ok(
    (await errorsFor('ع'.repeat(161))).length > 0,
    'a 161-character title is refused',
  );
});

/** The plan service up to the moment it creates the plan's items. */
function serviceRecordingItems() {
  const created: string[][] = [];
  const stop = new Error('items recorded');
  const tx = {
    $queryRaw: async () => [{ id: 'owner-1', status: 'ACTIVE', deletionPending: false }],
    weddingPlan: {
      create: async ({ data }: { data: Record<string, unknown> }) => ({
        id: 'plan-new',
        ...data,
      }),
    },
  };
  const prisma = {
    $transaction: async (work: (client: unknown) => Promise<unknown>) => work(tx),
    weddingPlan: { findFirst: async () => null },
  };
  const [users, activePlan, , tasks, guests] = planningOwnerPorts;
  const finance = {
    createBudgetCategoriesInTransaction: async (
      _client: unknown,
      _planId: string,
      itemNames: string[],
    ) => {
      created.push(itemNames);
      throw stop;
    },
  };
  const service = new WeddingPlansService(
    prisma as any,
    {} as any,
    collaborationHistory({ createHistoryScopeInTransaction: async () => undefined }) as any,
    users,
    activePlan,
    finance as any,
    tasks,
    guests,
  );
  return { service, created, stop };
}

test('onboarding creates every selected item, beyond the old 25', async () => {
  const { service, created, stop } = serviceRecordingItems();
  await assert.rejects(
    service.completeOnboarding({ id: 'owner-1' } as any, {
      persona: 'GROOM',
      selectedCategories: names(40),
    } as any),
    (error) => error === stop,
  );
  assert.equal(created[0]?.length, 40);
});

test('a local plan import creates every picked item and every agreement\'s item, beyond the old 50', async () => {
  const { service, created, stop } = serviceRecordingItems();
  await assert.rejects(
    service.importLocalPlan({ id: 'owner-1' } as any, {
      clientMigrationId: 'local-import-limits',
      persona: 'GROOM',
      selectedCategories: names(60),
      costs: names(5, 'اتفاق').map((title, index) => ({
        title,
        totalAmount: '1000',
        categoryName: `بند مضاف ${index + 1}`,
      })),
    } as any),
    (error) => error === stop,
  );
  assert.equal(created[0]?.length, 65);
});

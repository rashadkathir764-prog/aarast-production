import 'reflect-metadata';

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { MODULE_METADATA } from '@nestjs/common/constants';
import {
  GuestAttendanceStatus,
  GuestInvitationStatus,
  GuestSide,
  GuestStatus,
  type Prisma,
  WeddingTaskPriority,
  WeddingTaskStatus,
} from '@prisma/client';
import {
  GUESTS_IMPLEMENTATION,
  GuestsPortInternalModule,
} from '../src/modules/guests/internal/guests-port.internal.module';
import { GuestsPortService } from '../src/modules/guests/infrastructure/guests-port.service';
import { GuestsPublicModule } from '../src/modules/guests/public/guests-public.module';
import { GUESTS_PORT } from '../src/modules/guests/public/guests.port';
import {
  TASKS_IMPLEMENTATION,
  TasksPortInternalModule,
} from '../src/modules/tasks/internal/tasks-port.internal.module';
import { TasksPortService } from '../src/modules/tasks/infrastructure/tasks-port.service';
import { TasksPublicModule } from '../src/modules/tasks/public/tasks-public.module';
import { TASKS_PORT } from '../src/modules/tasks/public/tasks.port';

// Planning's local plan import ran these statements itself; the owners run
// them now on the import transaction with the same data and options.

test('the tasks port creates imported tasks for the plan and counts them', async () => {
  const calls: Array<[string, unknown]> = [];
  const tx = {
    weddingTask: {
      createMany: async (args: unknown) => { calls.push(['createMany', args]); return { count: 1 }; },
      count: async (args: unknown) => { calls.push(['count', args]); return 3; },
    },
  } as unknown as Prisma.TransactionClient;
  const service = new TasksPortService();
  const task = {
    title: 'Book the hall', description: null, dueDate: null, taskCategory: null, reminderAt: null,
    status: WeddingTaskStatus.TODO, priority: WeddingTaskPriority.MEDIUM,
  };
  await service.createImportedTasksInTransaction(tx, 'plan-1', [task]);
  await service.createImportedTasksInTransaction(tx, 'plan-1', []);
  assert.equal(await service.countPlanTasks(tx, 'plan-1'), 3);
  assert.deepEqual(calls, [
    ['createMany', { data: [{ weddingPlanId: 'plan-1', ...task }] }],
    ['count', { where: { weddingPlanId: 'plan-1' } }],
  ]);
});

test('the guests port creates imported guests skipping duplicates and counts them', async () => {
  const calls: Array<[string, unknown]> = [];
  const tx = {
    guest: {
      createMany: async (args: unknown) => { calls.push(['createMany', args]); return { count: 1 }; },
      count: async (args: unknown) => { calls.push(['count', args]); return 2; },
    },
  } as unknown as Prisma.TransactionClient;
  const service = new GuestsPortService();
  const guest = {
    name: 'Guest', normalizedName: 'Guest', phone: null, normalizedPhone: null, side: GuestSide.OTHER,
    status: GuestStatus.INVITED, invitationStatus: GuestInvitationStatus.NOT_SENT,
    attendanceStatus: GuestAttendanceStatus.PENDING, seatsCount: 1, companionsCount: 0, notes: null,
  };
  await service.createImportedGuestsInTransaction(tx, 'plan-1', [guest]);
  await service.createImportedGuestsInTransaction(tx, 'plan-1', []);
  assert.equal(await service.countPlanGuests(tx, 'plan-1'), 2);
  assert.deepEqual(calls, [
    ['createMany', { data: [{ weddingPlanId: 'plan-1', ...guest }], skipDuplicates: true }],
    ['count', { where: { weddingPlanId: 'plan-1' } }],
  ]);
});

test('the tasks and guests public modules expose only their port tokens bound to the internal implementations', () => {
  const metadata = (module: unknown, key: string) => Reflect.getMetadata(key, module as object);
  assert.deepEqual(metadata(TasksPublicModule, MODULE_METADATA.PROVIDERS), [{ provide: TASKS_PORT, useExisting: TASKS_IMPLEMENTATION }]);
  assert.deepEqual(metadata(TasksPublicModule, MODULE_METADATA.EXPORTS), [TASKS_PORT]);
  assert.deepEqual(metadata(TasksPortInternalModule, MODULE_METADATA.PROVIDERS), [
    TasksPortService, { provide: TASKS_IMPLEMENTATION, useExisting: TasksPortService },
  ]);
  assert.deepEqual(metadata(GuestsPublicModule, MODULE_METADATA.PROVIDERS), [{ provide: GUESTS_PORT, useExisting: GUESTS_IMPLEMENTATION }]);
  assert.deepEqual(metadata(GuestsPublicModule, MODULE_METADATA.EXPORTS), [GUESTS_PORT]);
  assert.deepEqual(metadata(GuestsPortInternalModule, MODULE_METADATA.PROVIDERS), [
    GuestsPortService, { provide: GUESTS_IMPLEMENTATION, useExisting: GuestsPortService },
  ]);
});

import assert from 'node:assert/strict';
import { test } from 'node:test';
import { NotificationRemindersScheduler } from '../src/notifications/notification-reminders.scheduler';

test('reminder scheduler delegates one durable scan per tick', async () => {
  let calls = 0;
  const scheduler = new NotificationRemindersScheduler({
    generateDueNotifications: async () => {
      calls++;
      return 3;
    },
  } as any);

  await scheduler.generateDueReminders();
  assert.equal(calls, 1);
});

test('reminder scheduler accepts a replica lock miss without retrying locally', async () => {
  let calls = 0;
  const scheduler = new NotificationRemindersScheduler({
    generateDueNotifications: async () => {
      calls++;
      return null;
    },
  } as any);

  await scheduler.generateDueReminders();
  assert.equal(calls, 1);
});

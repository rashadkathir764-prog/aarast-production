import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { BadRequestException } from "@nestjs/common";
import { UsersService } from "../src/users/users.service";

const currentUser = {
  id: "user-1",
  name: "رشاد",
  phone: "+967700000001",
} as any;

function preference(overrides: Record<string, unknown> = {}) {
  const now = new Date();
  return {
    id: "preference-1",
    userId: currentUser.id,
    pushEnabled: true,
    smsEnabled: false,
    whatsappEnabled: false,
    emailEnabled: false,
    taskRemindersEnabled: true,
    paymentRemindersEnabled: true,
    providerMessagesEnabled: true,
    createdAt: now,
    updatedAt: now,
    ...overrides,
  };
}

function harness({ pushSupported = false, preferenceOverrides = {} }: {
  pushSupported?: boolean;
  preferenceOverrides?: Record<string, unknown>;
} = {}) {
  let writes = 0;
  let lastUpsert: any;
  const events: string[] = [];
  const notificationPreference = {
    upsert: async (input: any) => {
      events.push("upsert");
      writes += 1;
      lastUpsert = input;
      return preference({
        ...preferenceOverrides,
        ...input.create,
        ...input.update,
      });
    },
  };
  const transactionClient = {
    $queryRaw: async () => {
      events.push("lock-user");
      return [{ id: currentUser.id, status: "ACTIVE" }];
    },
    notificationPreference,
  };
  const prisma = {
    notificationPreference,
    $transaction: async (
      operation: (tx: typeof transactionClient) => unknown,
    ) => operation(transactionClient),
  };
  return {
    service: new UsersService(
      prisma as any,
      {} as any,
      {} as any,
      undefined,
      { enabled: pushSupported } as any,
    ),
    writes: () => writes,
    lastUpsert: () => lastUpsert,
    events: () => events,
  };
}

test("settings report push unsupported when runtime push delivery is disabled", async () => {
  const { service } = harness();

  const settings = await service.getSettings(currentUser);

  assert.deepEqual(settings.channelCapabilities, {
    inApp: { supported: true, configurable: false, enabled: true },
    push: { supported: false, configurable: false, enabled: true },
    sms: { supported: false, configurable: false, enabled: false },
    whatsapp: { supported: false, configurable: false, enabled: false },
    email: { supported: false, configurable: false, enabled: false },
  });
  assert.equal(settings.pushEnabled, true);
});

test("settings separate runtime push support from the user's installation", async () => {
  const { service } = harness({
    pushSupported: true,
    preferenceOverrides: { pushEnabled: false },
  });

  const settings = await service.getSettings(currentUser);

  assert.deepEqual(settings.channelCapabilities.push, {
    supported: true,
    configurable: false,
    enabled: false,
  });
  assert.equal(settings.pushEnabled, false);
});

test("unsupported notification channels cannot be enabled", async () => {
  for (const [field, channel] of [
    ["smsEnabled", "sms"],
    ["whatsappEnabled", "whatsapp"],
    ["emailEnabled", "email"],
  ] as const) {
    const { service, writes } = harness();
    await assert.rejects(
      () => service.updateSettings(currentUser, { [field]: true }),
      (error: unknown) => {
        assert.ok(error instanceof BadRequestException);
        const response = error.getResponse();
        assert.equal(typeof response, "object");
        assert.equal(
          (response as { code?: unknown }).code,
          "NOTIFICATION_CHANNEL_UNSUPPORTED",
        );
        assert.equal((response as { channel?: unknown }).channel, channel);
        return true;
      },
    );
    assert.equal(writes(), 0);
  }
});

test("push enablement is controlled by the device registration", async () => {
  const { service, writes } = harness();

  await assert.rejects(
    () => service.updateSettings(currentUser, { pushEnabled: true }),
    (error: unknown) => {
      assert.ok(error instanceof BadRequestException);
      const response = error.getResponse();
      assert.equal(typeof response, "object");
      assert.equal(
        (response as { code?: unknown }).code,
        "NOTIFICATION_CHANNEL_DEVICE_MANAGED",
      );
      assert.equal((response as { channel?: unknown }).channel, "push");
      return true;
    },
  );
  assert.equal(writes(), 0);
});

test("supported content preferences remain writable while device-managed push is preserved", async () => {
  const { service, lastUpsert, events } = harness();

  const settings = await service.updateSettings(currentUser, {
    pushEnabled: false,
    smsEnabled: false,
    whatsappEnabled: false,
    emailEnabled: false,
    taskRemindersEnabled: false,
    paymentRemindersEnabled: false,
    providerMessagesEnabled: false,
  });

  assert.equal(settings.taskRemindersEnabled, false);
  assert.equal(settings.paymentRemindersEnabled, false);
  assert.equal(settings.providerMessagesEnabled, false);
  assert.equal(settings.pushEnabled, true);
  assert.equal(settings.smsEnabled, false);
  assert.equal(settings.whatsappEnabled, false);
  assert.equal(settings.emailEnabled, false);
  assert.deepEqual(events(), ["lock-user", "upsert"]);
  assert.deepEqual(lastUpsert().update, {
    smsEnabled: false,
    whatsappEnabled: false,
    emailEnabled: false,
    taskRemindersEnabled: false,
    paymentRemindersEnabled: false,
    providerMessagesEnabled: false,
  });
});

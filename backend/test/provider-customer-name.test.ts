import "reflect-metadata";

import assert from "node:assert/strict";
import { test } from "node:test";
import { UserRole } from "@prisma/client";
import { ConversationsService } from "../src/conversations/conversations.service";
import {
  bookingProviderNotification,
  bookingReminderNotifications,
} from "../src/marketplace/booking-notifications";
import { quoteSubmittedProviderNotification } from "../src/marketplace/quote-notifications";
import { customerNameForProvider } from "../src/shared-kernel/privacy/provider-customer-name";

// RA-BE-168: one rule for the customer's name in front of a provider: the
// first name and the family's initial, in the plan's header, the chat, the
// request and every notice.

test("the first name and the family's initial; the article is no part of the letter", () => {
  assert.equal(customerNameForProvider("محمد الحمدي"), "محمد ح.");
  assert.equal(customerNameForProvider("  محمد   علي  الحمدي "), "محمد ح.");
  assert.equal(customerNameForProvider("سلمى أحمد"), "سلمى أ.");
});

test("a single name stays, nothing gives nothing, and writing it twice is the same", () => {
  assert.equal(customerNameForProvider("محمد"), "محمد");
  assert.equal(customerNameForProvider("   "), null);
  assert.equal(customerNameForProvider(null), null);
  assert.equal(customerNameForProvider("محمد ح."), "محمد ح.");
});

test("every notice a provider reads names the customer the same way", () => {
  const name = "محمد الحمدي";
  const ids = { quoteId: "q", providerId: "p", providerUserId: "u" };
  assert.equal(
    quoteSubmittedProviderNotification({ ...ids, customerName: name }).title,
    "طلب جديد من محمد ح.",
  );
  const booking = {
    bookingId: "b",
    quoteRequestId: "q",
    providerId: "p",
    providerUserId: "u",
    eventDate: new Date("2027-02-18T00:00:00Z"),
    revision: 1,
    customerName: name,
  };
  assert.match(String(bookingProviderNotification("REQUESTED", booking).title), /^طلب حجز من محمد ح\.$/u);
  assert.ok(bookingReminderNotifications);
});

function conversations(): any {
  return new ConversationsService(
    {} as never,
    {} as never,
    {} as never,
    { createDownloadUrl: async () => ({ downloadUrl: "u", expiresAt: new Date() }) } as never,
    {} as never,
    {} as never,
  );
}

test("the provider's request and chat carry the shortened name, the customer's own side the whole one", () => {
  const service = conversations();
  const quote = {
    id: "q",
    user: { id: "u", name: "محمد الحمدي", appName: null, role: UserRole.USER, avatarUrl: null, appAvatarUrl: null },
    offers: [],
    budgetMin: null,
    budgetMax: null,
    contactName: "محمد علي الحمدي",
    contactPhone: null,
    contactNormalizedPhone: null,
    shareBudget: false,
    shareContact: false,
  };
  const access = (side: "PROVIDER" | "CUSTOMER") => ({
    side,
    canManageProviders: true,
    canViewMoney: true,
    canManageMoney: false,
    canViewContact: true,
  });
  const asProvider = service.toQuoteRequestResponse(quote, access("PROVIDER"));
  assert.equal(asProvider.user.name, "محمد ح.");
  assert.equal(asProvider.contactName, "محمد ح.");
  const asCustomer = service.toQuoteRequestResponse(quote, access("CUSTOMER"));
  assert.equal(asCustomer.contactName, "محمد علي الحمدي");
});

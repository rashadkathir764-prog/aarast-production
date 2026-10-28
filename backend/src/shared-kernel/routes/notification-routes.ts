import type { NotificationType } from '@prisma/client';

/**
 * B-19: every notice opens the exact screen it is about, on the phone's own
 * routes (`mobile/lib/core/routing/app_router*.dart`). The server writes the
 * route once, here; the phone opens it as it is.
 *
 * `NOTIFICATION_ROUTES` lists, for every notification type, the route shapes
 * a notice of that type may carry (`:name` is an id, `?key=:name` a query the
 * screen reads). A type with no route is emitted by no code; the tests
 * (`test/notification-routes.test.ts` and the phone's
 * `notification_routes_contract_test.dart`) read this table: every builder's
 * route matches its type's shapes, every shape is a registered phone route,
 * and every listed-empty type is written nowhere in `src`. Keep one entry per
 * line: the phone's test reads the lines.
 */
export const NOTIFICATION_ROUTES = {
  QUOTE_REQUEST_SUBMITTED: ['/wedding-plans/:planId/providers/requests?quote=:quoteRequestId', '/providers?quoteId=:quoteRequestId', '/provider/requests/:quoteRequestId'],
  TASK_ASSIGNED: ['/wedding-plans/:planId/tasks/:taskId'],
  TASK_DUE_SOON: ['/wedding-plans/:planId/tasks/:taskId'],
  TASK_OVERDUE: ['/wedding-plans/:planId/tasks/:taskId'],
  PAYMENT_SCHEDULE_DUE_SOON: ['/wedding-plans/:planId/money/costs/:costId'],
  PAYMENT_SCHEDULE_OVERDUE: ['/wedding-plans/:planId/money/costs/:costId'],
  SHARING_INVITATION: ['/invites/:inviteId', '/wedding-plans/:planId/dashboard'],
  SHARING_UPDATED: [],
  SHARING_INVITE_ACCEPTED: ['/wedding-plans/:planId/sharing'],
  SHARING_INVITE_DECLINED: ['/wedding-plans/:planId/sharing'],
  QUOTE_OFFER_RECEIVED: ['/wedding-plans/:planId/providers/requests?quote=:quoteRequestId', '/providers?quoteId=:quoteRequestId'],
  QUOTE_ACCEPTED: ['/wedding-plans/:planId/providers/requests?quote=:quoteRequestId', '/providers?quoteId=:quoteRequestId', '/provider/requests/:quoteRequestId'],
  QUOTE_REJECTED: ['/wedding-plans/:planId/providers/requests?quote=:quoteRequestId', '/providers?quoteId=:quoteRequestId', '/provider/requests/:quoteRequestId'],
  PLAN_UPDATED: ['/home', '/wedding-plans/:planId/dashboard'],
  SYNC_REQUIRED: [],
  CHAT_MESSAGE_RECEIVED: ['/conversations/:conversationId'],
  GENERAL: [],
  BUDGET_CATEGORY_EXCEEDED: ['/wedding-plans/:planId/money/categories/:categoryId'],
  LOAN_REPAYMENT_DUE_SOON: ['/wedding-plans/:planId/money/funding'],
  LOAN_REPAYMENT_OVERDUE: ['/wedding-plans/:planId/money/funding'],
  WEDDING_COUNTDOWN: ['/wedding-plans/:planId/dashboard'],
  BOOKING_UPDATED: ['/wedding-plans/:planId/providers/requests?quote=:quoteRequestId', '/providers?quoteId=:quoteRequestId', '/provider/requests/:quoteRequestId', '/wedding-plans/:planId/providers/requests', '/providers', '/provider/dashboard?tab=:tab'],
  GUEST_RESPONDED: ['/wedding-plans/:planId/guests/view/:guestId'],
  QUOTE_REQUEST_EXPIRING: ['/provider/requests/:quoteRequestId'],
  BOOKING_REQUESTED: ['/provider/requests/:quoteRequestId'],
  REVIEW_RECEIVED: ['/provider/reviews/:reviewId'],
  REVIEW_REPLIED: ['/providers/:providerId'],
  PROVIDER_APPROVED: ['/provider/dashboard'],
  PROVIDER_NEEDS_CHANGES: ['/provider/dashboard'],
  PROVIDER_REJECTED: ['/provider/dashboard'],
  PROVIDER_SUSPENDED: ['/provider/dashboard'],
  PROVIDER_IN_REVIEW: ['/provider/dashboard'],
  PROVIDER_CLAIM_DECIDED: ['/provider/dashboard', '/provider/apply'],
  LISTING_PLAN_CHANGED: ['/provider/dashboard?tab=:tab'],
  PORTFOLIO_REVIEWED: ['/provider/gallery'],
} as const satisfies Record<NotificationType, readonly string[]>;

const part = (value: string) => encodeURIComponent(value);

/** The routes notices carry, built once (the shapes above). */
export const noticeRoutes = {
  /** f04: the customer's request, its offers and its booking. */
  customerRequest(weddingPlanId: string | null, quoteRequestId: string): string {
    return weddingPlanId
      ? `/wedding-plans/${part(weddingPlanId)}/providers/requests?quote=${part(quoteRequestId)}`
      : `/providers?quoteId=${part(quoteRequestId)}`;
  },
  /** f01: the plan's requests, when the request itself is gone (B-33: its provider closed his account). */
  customerRequests(weddingPlanId: string | null): string {
    return weddingPlanId
      ? `/wedding-plans/${part(weddingPlanId)}/providers/requests`
      : '/providers';
  },
  /** p16/p19: one request as the provider sees it (D39). */
  providerRequest(quoteRequestId: string): string {
    return `/provider/requests/${part(quoteRequestId)}`;
  },
  task(weddingPlanId: string, taskId: string): string {
    return `/wedding-plans/${part(weddingPlanId)}/tasks/${part(taskId)}`;
  },
  /** c07: an agreement, which lists every payment date. */
  cost(weddingPlanId: string, costId: string): string {
    return `/wedding-plans/${part(weddingPlanId)}/money/costs/${part(costId)}`;
  },
  budgetItem(weddingPlanId: string, categoryId: string): string {
    return `/wedding-plans/${part(weddingPlanId)}/money/categories/${part(categoryId)}`;
  },
  funding(weddingPlanId: string): string {
    return `/wedding-plans/${part(weddingPlanId)}/money/funding`;
  },
  /** The app's home, for a plan the reader can no longer open (D63). */
  home(): string {
    return '/home';
  },
  /** p15: the provider's requests tab, when the request itself is gone (D63: its customer closed his account). */
  providerRequests(): string {
    return '/provider/dashboard?tab=requests';
  },
  planHome(weddingPlanId: string): string {
    return `/wedding-plans/${part(weddingPlanId)}/dashboard`;
  },
  guest(weddingPlanId: string, guestId: string): string {
    return `/wedding-plans/${part(weddingPlanId)}/guests/view/${part(guestId)}`;
  },
  sharing(weddingPlanId: string): string {
    return `/wedding-plans/${part(weddingPlanId)}/sharing`;
  },
  invite(inviteId: string): string {
    return `/invites/${part(inviteId)}`;
  },
  conversation(conversationId: string): string {
    return `/conversations/${part(conversationId)}`;
  },
  /** The provider's portal; the portal shows the screen of his status. */
  providerPortal(): string {
    return '/provider/dashboard';
  },
  /** p35 «ملفي», where his featured placement shows. */
  providerProfile(): string {
    return '/provider/dashboard?tab=profile';
  },
  /** p37 «معرض الشغل»: his photos, each approved, waiting or refused with its reason (B-16). */
  providerPortfolio(): string {
    return '/provider/gallery';
  },
  /** The joining screen, where a refused claim is read (p02). */
  providerApply(): string {
    return '/provider/apply';
  },
  /** p27: one review of his, and his reply. */
  providerReview(reviewId: string): string {
    return `/provider/reviews/${part(reviewId)}`;
  },
  /** f03: a provider's page as customers read it, with its reviews. */
  providerPage(providerId: string): string {
    return `/providers/${part(providerId)}`;
  },
} as const;

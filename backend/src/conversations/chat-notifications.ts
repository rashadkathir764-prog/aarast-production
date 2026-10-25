import { NotificationPriority, NotificationType } from '@prisma/client';
import type { CreateNotificationInput } from '../modules/notifications/public/notifications.port';
import { noticeRoutes } from '../shared-kernel/routes/notification-routes';

/**
 * A new message in a request's conversation, for one side (the provider or
 * a customer-side member). The words carry no name and no message text: the
 * conversation shows them to whoever may read it. Pure, no Prisma.
 */
export function chatMessageNotification(args: {
  recipientId: string;
  weddingPlanId: string | null;
  conversationId: string;
  providerId: string;
  recipientIsProvider: boolean;
  messageId: string;
}): CreateNotificationInput {
  return {
    userId: args.recipientId,
    weddingPlanId: args.weddingPlanId,
    type: NotificationType.CHAT_MESSAGE_RECEIVED,
    priority: NotificationPriority.NORMAL,
    title: 'رسالة جديدة',
    body: 'وصلتك رسالة في محادثة الطلب.',
    entityType: 'conversation',
    entityId: args.conversationId,
    routeTarget: noticeRoutes.conversation(args.conversationId),
    data: {
      conversationId: args.conversationId,
      providerId: args.providerId,
      recipientAudience: args.recipientIsProvider ? 'PROVIDER' : 'CUSTOMER',
      ...(args.weddingPlanId ? { weddingPlanId: args.weddingPlanId } : {}),
      messageId: args.messageId,
    },
    dedupeKey: `chat:${args.messageId}:${args.recipientId}`,
  };
}

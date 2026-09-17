import { Inject, Injectable } from '@nestjs/common';
import {
  ConversationScope,
  type ChatAttachment,
  type ChatMessage,
  type Conversation,
  type ConversationParticipant,
  type Prisma,
  type ProviderStatus,
  type SharedMemberRole,
  type WeddingPlanStatus,
} from '@prisma/client';
import {
  COLLABORATION_PERMISSION_PORT,
  type CollaborationPermissionPort,
} from '../modules/collaboration/public/collaboration-permission.port';
import {
  type AppIdentity,
  USER_READ_PORT,
  type UserReadPort,
} from '../modules/identity/public/user-read.port';
import {
  PROVIDER_READ_PORT,
  type ProviderReadPort,
} from '../modules/marketplace/public/provider-read.port';
import {
  type ConversationQuoteRequest,
  QUOTE_READ_PORT,
  type QuoteReadPort,
} from '../modules/marketplace/public/quote-read.port';
import {
  PLAN_READ_PORT,
  type PlanReadPort,
} from '../modules/planning/public/plan-read.port';

// The rows a conversation shows besides its own: the provider and its
// account (marketplace, identity), the plan and its members (planning,
// collaboration), the account requester, the participants' and senders'
// identities (identity) and the quote requests it carries (marketplace).
// They used to arrive through one Prisma include; they are read through the
// owners' ports on the caller's client and attached in the same shape.

export interface ConversationProvider {
  id: string;
  userId: string | null;
  status: ProviderStatus;
  businessName: string;
  logoUrl: string | null;
  user: AppIdentity | null;
}

export interface ConversationPlanMember {
  userId: string;
  role: SharedMemberRole;
  canManageProviders: boolean;
  canViewMoney: boolean;
  canManageMoney: boolean;
}

export interface ConversationPlan {
  id: string;
  title: string;
  ownerUserId: string;
  status: WeddingPlanStatus;
  sharedMembers: ConversationPlanMember[];
}

export type MessageWithSender = ChatMessage & {
  sender: AppIdentity;
  attachments: ChatAttachment[];
};

export type QuoteRequestWithRequester = ConversationQuoteRequest & {
  user: AppIdentity;
};

/** The conversation's own rows the service reads before the owners' rows are attached. */
export const conversationOwnInclude = {
  participants: true,
  messages: {
    where: { deletedAt: null },
    orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
    take: 1,
    include: { attachments: { orderBy: { createdAt: 'asc' } } },
  },
} satisfies Prisma.ConversationInclude;

export type ConversationRow = Prisma.ConversationGetPayload<{
  include: typeof conversationOwnInclude;
}>;

export type ConversationRecord = Conversation & {
  provider: ConversationProvider;
  weddingPlan: ConversationPlan | null;
  accountRequester: AppIdentity | null;
  participants: Array<ConversationParticipant & { user: AppIdentity }>;
  quoteRequests: QuoteRequestWithRequester[];
  messages: MessageWithSender[];
  _count: { quoteRequests: number };
};

/** What a conversation mutation needs to know before it takes its locks. */
export interface ConversationIdentity {
  scope: ConversationScope;
  weddingPlanId: string | null;
  accountRequesterUserId: string | null;
  provider: { id: string; userId: string | null; status: ProviderStatus };
  weddingPlan: {
    ownerUserId: string;
    sharedMembers: Array<{ userId: string; canManageProviders: boolean }>;
  } | null;
}

@Injectable()
export class ConversationRelationsService {
  constructor(
    @Inject(PROVIDER_READ_PORT) readonly providers: ProviderReadPort,
    @Inject(USER_READ_PORT) private readonly users: UserReadPort,
    @Inject(PLAN_READ_PORT) readonly plans: PlanReadPort,
    @Inject(COLLABORATION_PERMISSION_PORT)
    readonly permissions: CollaborationPermissionPort,
    @Inject(QUOTE_READ_PORT) readonly quotes: QuoteReadPort,
  ) {}

  async attachConversationRelations(
    client: Prisma.TransactionClient,
    rows: ConversationRow[],
  ): Promise<ConversationRecord[]> {
    if (rows.length === 0) return [];
    const conversationIds = rows.map((row) => row.id);
    const providers = new Map(
      (
        await this.providers.getProviders(
          client,
          unique(rows.map((row) => row.providerId)),
        )
      ).map((provider) => [provider.id, provider]),
    );
    const plans = new Map(
      (
        await this.plans.getPlans(
          client,
          unique(rows.flatMap((row) => (row.weddingPlanId ? [row.weddingPlanId] : []))),
        )
      ).map((plan) => [plan.id, plan]),
    );
    const membersByPlan = new Map<string, ConversationPlanMember[]>();
    for (const member of await this.permissions.listPlanMembers(client, [...plans.keys()])) {
      const members = membersByPlan.get(member.weddingPlanId) ?? [];
      members.push({
        userId: member.userId,
        role: member.role,
        canManageProviders: member.canManageProviders,
        canViewMoney: member.canViewMoney,
        canManageMoney: member.canManageMoney,
      });
      membersByPlan.set(member.weddingPlanId, members);
    }
    const latestQuotes = new Map(
      (await this.quotes.getLatestConversationQuoteRequests(client, conversationIds)).map(
        (quote) => [quote.conversationId, quote],
      ),
    );
    const quoteCounts = new Map(
      (await this.quotes.countConversationQuoteRequests(client, conversationIds)).map(
        (count) => [count.conversationId, count.count],
      ),
    );
    const users = await this.identitiesFor(client, [
      ...[...providers.values()].flatMap((provider) => (provider.userId ? [provider.userId] : [])),
      ...rows.flatMap((row) => (row.accountRequesterUserId ? [row.accountRequesterUserId] : [])),
      ...rows.flatMap((row) => row.participants.map((participant) => participant.userId)),
      ...rows.flatMap((row) => row.messages.map((message) => message.senderUserId)),
      ...[...latestQuotes.values()].map((quote) => quote.userId),
    ]);
    return rows.map((row) => {
      const provider = required(providers.get(row.providerId), 'Conversation provider');
      const plan = row.weddingPlanId ? plans.get(row.weddingPlanId) : undefined;
      const latestQuote = latestQuotes.get(row.id);
      return {
        ...row,
        provider: {
          id: provider.id,
          userId: provider.userId,
          status: provider.status,
          businessName: provider.businessName,
          logoUrl: provider.logoUrl,
          user: provider.userId ? (users.get(provider.userId) ?? null) : null,
        },
        weddingPlan: plan
          ? {
              id: plan.id,
              title: plan.title,
              ownerUserId: plan.ownerUserId,
              status: plan.status,
              sharedMembers: membersByPlan.get(plan.id) ?? [],
            }
          : null,
        accountRequester: row.accountRequesterUserId
          ? (users.get(row.accountRequesterUserId) ?? null)
          : null,
        participants: row.participants.map((participant) => ({
          ...participant,
          user: required(users.get(participant.userId), 'Conversation participant'),
        })),
        quoteRequests: latestQuote
          ? [{ ...latestQuote, user: required(users.get(latestQuote.userId), 'Quote requester') }]
          : [],
        messages: row.messages.map((message) => ({
          ...message,
          sender: required(users.get(message.senderUserId), 'Message sender'),
        })),
        _count: { quoteRequests: quoteCounts.get(row.id) ?? 0 },
      };
    });
  }

  async attachMessageSenders<T extends ChatMessage & { attachments: ChatAttachment[] }>(
    client: Prisma.TransactionClient,
    messages: T[],
  ): Promise<Array<T & { sender: AppIdentity }>> {
    const users = await this.identitiesFor(client, messages.map((message) => message.senderUserId));
    return messages.map((message) => ({
      ...message,
      sender: required(users.get(message.senderUserId), 'Message sender'),
    }));
  }

  async attachQuoteRequesters<T extends ConversationQuoteRequest>(
    client: Prisma.TransactionClient,
    quotes: T[],
  ): Promise<Array<T & { user: AppIdentity }>> {
    const users = await this.identitiesFor(client, quotes.map((quote) => quote.userId));
    return quotes.map((quote) => ({
      ...quote,
      user: required(users.get(quote.userId), 'Quote requester'),
    }));
  }

  /** The immutable relation ids a mutation reads first, without a row lock. */
  async conversationIdentity(
    client: Prisma.TransactionClient,
    conversationId: string,
  ): Promise<ConversationIdentity | null> {
    const row = await client.conversation.findUnique({
      where: { id: conversationId },
      select: {
        scope: true,
        weddingPlanId: true,
        accountRequesterUserId: true,
        providerId: true,
      },
    });
    if (!row) return null;
    const provider = await this.providers.getProvider(client, row.providerId);
    if (!provider) return null;
    const plan = row.weddingPlanId ? await this.plans.getPlan(client, row.weddingPlanId) : null;
    const members = plan ? await this.permissions.listPlanMembers(client, [plan.id]) : [];
    return {
      scope: row.scope,
      weddingPlanId: row.weddingPlanId,
      accountRequesterUserId: row.accountRequesterUserId,
      provider: { id: provider.id, userId: provider.userId, status: provider.status },
      weddingPlan: plan
        ? {
            ownerUserId: plan.ownerUserId,
            sharedMembers: members.map((member) => ({
              userId: member.userId,
              canManageProviders: member.canManageProviders,
            })),
          }
        : null,
    };
  }

  private async identitiesFor(
    client: Prisma.TransactionClient,
    userIds: readonly string[],
  ): Promise<Map<string, AppIdentity>> {
    return new Map(
      (await this.users.getAppIdentities(client, unique(userIds))).map((user) => [user.id, user]),
    );
  }
}

function unique(ids: readonly string[]): string[] {
  return [...new Set(ids)];
}

function required<T>(value: T | undefined, label: string): T {
  // A required relation (the FK is NOT NULL) is missing only when the
  // owner's row disappeared between the two statements.
  if (value === undefined) throw new Error(`${label} not found`);
  return value;
}

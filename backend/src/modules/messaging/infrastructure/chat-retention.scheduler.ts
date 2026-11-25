import { Inject, Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import type { Prisma } from '@prisma/client';
import { PrismaService } from '../../../platform/database/prisma.service';
import { runSerializableTransaction } from '../../../platform/database/serializable-transaction';
import {
  MEDIA_STORAGE_PORT,
  type MediaStoragePort,
} from '../../media/public/media-storage.port';

/** RA-BE-179: chat messages are kept two years after their conversation's last activity. */
export const CHAT_MESSAGE_RETENTION_YEARS = 2;
const BATCH = 500;
/** A run takes at most this many batches; the rest waits for the next day. */
const MAX_BATCHES_PER_RUN = 40;

/** The instant before which a conversation's last activity is past the period (with a day's margin). */
export function chatRetentionCutoff(now: Date): Date {
  const before = new Date(now);
  before.setUTCFullYear(before.getUTCFullYear() - CHAT_MESSAGE_RETENTION_YEARS);
  before.setUTCDate(before.getUTCDate() - 1);
  return before;
}

/**
 * RA-BE-179: the messages of a conversation whose last activity was over two
 * years ago go, and so do their attachments (the files are scheduled for
 * deletion first, as an erased account's are). The conversation itself, its
 * participants and its request events stay; it simply holds no messages.
 * One batch is one transaction; returns how many messages it removed.
 */
export async function removeStaleChatMessagesBatch(
  tx: Prisma.TransactionClient,
  media: Pick<MediaStoragePort, 'scheduleChatAttachmentDeletion'>,
  now: Date,
): Promise<number> {
  const stale = await tx.chatMessage.findMany({
    where: { conversation: { lastActivityAt: { lt: chatRetentionCutoff(now) } } },
    orderBy: { id: 'asc' },
    select: { id: true, attachments: { select: { id: true } } },
    take: BATCH,
  });
  if (stale.length === 0) return 0;
  await media.scheduleChatAttachmentDeletion(
    stale.flatMap((message) => message.attachments.map((attachment) => attachment.id)),
    tx,
  );
  const result = await tx.chatMessage.deleteMany({
    where: { id: { in: stale.map((message) => message.id) } },
  });
  return result.count;
}

/** Daily retention of the chat messages (privacy page, «كم نحتفظ ببياناتك»). */
@Injectable()
export class ChatRetentionScheduler {
  private readonly logger = new Logger(ChatRetentionScheduler.name);

  constructor(
    private readonly prisma: PrismaService,
    @Inject(MEDIA_STORAGE_PORT) private readonly media: MediaStoragePort,
  ) {}

  @Cron('35 3 * * *')
  async removeStale(now: Date = new Date()): Promise<number> {
    let removed = 0;
    for (let batch = 0; batch < MAX_BATCHES_PER_RUN; batch += 1) {
      const count = await runSerializableTransaction(this.prisma, (tx) =>
        removeStaleChatMessagesBatch(tx, this.media, now),
      );
      removed += count;
      if (count < BATCH) break;
    }
    if (removed > 0) {
      this.logger.log(`Removed ${removed} chat message(s) from conversations idle over two years`);
    }
    return removed;
  }
}

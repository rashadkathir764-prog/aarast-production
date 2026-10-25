import { Inject, Injectable } from "@nestjs/common";
import { NotificationPriority, NotificationType } from "@prisma/client";
import {
  NOTIFICATIONS_PORT,
  type NotificationsPort,
} from "../modules/notifications/public/notifications.port";
import * as featured from "../modules/marketplace/infrastructure/featured-period.repository";
import {
  arabicDayLabel,
  FEATURED_ENDING_NOTICE_DAYS,
  featuredLastDay,
} from "../modules/marketplace/public/featured-placement";
import { PROVIDER_PORTAL_ROUTE } from "../modules/marketplace/public/provider-access-policy";
import { runSerializableTransaction } from "../platform/database/serializable-transaction";
import { PrismaService } from "../platform/database/prisma.service";

const BATCH_SIZE = 100;
const MAX_BATCHES_PER_RUN = 20;
const DAY_MS = 24 * 60 * 60 * 1000;

export interface FeaturedPeriodNoticesRun {
  warned: number;
  ended: number;
  failures: Array<{ featuredPeriodId: string; error: unknown }>;
}

type Notice = "ending" | "ended";

/**
 * B-43: the placement itself lapses at its end with no job (it is read at
 * request time). This job only tells the provider: once in the week before
 * the end, and once when it ended, unless a period booked right after
 * carries it on. Each period is marked in its own transaction from the state
 * it was read in, so a retry or a second instance tells him nothing twice.
 */
@Injectable()
export class FeaturedPeriodNoticesService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(NOTIFICATIONS_PORT)
    private readonly notifications: NotificationsPort,
  ) {}

  async run(now: Date = new Date()): Promise<FeaturedPeriodNoticesRun> {
    const result: FeaturedPeriodNoticesRun = { warned: 0, ended: 0, failures: [] };
    const until = new Date(now.getTime() + FEATURED_ENDING_NOTICE_DAYS * DAY_MS);
    await this.sweep(
      result,
      (take) => featured.listFeaturedPeriodIdsEndingSoon(this.prisma, now, until, take),
      (id) => this.tell(id, "ending", now),
      "warned",
    );
    await this.sweep(
      result,
      (take) => featured.listFeaturedPeriodIdsEnded(this.prisma, now, take),
      (id) => this.tell(id, "ended", now),
      "ended",
    );
    return result;
  }

  private async sweep(
    result: FeaturedPeriodNoticesRun,
    list: (take: number) => Promise<Array<{ id: string }>>,
    handle: (id: string) => Promise<boolean>,
    counter: "warned" | "ended",
  ): Promise<void> {
    const failed = new Set(result.failures.map((failure) => failure.featuredPeriodId));
    for (let batch = 0; batch < MAX_BATCHES_PER_RUN; batch += 1) {
      const due = (await list(BATCH_SIZE + failed.size)).filter((row) => !failed.has(row.id));
      if (due.length === 0) break;
      for (const { id } of due) {
        try {
          if (await handle(id)) result[counter] += 1;
        } catch (error) {
          failed.add(id);
          result.failures.push({ featuredPeriodId: id, error });
        }
      }
      if (due.length < BATCH_SIZE) break;
    }
  }

  /** Marks one period told; true when a notice went out. */
  private tell(id: string, notice: Notice, now: Date): Promise<boolean> {
    return runSerializableTransaction(this.prisma, async (tx) => {
      const period = await featured.lockFeaturedPeriodForUpdate(tx, id);
      if (!period || period.endedAt !== null) return false;
      const due =
        notice === "ending"
          ? period.endingNoticeAt === null &&
            period.startsAt.getTime() <= now.getTime() &&
            period.endsAt.getTime() > now.getTime() &&
            period.endsAt.getTime() <= now.getTime() + FEATURED_ENDING_NOTICE_DAYS * DAY_MS
          : period.endNoticeAt === null && period.endsAt.getTime() <= now.getTime();
      if (!due) return false;
      const marked =
        notice === "ending"
          ? await featured.markFeaturedEndingNotice(tx, id, now)
          : await featured.markFeaturedEndNotice(tx, id, now);
      if (marked.count !== 1) return false;
      // A renewal booked right after: nothing ends for him, so nothing to say.
      if (await featured.findFeaturedContinuation(tx, period)) return false;
      const userId = period.provider.userId;
      if (!userId) return false;
      const lastDay = arabicDayLabel(featuredLastDay(period.endsAt));
      await this.notifications.createNotificationInTransaction(tx, {
        userId,
        type: NotificationType.GENERAL,
        priority: notice === "ending" ? NotificationPriority.HIGH : NotificationPriority.NORMAL,
        title: notice === "ending" ? "ظهورك المميز ينتهي قريب" : "خلص ظهورك المميز",
        body:
          notice === "ending"
            ? `آخر يوم له ${lastDay}. لو تبي تجدده كلّم فريق اعّرست.`
            : "من اليوم ملفك يظهر عادي. لو تبي ترجع مميز كلّم فريق اعّرست.",
        entityType: "ProviderFeaturedPeriod",
        entityId: period.id,
        routeTarget: PROVIDER_PORTAL_ROUTE,
        data: {
          providerId: period.providerId,
          featuredPeriodId: period.id,
          featuredEvent: notice,
          recipientAudience: "PROVIDER",
        },
        dedupeKey: `featured-period:${period.id}:${notice}`,
      });
      return true;
    });
  }
}

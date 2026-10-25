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
  featuredRunAround,
  featuredRunWarnsBeforeEnd,
} from "../modules/marketplace/public/featured-placement";
import { noticeRoutes } from "../shared-kernel/routes/notification-routes";
import { runSerializableTransaction } from "../platform/database/serializable-transaction";
import { PrismaService } from "../platform/database/prisma.service";

const BATCH_SIZE = 100;
const MAX_BATCHES_PER_RUN = 20;
const DAY_MS = 24 * 60 * 60 * 1000;

export interface FeaturedPeriodNoticesRun {
  started: number;
  warned: number;
  ended: number;
  failures: Array<{ featuredPeriodId: string; error: unknown }>;
}

export type Notice = "started" | "ending" | "ended";

const COUNTER: Record<Notice, "started" | "warned" | "ended"> = {
  started: "started",
  ending: "warned",
  ended: "ended",
};

/**
 * B-43: the placement itself starts and lapses with no job (it is read at
 * request time). This job only tells the provider: once when a placement
 * booked for a later day starts, once in the week before the end of a run
 * longer than that week, and once when it ended, never where a renewal right
 * before or after carries the run on. What it says is true for him: when the
 * placement rule does not hold (he is not in the customers' list), it does
 * not tell him to renew or that he shows «عادي»; it says what is true or
 * nothing. Each period is marked in its own transaction from the state it
 * was read in, so a retry or a second instance tells him nothing twice.
 */
@Injectable()
export class FeaturedPeriodNoticesService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(NOTIFICATIONS_PORT)
    private readonly notifications: NotificationsPort,
  ) {}

  async run(now: Date = new Date()): Promise<FeaturedPeriodNoticesRun> {
    const result: FeaturedPeriodNoticesRun = { started: 0, warned: 0, ended: 0, failures: [] };
    const until = new Date(now.getTime() + FEATURED_ENDING_NOTICE_DAYS * DAY_MS);
    await this.sweep(
      result,
      (take) => featured.listFeaturedPeriodIdsStarted(this.prisma, now, take),
      (id) => this.tell(id, "started", now),
      "started",
    );
    await this.sweep(
      result,
      (take) => featured.listFeaturedPeriodIdsEndingSoon(this.prisma, now, until, take),
      (id) => this.tell(id, "ending", now),
      "ending",
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
    notice: Notice,
  ): Promise<void> {
    const failed = new Set(result.failures.map((failure) => failure.featuredPeriodId));
    for (let batch = 0; batch < MAX_BATCHES_PER_RUN; batch += 1) {
      const due = (await list(BATCH_SIZE + failed.size)).filter((row) => !failed.has(row.id));
      if (due.length === 0) break;
      for (const { id } of due) {
        try {
          if (await handle(id)) result[COUNTER[notice]] += 1;
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
      const at = now.getTime();
      const running = period.startsAt.getTime() <= at && period.endsAt.getTime() > at;
      const due = {
        started: period.startNoticeAt === null && running,
        ending:
          period.endingNoticeAt === null &&
          running &&
          period.endsAt.getTime() <= at + FEATURED_ENDING_NOTICE_DAYS * DAY_MS,
        ended: period.endNoticeAt === null && period.endsAt.getTime() <= at,
      }[notice];
      if (!due) return false;
      const marked = await {
        started: featured.markFeaturedStartNotice,
        ending: featured.markFeaturedEndingNotice,
        ended: featured.markFeaturedEndNotice,
      }[notice](tx, id, now);
      if (marked.count !== 1) return false;

      const run = featuredRunAround(
        await featured.listOpenFeaturedPeriods(tx, [period.providerId]),
        period.id,
      )!;
      // A renewal right before (started) or right after (ending, ended):
      // nothing starts or ends for him, so there is nothing to say.
      if (notice === "started" && run.startsAt.getTime() < period.startsAt.getTime()) return false;
      if (notice !== "started" && run.endsAt.getTime() > period.endsAt.getTime()) return false;
      // No «ينتهي قريب» for a run no longer than the week it warns about.
      if (notice === "ending" && !featuredRunWarnsBeforeEnd(run)) return false;
      const userId = period.provider.userId;
      if (!userId) return false;
      const shown =
        (await featured.listFeaturedShownProviderIds(tx, [period.providerId])).length === 1;
      const message = noticeMessage(notice, featuredLastDay(period.endsAt), shown);
      // Not in the customers' list: «جدّده» would sell him nothing.
      if (!message) return false;
      await this.notifications.createNotificationInTransaction(tx, {
        userId,
        type: NotificationType.LISTING_PLAN_CHANGED,
        priority: notice === "ending" ? NotificationPriority.HIGH : NotificationPriority.NORMAL,
        title: message.title,
        body: message.body,
        entityType: "ProviderFeaturedPeriod",
        entityId: period.id,
        routeTarget: noticeRoutes.providerProfile(),
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

/**
 * What the provider reads, true for where he stands: `shown` is the
 * placement rule (he is in the customers' list). Null: nothing true to say.
 */
export function noticeMessage(
  notice: Notice,
  lastDay: string,
  shown: boolean,
): { title: string; body: string } | null {
  const until = arabicDayLabel(lastDay);
  switch (notice) {
    case "started":
      return {
        title: "بدأ ظهورك المميز",
        body: shown
          ? `من اليوم لين ${until} ملفك يطلع مع المميزين أول، وعليه علامة «مميز».`
          : `بدأ اليوم ويستمر لين ${until}، بس ملفك مو ظاهر للعرسان الحين، فما يطلع لهم. لو عندك سؤال كلّم فريق اعّرست.`,
      };
    case "ending":
      return shown
        ? {
            title: "ظهورك المميز ينتهي قريب",
            body: `آخر يوم له ${until}. لو تبي تجدده كلّم فريق اعّرست.`,
          }
        : null;
    case "ended":
      return {
        title: "خلص ظهورك المميز",
        body: shown
          ? "من اليوم ملفك يظهر عادي. لو تبي ترجع مميز كلّم فريق اعّرست."
          : `آخر يوم له كان ${until}.`,
      };
  }
}

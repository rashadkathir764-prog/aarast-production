import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../../platform/database/prisma.service';
import {
  ASSISTANT_OPEN_REPORTS_PER_ACCOUNT,
  ASSISTANT_RESOLVED_REPORT_KEEP_DAYS,
  type AssistantAnswerReportInput,
  type AssistantReportPort,
} from '../public/assistant-report.port';

/** RA-ST-04 (D95): the assistant answers reported to the moderation team. */
@Injectable()
export class AssistantReportService implements AssistantReportPort {
  constructor(private readonly prisma: PrismaService) {}

  async recordAnswerReport(
    userId: string,
    report: AssistantAnswerReportInput,
  ): Promise<boolean> {
    const open = await this.prisma.assistantAnswerReport.count({
      where: { reporterUserId: userId, resolvedAt: null },
    });
    if (open >= ASSISTANT_OPEN_REPORTS_PER_ACCOUNT) return false;
    // RA-BE-166: one row per answer; reporting it again keeps the first.
    await this.prisma.assistantAnswerReport.createMany({
      skipDuplicates: true,
      data: {
        reporterUserId: userId,
        answerId: report.answerId,
        kind: report.kind,
        question: report.question,
        answer: report.answer,
        reason: report.reason,
      },
    });
    return true;
  }
}

const DAY_MS = 24 * 60 * 60 * 1000;

/**
 * RA-BE-166: reviewed reports leave 90 days after their review (the hourly
 * retention run of the account data). Open reports stay until reviewed.
 */
export async function removeReviewedAssistantReports(
  prisma: PrismaService,
  now: Date,
): Promise<number> {
  const removed = await prisma.assistantAnswerReport.deleteMany({
    where: {
      resolvedAt: { lt: new Date(now.getTime() - ASSISTANT_RESOLVED_REPORT_KEEP_DAYS * DAY_MS) },
    },
  });
  return removed.count;
}

import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../../platform/database/prisma.service';
import {
  ASSISTANT_OPEN_REPORTS_PER_ACCOUNT,
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
    await this.prisma.assistantAnswerReport.create({
      data: {
        reporterUserId: userId,
        kind: report.kind,
        question: report.question,
        answer: report.answer,
        reason: report.reason,
      },
    });
    return true;
  }
}

import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InstallmentStatus } from '@prisma/client';
import { startOfRiyadhDay } from '../common/time/business-day';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class FinancialInstallmentsOverdueScheduler {
  private readonly logger = new Logger(
    FinancialInstallmentsOverdueScheduler.name,
  );

  constructor(private readonly prisma: PrismaService) {}

  @Cron('30 0 * * *')
  async markOverdueInstallments(): Promise<void> {
    const startOfToday = startOfRiyadhDay();
    const updatedCount = await this.prisma.$transaction(async (tx) => {
      const [lock] = await tx.$queryRaw<Array<{ locked: boolean }>>`
        SELECT pg_try_advisory_xact_lock(20260711, 1) AS locked
      `;
      if (!lock?.locked) return null;

      const result = await tx.financialInstallment.updateMany({
        where: {
          status: InstallmentStatus.PENDING,
          dueDate: { lt: startOfToday },
        },
        data: { status: InstallmentStatus.OVERDUE },
      });
      return result.count;
    });

    if (updatedCount == null) {
      this.logger.debug('Skipped overdue scan; another replica owns the lock');
    } else if (updatedCount > 0) {
      this.logger.log(
        `Marked ${updatedCount} financial installment(s) as OVERDUE`,
      );
    }
  }
}

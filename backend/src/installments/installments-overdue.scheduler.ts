import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { InstallmentStatus } from '@prisma/client';
import { PrismaService } from '../prisma/prisma.service';

/**
 * Nothing in the system ever set InstallmentStatus.OVERDUE before — the
 * status existed only as a filter value. This job makes "متأخر" real:
 * every pending installment whose due date has passed is flagged daily,
 * which feeds the dashboard alerts and (phase 6) push reminders.
 */
@Injectable()
export class InstallmentsOverdueScheduler {
  private readonly logger = new Logger(InstallmentsOverdueScheduler.name);

  constructor(private readonly prisma: PrismaService) {}

  // 00:30 server time daily; also run once shortly after boot via the
  // controller of the first request? No — keep it deterministic: cron only.
  @Cron('30 0 * * *')
  async markOverdueInstallments(): Promise<void> {
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);

    const result = await this.prisma.installment.updateMany({
      where: {
        status: InstallmentStatus.PENDING,
        dueDate: { lt: startOfToday },
      },
      data: { status: InstallmentStatus.OVERDUE },
    });

    if (result.count > 0) {
      this.logger.log(`Marked ${result.count} installment(s) as OVERDUE`);
    }
  }
}

import { HttpException, HttpStatus, Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../../platform/database/prisma.service';
import {
  OpenWaTransientDeliveryRejectedError,
  OpenWaTransientDeliveryUncertainError,
  sendOpenWaTransientText,
} from '../../../platform/otp-transport/openwa-transient-text';
import {
  consumeOtpDispatchQuotaAttempt,
  type OtpQuotaPolicy,
} from '../infrastructure/otp-dispatch-quota.repository';
import { OtpDispatchQuotaService } from './auth/otp-dispatch-quota.service';
import {
  IdentityTransientDeliveryInput,
  IdentityTransientDeliveryPort,
  IdentityTransientDeliveryRejectedError,
  IdentityTransientDeliveryUncertainError,
} from '../public/identity-transient-delivery.port';

const DAY_MS = 24 * 60 * 60_000;

/**
 * RA-BE-34: the invites' WhatsApp messages leave from the number that sends
 * the sign-in codes, and nothing counted them: one account could send
 * thousands of unasked links, and a ban of the number stops every sign-in
 * (D92 caps the codes for that reason). They have their own budget, apart
 * from the codes' so invites never use up sign-in: a number gets at most a
 * few a day, and the app at most so many. Past it the message is refused,
 * which the invite reads as «not sent: copy the link» (the invite stands).
 */
export const TRANSIENT_PER_PHONE_DAILY_LIMIT = 3;
export const TRANSIENT_DAILY_LIMIT = 300;

@Injectable()
export class IdentityTransientDeliveryAdapter
  implements IdentityTransientDeliveryPort
{
  constructor(private readonly prisma: PrismaService) {}

  async send(input: IdentityTransientDeliveryInput): Promise<void> {
    await this.consumeQuota(input.phone);
    try {
      await sendOpenWaTransientText(input);
    } catch (error) {
      if (error instanceof OpenWaTransientDeliveryUncertainError) {
        throw new IdentityTransientDeliveryUncertainError();
      }
      if (error instanceof OpenWaTransientDeliveryRejectedError) {
        throw new IdentityTransientDeliveryRejectedError();
      }
      throw error;
    }
  }

  private async consumeQuota(phone: string): Promise<void> {
    const policies: OtpQuotaPolicy[] = [
      {
        scope: 'TRANSIENT_PHONE_DAY',
        subject: phone,
        limit: TRANSIENT_PER_PHONE_DAILY_LIMIT,
        windowMs: DAY_MS,
      },
      {
        scope: 'TRANSIENT_GLOBAL_DAY',
        subject: 'aarast-transient',
        limit: TRANSIENT_DAILY_LIMIT,
        windowMs: DAY_MS,
      },
    ];
    for (let attempt = 0; attempt < 3; attempt += 1) {
      try {
        await consumeOtpDispatchQuotaAttempt(
          this.prisma,
          policies,
          () => new Date(),
          OtpDispatchQuotaService.subjectHash,
        );
        return;
      } catch (error) {
        if (
          error instanceof HttpException &&
          error.getStatus() === HttpStatus.TOO_MANY_REQUESTS
        ) {
          throw new IdentityTransientDeliveryRejectedError();
        }
        if (
          error instanceof Prisma.PrismaClientKnownRequestError &&
          (error.code === 'P2002' || error.code === 'P2034') &&
          attempt < 2
        ) {
          continue;
        }
        throw error;
      }
    }
  }
}

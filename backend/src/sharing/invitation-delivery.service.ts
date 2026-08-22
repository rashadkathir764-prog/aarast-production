import { Inject, Injectable, Logger } from '@nestjs/common';
import {
  IDENTITY_TRANSIENT_DELIVERY_PORT,
  IdentityTransientDeliveryPort,
  IdentityTransientDeliveryRejectedError,
  IdentityTransientDeliveryUncertainError,
} from '../modules/identity/public/identity-transient-delivery.port';
import { invitationDeliveryOutcomesTotal } from '../platform/observability/metrics';

export type InvitationDeliveryStatus =
  | 'DELIVERED'
  | 'UNCERTAIN'
  | 'UNAVAILABLE';

export interface InvitationDeliveryResult {
  channel: 'WHATSAPP';
  status: InvitationDeliveryStatus;
}

const defaultInviteOrigin = 'https://aarast.shadowgardn.com';

@Injectable()
export class InvitationDeliveryService {
  private readonly logger = new Logger(InvitationDeliveryService.name);

  constructor(
    @Inject(IDENTITY_TRANSIENT_DELIVERY_PORT)
    private readonly transientDelivery: IdentityTransientDeliveryPort,
  ) {}

  async deliver(phone: string | null, token: string): Promise<InvitationDeliveryResult> {
    if (!phone || process.env.AUTH_OTP_MODE?.trim().toLowerCase() !== 'openwa') {
      invitationDeliveryOutcomesTotal.inc({ outcome: 'not_attempted' });
      return { channel: 'WHATSAPP', status: 'UNAVAILABLE' };
    }

    try {
      await this.transientDelivery.send({
        phone,
        text: buildInvitationMessage(token),
      });
      invitationDeliveryOutcomesTotal.inc({ outcome: 'delivered' });
      return { channel: 'WHATSAPP', status: 'DELIVERED' };
    } catch (error) {
      if (error instanceof IdentityTransientDeliveryUncertainError) {
        invitationDeliveryOutcomesTotal.inc({ outcome: 'uncertain' });
        this.logFailure('uncertain');
        return { channel: 'WHATSAPP', status: 'UNCERTAIN' };
      }
      if (error instanceof IdentityTransientDeliveryRejectedError) {
        invitationDeliveryOutcomesTotal.inc({ outcome: 'rejected' });
        this.logFailure('rejected');
        return { channel: 'WHATSAPP', status: 'UNAVAILABLE' };
      }
      invitationDeliveryOutcomesTotal.inc({ outcome: 'failed' });
      this.logFailure('failed');
      return { channel: 'WHATSAPP', status: 'UNAVAILABLE' };
    }
  }

  /**
   * Never attach the thrown error, phone, token, or generated message. Provider
   * errors can contain request targets and transport payloads.
   */
  private logFailure(outcome: 'uncertain' | 'rejected' | 'failed'): void {
    this.logger.warn({
      event: 'invitation_delivery_failed',
      outcome,
    });
  }
}

export function buildInvitationMessage(
  token: string,
  environment: NodeJS.ProcessEnv = process.env,
): string {
  const cleanToken = token.trim();
  if (!/^[A-Za-z0-9_-]{43}$/.test(cleanToken)) {
    throw new Error('Invalid invitation token');
  }

  const origin = inviteOrigin(environment.INVITE_PUBLIC_ORIGIN);
  const link = new URL(`/invites/${cleanToken}`, origin).toString();
  return [
    'مرحبًا 👋',
    'لديك دعوة خاصة للمشاركة في خطة عبر أعرست.',
    'افتح الرابط، ثم تحقق من رقم هاتفك لعرض الدعوة:',
    link,
    'هذا الرابط خاص بك، لا تشاركه مع الآخرين.',
  ].join('\n');
}

function inviteOrigin(configuredOrigin: string | undefined): string {
  const raw = configuredOrigin?.trim() || defaultInviteOrigin;
  let parsed: URL;
  try {
    parsed = new URL(raw);
  } catch {
    throw new Error('INVITE_PUBLIC_ORIGIN must be a valid absolute URL');
  }
  if (
    parsed.protocol !== 'https:' ||
    parsed.username ||
    parsed.password ||
    parsed.search ||
    parsed.hash ||
    parsed.pathname !== '/'
  ) {
    throw new Error('INVITE_PUBLIC_ORIGIN must be a public HTTPS origin');
  }
  return parsed.toString();
}

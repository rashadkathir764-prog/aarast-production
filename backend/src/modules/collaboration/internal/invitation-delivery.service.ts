import { Inject, Injectable, Logger } from '@nestjs/common';
import {
  IDENTITY_TRANSIENT_DELIVERY_PORT,
  IdentityTransientDeliveryPort,
  IdentityTransientDeliveryRejectedError,
  IdentityTransientDeliveryUncertainError,
} from '../../identity/public/identity-transient-delivery.port';
import { invitationDeliveryOutcomesTotal } from '../../../platform/observability/metrics';

export type InvitationDeliveryStatus =
  | 'DELIVERED'
  | 'UNCERTAIN'
  | 'UNAVAILABLE';

export interface InvitationDeliveryResult {
  channel: 'WHATSAPP';
  status: InvitationDeliveryStatus;
}

const defaultInviteOrigin = 'https://aarast.shadowgardn.com';

/**
 * Who invites and to which wedding, as the message names them (RA-BE-156,
 * Q-37, D124). Both are typed by people, so the message takes a clean first
 * name and a bounded title only.
 */
export interface InvitationSender {
  inviterName: string | null;
  planTitle: string | null;
}

const maxPlanTitleLength = 60;
const maxInviterNameLength = 30;

@Injectable()
export class InvitationDeliveryService {
  private readonly logger = new Logger(InvitationDeliveryService.name);

  constructor(
    @Inject(IDENTITY_TRANSIENT_DELIVERY_PORT)
    private readonly transientDelivery: IdentityTransientDeliveryPort,
  ) {}

  async deliver(
    phone: string | null,
    token: string,
    sender: InvitationSender,
  ): Promise<InvitationDeliveryResult> {
    if (!phone || process.env.AUTH_OTP_MODE?.trim().toLowerCase() !== 'openwa') {
      invitationDeliveryOutcomesTotal.inc({ outcome: 'not_attempted' });
      return { channel: 'WHATSAPP', status: 'UNAVAILABLE' };
    }

    try {
      await this.transientDelivery.send({
        phone,
        text: buildInvitationMessage(token, sender),
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

/**
 * The invitation as the relative first reads it on WhatsApp, from the
 * platform's number. It says who invited them and to which wedding, in the
 * Yemeni voice and in no one's gender (the one invited may be a man or a
 * woman and has no account to say which), so it does not read as a stranger's
 * message (RA-OP-33).
 */
export function buildInvitationMessage(
  token: string,
  sender: InvitationSender,
  environment: NodeJS.ProcessEnv = process.env,
): string {
  const cleanToken = token.trim();
  if (!/^[A-Za-z0-9_-]{43}$/.test(cleanToken)) {
    throw new Error('Invalid invitation token');
  }

  const origin = inviteOrigin(environment.INVITE_PUBLIC_ORIGIN);
  const link = new URL(`/invites/${cleanToken}`, origin).toString();
  const inviter = cleanLabel(
    sender.inviterName?.trim().split(/\s+/u)[0] ?? null,
    maxInviterNameLength,
  );
  const plan = cleanLabel(sender.planTitle, maxPlanTitleLength) ?? 'عرس';
  return [
    'السلام عليكم 👋',
    `وصلتك دعوة ${inviter ? `من ${inviter} ` : ''}للمشاركة في ${plan} على اعّرست.`,
    'الدعوة تنفتح من الرابط، بعد ما نتأكد من رقم جوالك:',
    link,
    'الرابط خاص بجوالك بس.',
  ].join('\n');
}

/**
 * A name or title someone typed, made safe to put inside the platform's own
 * message: one line, no formatting marks, no direction controls, bounded, and
 * nothing that reads as a link (the platform's number must never carry a
 * stranger's link). Null when nothing clean is left.
 */
function cleanLabel(value: string | null, maxLength: number): string | null {
  if (!value) return null;
  const text = value
    .replace(/[\u0000-\u001f\u007f\u200e\u200f\u202a-\u202e\u2066-\u2069*_~`]/gu, ' ')
    .replace(/\s+/gu, ' ')
    .trim();
  if (!text) return null;
  if (/(https?:|www\.|:\/\/|@|[a-z0-9-]+\.[a-z]{2,})/iu.test(text)) return null;
  return Array.from(text).slice(0, maxLength).join('').trim() || null;
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

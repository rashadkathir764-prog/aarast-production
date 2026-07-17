import { Injectable } from '@nestjs/common';
import {
  OpenWaTransientDeliveryUncertainError,
  sendOpenWaTransientText,
} from '../auth/openwa-transient-text';

export type InvitationDeliveryStatus =
  | 'SENT'
  | 'UNCERTAIN'
  | 'UNAVAILABLE';

export interface InvitationDeliveryResult {
  channel: 'WHATSAPP';
  status: InvitationDeliveryStatus;
}

const defaultInviteOrigin = 'https://aarast.shadowgardn.com';

@Injectable()
export class InvitationDeliveryService {
  async deliver(phone: string | null, token: string): Promise<InvitationDeliveryResult> {
    if (!phone || process.env.AUTH_OTP_MODE?.trim().toLowerCase() !== 'openwa') {
      return { channel: 'WHATSAPP', status: 'UNAVAILABLE' };
    }

    try {
      await sendOpenWaTransientText({
        phone,
        text: buildInvitationMessage(token),
      });
      return { channel: 'WHATSAPP', status: 'SENT' };
    } catch (error) {
      if (error instanceof OpenWaTransientDeliveryUncertainError) {
        return { channel: 'WHATSAPP', status: 'UNCERTAIN' };
      }
      return { channel: 'WHATSAPP', status: 'UNAVAILABLE' };
    }
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

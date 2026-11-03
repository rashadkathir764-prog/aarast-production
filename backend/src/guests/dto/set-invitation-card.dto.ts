import { IsOptional, IsString, MaxLength } from 'class-validator';
import { INVITATION_CARD_LIMITS } from '../../modules/guests/domain/invitation-card';

/**
 * D83: a write to the plan's invitation card. A missing field keeps what is
 * stored; null or blank clears it. The photo is a public upload of the
 * writer's (`guest-invitation-card`), checked by the media port.
 */
export class SetInvitationCardDto {
  @IsString()
  @MaxLength(INVITATION_CARD_LIMITS.hostLine)
  @IsOptional()
  hostLine?: string | null;

  @IsString()
  @MaxLength(INVITATION_CARD_LIMITS.freeText)
  @IsOptional()
  freeText?: string | null;

  @IsString()
  @MaxLength(1000)
  @IsOptional()
  photoUrl?: string | null;

  @IsString()
  @MaxLength(INVITATION_CARD_LIMITS.mapUrl)
  @IsOptional()
  mapUrl?: string | null;

  @IsString()
  @MaxLength(INVITATION_CARD_LIMITS.address)
  @IsOptional()
  address?: string | null;
}

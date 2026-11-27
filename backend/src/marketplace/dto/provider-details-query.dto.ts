import { IsOptional, IsString } from 'class-validator';

/** `GET /api/v1/providers/:id`. */
export class ProviderDetailsQueryDto {
  /**
   * D131 (2026-11-26 review): the wedding's day (`YYYY-MM-DD`), read as the
   * list reads it; the page then says `dayStatus` (CLOSED, FULL or null).
   */
  @IsString()
  @IsOptional()
  eventDate?: string;
}

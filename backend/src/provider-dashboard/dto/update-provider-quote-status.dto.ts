import { QuoteRequestStatus } from '@prisma/client';
import { IsEnum } from 'class-validator';

export class UpdateProviderQuoteStatusDto {
  @IsEnum(QuoteRequestStatus)
  status!: QuoteRequestStatus;
}

import { IsBoolean, IsOptional } from 'class-validator';

export class UpdateSettingsDto {
  @IsBoolean()
  @IsOptional()
  pushEnabled?: boolean;

  @IsBoolean()
  @IsOptional()
  smsEnabled?: boolean;

  @IsBoolean()
  @IsOptional()
  whatsappEnabled?: boolean;

  @IsBoolean()
  @IsOptional()
  emailEnabled?: boolean;

  @IsBoolean()
  @IsOptional()
  taskRemindersEnabled?: boolean;

  @IsBoolean()
  @IsOptional()
  paymentRemindersEnabled?: boolean;

  @IsBoolean()
  @IsOptional()
  providerMessagesEnabled?: boolean;
}

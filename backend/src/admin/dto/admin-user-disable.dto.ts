import { IsNotEmpty, IsString, MaxLength } from 'class-validator';

/**
 * RA-AD-23: disabling an account says why; the audit log keeps the reason
 * (admin-web's dialog stops at the same 500).
 */
export class AdminUserDisableDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(500)
  reason!: string;
}

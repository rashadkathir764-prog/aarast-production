import { IsNotEmpty, IsString, Length, Matches, MaxLength } from 'class-validator';

/** Q-52 (أ): the public deletion page asks a code for the registered number. */
export class AccountDeletionCodeDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phone!: string;
}

/** Q-52 (أ): the number and the code its WhatsApp received. */
export class AccountDeletionConfirmDto {
  @IsString()
  @IsNotEmpty()
  @MaxLength(40)
  phone!: string;

  @IsString()
  @Length(6, 6)
  @Matches(/^\d{6}$/)
  code!: string;
}

import { Module } from '@nestjs/common';
import {
  IdentityAuthInternalModule,
  OTP_CAPACITY_IMPLEMENTATION,
} from '../internal/identity-auth.internal.module';
import { OTP_CAPACITY_PORT } from './otp-capacity.port';

@Module({
  imports: [IdentityAuthInternalModule],
  providers: [
    {
      provide: OTP_CAPACITY_PORT,
      useExisting: OTP_CAPACITY_IMPLEMENTATION,
    },
  ],
  exports: [OTP_CAPACITY_PORT],
})
export class OtpCapacityPublicModule {}

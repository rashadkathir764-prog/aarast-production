import { Module } from "@nestjs/common";
import {
  IdentityUserInternalModule,
  USER_READ_IMPLEMENTATION,
} from "../internal/identity-user.internal.module";
import { USER_READ_PORT } from "./user-read.port";

@Module({
  imports: [IdentityUserInternalModule],
  providers: [
    {
      provide: USER_READ_PORT,
      useExisting: USER_READ_IMPLEMENTATION,
    },
  ],
  exports: [USER_READ_PORT],
})
export class UserReadPublicModule {}

import { Module } from "@nestjs/common";
import { IdentityUserPortService } from "./identity-user-port.service";

export const USER_READ_IMPLEMENTATION = Symbol("USER_READ_IMPLEMENTATION");
export const ACTIVE_PLAN_IMPLEMENTATION = Symbol("ACTIVE_PLAN_IMPLEMENTATION");

@Module({
  providers: [
    IdentityUserPortService,
    {
      provide: USER_READ_IMPLEMENTATION,
      useExisting: IdentityUserPortService,
    },
    {
      provide: ACTIVE_PLAN_IMPLEMENTATION,
      useExisting: IdentityUserPortService,
    },
  ],
  exports: [
    IdentityUserPortService,
    USER_READ_IMPLEMENTATION,
    ACTIVE_PLAN_IMPLEMENTATION,
  ],
})
export class IdentityUserInternalModule {}

import { Module } from "@nestjs/common";
import { PrismaModule } from "../../../platform/database/prisma.module";
import { IdentityRealtimeSessionService } from "./identity-realtime-session.service";
import { IdentityUserPortService } from "./identity-user-port.service";

export const USER_READ_IMPLEMENTATION = Symbol("USER_READ_IMPLEMENTATION");
export const ACTIVE_PLAN_IMPLEMENTATION = Symbol("ACTIVE_PLAN_IMPLEMENTATION");
export const PROVIDER_ACCOUNT_IMPLEMENTATION = Symbol(
  "PROVIDER_ACCOUNT_IMPLEMENTATION",
);
export const IDENTITY_REALTIME_SESSION_IMPLEMENTATION = Symbol(
  "IDENTITY_REALTIME_SESSION_IMPLEMENTATION",
);

@Module({
  imports: [PrismaModule],
  providers: [
    IdentityUserPortService,
    IdentityRealtimeSessionService,
    {
      provide: USER_READ_IMPLEMENTATION,
      useExisting: IdentityUserPortService,
    },
    {
      provide: ACTIVE_PLAN_IMPLEMENTATION,
      useExisting: IdentityUserPortService,
    },
    {
      provide: PROVIDER_ACCOUNT_IMPLEMENTATION,
      useExisting: IdentityUserPortService,
    },
    {
      provide: IDENTITY_REALTIME_SESSION_IMPLEMENTATION,
      useExisting: IdentityRealtimeSessionService,
    },
  ],
  exports: [
    IdentityUserPortService,
    IdentityRealtimeSessionService,
    USER_READ_IMPLEMENTATION,
    ACTIVE_PLAN_IMPLEMENTATION,
    PROVIDER_ACCOUNT_IMPLEMENTATION,
    IDENTITY_REALTIME_SESSION_IMPLEMENTATION,
  ],
})
export class IdentityUserInternalModule {}

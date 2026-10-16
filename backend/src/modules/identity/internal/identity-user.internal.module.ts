import { Module } from "@nestjs/common";
import { PrismaModule } from "../../../platform/database/prisma.module";
import { AssistantQuotaService } from "../infrastructure/assistant-quota.service";
import { IdentityAdminService } from "../infrastructure/identity-admin.service";
import { IdentityRealtimeSessionService } from "../infrastructure/identity-realtime-session.service";
import { IdentityUserPortService } from "../infrastructure/identity-user-port.service";

export const USER_READ_IMPLEMENTATION = Symbol("USER_READ_IMPLEMENTATION");
export const ACTIVE_PLAN_IMPLEMENTATION = Symbol("ACTIVE_PLAN_IMPLEMENTATION");
export const PROVIDER_ACCOUNT_IMPLEMENTATION = Symbol(
  "PROVIDER_ACCOUNT_IMPLEMENTATION",
);
export const IDENTITY_REALTIME_SESSION_IMPLEMENTATION = Symbol(
  "IDENTITY_REALTIME_SESSION_IMPLEMENTATION",
);
export const IDENTITY_ADMIN_IMPLEMENTATION = Symbol(
  "IDENTITY_ADMIN_IMPLEMENTATION",
);
export const ASSISTANT_QUOTA_IMPLEMENTATION = Symbol(
  "ASSISTANT_QUOTA_IMPLEMENTATION",
);

@Module({
  imports: [PrismaModule],
  providers: [
    IdentityUserPortService,
    IdentityRealtimeSessionService,
    IdentityAdminService,
    AssistantQuotaService,
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
    {
      provide: IDENTITY_ADMIN_IMPLEMENTATION,
      useExisting: IdentityAdminService,
    },
    {
      provide: ASSISTANT_QUOTA_IMPLEMENTATION,
      useExisting: AssistantQuotaService,
    },
  ],
  exports: [
    IdentityUserPortService,
    IdentityRealtimeSessionService,
    IdentityAdminService,
    USER_READ_IMPLEMENTATION,
    ACTIVE_PLAN_IMPLEMENTATION,
    PROVIDER_ACCOUNT_IMPLEMENTATION,
    IDENTITY_REALTIME_SESSION_IMPLEMENTATION,
    IDENTITY_ADMIN_IMPLEMENTATION,
    ASSISTANT_QUOTA_IMPLEMENTATION,
  ],
})
export class IdentityUserInternalModule {}

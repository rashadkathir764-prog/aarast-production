import { Module } from "@nestjs/common";
import {
  ASSISTANT_QUOTA_IMPLEMENTATION,
  IdentityUserInternalModule,
} from "../internal/identity-user.internal.module";
import { ASSISTANT_QUOTA_PORT } from "./assistant-quota.port";

@Module({
  imports: [IdentityUserInternalModule],
  providers: [
    {
      provide: ASSISTANT_QUOTA_PORT,
      useExisting: ASSISTANT_QUOTA_IMPLEMENTATION,
    },
  ],
  exports: [ASSISTANT_QUOTA_PORT],
})
export class AssistantQuotaPublicModule {}

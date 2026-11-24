import { Module } from "@nestjs/common";
import {
  ASSISTANT_CONSENT_IMPLEMENTATION,
  IdentityUserInternalModule,
} from "../internal/identity-user.internal.module";
import { ASSISTANT_CONSENT_PORT } from "./assistant-consent.port";

@Module({
  imports: [IdentityUserInternalModule],
  providers: [
    {
      provide: ASSISTANT_CONSENT_PORT,
      useExisting: ASSISTANT_CONSENT_IMPLEMENTATION,
    },
  ],
  exports: [ASSISTANT_CONSENT_PORT],
})
export class AssistantConsentPublicModule {}

import { Module } from "@nestjs/common";
import {
  ASSISTANT_REPORT_IMPLEMENTATION,
  IdentityUserInternalModule,
} from "../internal/identity-user.internal.module";
import { ASSISTANT_REPORT_PORT } from "./assistant-report.port";

@Module({
  imports: [IdentityUserInternalModule],
  providers: [
    {
      provide: ASSISTANT_REPORT_PORT,
      useExisting: ASSISTANT_REPORT_IMPLEMENTATION,
    },
  ],
  exports: [ASSISTANT_REPORT_PORT],
})
export class AssistantReportPublicModule {}

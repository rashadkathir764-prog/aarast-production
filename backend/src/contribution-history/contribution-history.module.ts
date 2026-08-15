import { Module } from "@nestjs/common";
import { IdentityAuthPublicModule } from "../modules/identity/public/identity-auth-public.module";
import { CollaborationHistoryInternalModule } from "../modules/collaboration/internal/collaboration-history.internal.module";
import { CollaborationScopeInternalModule } from "../modules/collaboration/internal/collaboration-scope.internal.module";
import { ContributionHistoryController } from "./contribution-history.controller";

@Module({
  imports: [
    IdentityAuthPublicModule,
    CollaborationHistoryInternalModule,
    CollaborationScopeInternalModule,
  ],
  controllers: [ContributionHistoryController],
})
export class ContributionHistoryModule {}

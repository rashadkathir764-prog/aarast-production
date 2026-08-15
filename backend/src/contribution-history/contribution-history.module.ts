import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { CollaborationHistoryInternalModule } from "../modules/collaboration/internal/collaboration-history.internal.module";
import { CollaborationScopeInternalModule } from "../modules/collaboration/internal/collaboration-scope.internal.module";
import { ContributionHistoryController } from "./contribution-history.controller";

@Module({
  imports: [
    AuthModule,
    CollaborationHistoryInternalModule,
    CollaborationScopeInternalModule,
  ],
  controllers: [ContributionHistoryController],
})
export class ContributionHistoryModule {}

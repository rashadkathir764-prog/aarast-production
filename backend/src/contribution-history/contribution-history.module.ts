import { Module } from "@nestjs/common";
import { AuthModule } from "../auth/auth.module";
import { ContributionHistoryController } from "./contribution-history.controller";
import { ContributionHistoryService } from "./contribution-history.service";
import { ContributorScopeService } from "./contributor-scope.service";

@Module({
  imports: [AuthModule],
  controllers: [ContributionHistoryController],
  providers: [ContributionHistoryService, ContributorScopeService],
  exports: [ContributionHistoryService, ContributorScopeService],
})
export class ContributionHistoryModule {}

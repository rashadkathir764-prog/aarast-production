import { Module } from "@nestjs/common";
import { ContributionHistoryController } from "./api/contribution-history.controller";
import {
  ApiV1InviteAcceptController,
  ApiV1InviteAccessController,
  ApiV1InvitesController,
  ApiV1WeddingPlanInvitesController,
  ApiV1WeddingPlanMembersController,
  ApiV1WeddingPlanPermissionsController,
  SharedWeddingPlansController,
} from "../../sharing/sharing.controller";
import { CollaborationHistoryInternalModule } from "./internal/collaboration-history.internal.module";
import { CollaborationScopeInternalModule } from "./internal/collaboration-scope.internal.module";
import { CollaborationServicesInternalModule } from "./internal/collaboration-services.internal.module";

@Module({
  imports: [
    CollaborationHistoryInternalModule,
    CollaborationScopeInternalModule,
    CollaborationServicesInternalModule,
  ],
  controllers: [
    ApiV1InviteAccessController,
    SharedWeddingPlansController,
    ApiV1WeddingPlanMembersController,
    ApiV1WeddingPlanInvitesController,
    ApiV1InvitesController,
    ApiV1InviteAcceptController,
    ApiV1WeddingPlanPermissionsController,
    ContributionHistoryController,
  ],
})
export class CollaborationModule {}

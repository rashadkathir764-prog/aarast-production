import { Module } from "@nestjs/common";
import { PrismaModule } from "../platform/database/prisma.module";
import { CollaborationHistoryPublicModule } from "../modules/collaboration/public/collaboration-history-public.module";
import { CollaborationPermissionPublicModule } from "../modules/collaboration/public/collaboration-permission-public.module";
import { NotificationsModule } from "../notifications/notifications.module";
import {
  ApiV1QuoteOffersController,
  ApiV1QuoteRequestsController,
  ApiV1WeddingPlanQuoteRequestsController,
  CitiesController,
  GovernoratesController,
  MeMarketplaceController,
  ProviderCategoriesController,
  ProvidersController,
  ReviewsController,
  ServicesController,
} from "./marketplace.controller";
import { MarketplaceService } from "./marketplace.service";

@Module({
  imports: [
    PrismaModule,
    CollaborationPermissionPublicModule,
    NotificationsModule,
    CollaborationHistoryPublicModule,
  ],
  controllers: [
    CitiesController,
    GovernoratesController,
    ProviderCategoriesController,
    ProvidersController,
    ServicesController,
    MeMarketplaceController,
    ReviewsController,
    ApiV1WeddingPlanQuoteRequestsController,
    ApiV1QuoteRequestsController,
    ApiV1QuoteOffersController,
  ],
  providers: [MarketplaceService],
  exports: [MarketplaceService],
})
export class MarketplaceModule {}

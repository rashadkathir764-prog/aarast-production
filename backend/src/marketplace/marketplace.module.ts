import { Module } from "@nestjs/common";
import { PrismaModule } from "../prisma/prisma.module";
import { NotificationsModule } from "../notifications/notifications.module";
import { SharingModule } from "../sharing/sharing.module";
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
  imports: [PrismaModule, SharingModule, NotificationsModule],
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

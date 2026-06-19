import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { SharingModule } from '../sharing/sharing.module';
import {
  ApiV1ProviderCategoriesController,
  ApiV1ProvidersController,
  ApiV1QuoteOffersController,
  ApiV1QuoteRequestsController,
  ApiV1WeddingPlanQuoteRequestsController,
  CitiesController,
  MeMarketplaceController,
  ProviderCategoriesController,
  ProvidersController,
  ReviewsController,
  ServicesController,
} from './marketplace.controller';
import { MarketplaceService } from './marketplace.service';

@Module({
  imports: [PrismaModule, SharingModule],
  controllers: [
    CitiesController,
    ProviderCategoriesController,
    ProvidersController,
    ServicesController,
    MeMarketplaceController,
    ReviewsController,
    ApiV1ProviderCategoriesController,
    ApiV1ProvidersController,
    ApiV1WeddingPlanQuoteRequestsController,
    ApiV1QuoteRequestsController,
    ApiV1QuoteOffersController,
  ],
  providers: [MarketplaceService],
  exports: [MarketplaceService],
})
export class MarketplaceModule {}

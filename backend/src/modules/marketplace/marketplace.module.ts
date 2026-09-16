import { Module } from '@nestjs/common';
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
} from '../../marketplace/marketplace.controller';
import {
  ProviderApplicationController,
  ProviderDashboardController,
} from '../../provider-dashboard/provider-dashboard.controller';
import { MarketplaceServicesInternalModule } from './internal/marketplace-services.internal.module';
import { ProviderReadPublicModule } from './public/provider-read-public.module';
import { QuoteReadPublicModule } from './public/quote-read-public.module';

@Module({
  imports: [
    ProviderReadPublicModule,
    QuoteReadPublicModule,
    MarketplaceServicesInternalModule,
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
    ProviderApplicationController,
    ProviderDashboardController,
  ],
})
export class MarketplaceModule {}

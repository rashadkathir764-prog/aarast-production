import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { SharingModule } from '../sharing/sharing.module';
import {
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
  ],
  providers: [MarketplaceService],
  exports: [MarketplaceService],
})
export class MarketplaceModule {}

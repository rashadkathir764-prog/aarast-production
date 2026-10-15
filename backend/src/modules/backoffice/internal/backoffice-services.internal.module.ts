import { Module } from '@nestjs/common';
import { AdminAuditService } from '../../../admin/admin-audit.service';
import { AdminOwners } from '../../../admin/admin-owners';
import { AdminService } from '../../../admin/admin.service';
import { PrismaModule } from '../../../platform/database/prisma.module';
import { AdminAuditLogPublicModule } from '../public/admin-audit-log-public.module';
import { CatalogAdminPublicModule } from '../../catalog/public/catalog-admin-public.module';
import { CatalogReadPublicModule } from '../../catalog/public/catalog-read-public.module';
import { CollaborationPermissionPublicModule } from '../../collaboration/public/collaboration-permission-public.module';
import { FinancePublicModule } from '../../finance/public/finance-public.module';
import { IdentityAdminPublicModule } from '../../identity/public/identity-admin-public.module';
import { ProviderAccountPublicModule } from '../../identity/public/provider-account-public.module';
import { UserReadPublicModule } from '../../identity/public/user-read-public.module';
import { MarketplaceAdminPublicModule } from '../../marketplace/public/marketplace-admin-public.module';
import { ProviderReadPublicModule } from '../../marketplace/public/provider-read-public.module';
import { QuoteReadPublicModule } from '../../marketplace/public/quote-read-public.module';
import { MessagingAdminPublicModule } from '../../messaging/public/messaging-admin-public.module';
import { MessagingRealtimePublicModule } from '../../messaging/public/messaging-realtime-public.module';
import { NotificationsAdminPublicModule } from '../../notifications/public/notifications-admin-public.module';
import { NotificationsPublicModule } from '../../notifications/public/notifications-public.module';
import { PlanReadPublicModule } from '../../planning/public/plan-read-public.module';

@Module({
  imports: [
    PrismaModule,
    AdminAuditLogPublicModule,
    MessagingRealtimePublicModule,
    NotificationsPublicModule,
    IdentityAdminPublicModule,
    ProviderAccountPublicModule,
    UserReadPublicModule,
    CatalogAdminPublicModule,
    CatalogReadPublicModule,
    MarketplaceAdminPublicModule,
    ProviderReadPublicModule,
    QuoteReadPublicModule,
    MessagingAdminPublicModule,
    NotificationsAdminPublicModule,
    PlanReadPublicModule,
    CollaborationPermissionPublicModule,
    FinancePublicModule,
  ],
  providers: [AdminOwners, AdminService, AdminAuditService],
  exports: [AdminService, AdminAuditService],
})
export class BackofficeServicesInternalModule {}

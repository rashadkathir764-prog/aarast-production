import { Module } from "@nestjs/common";
import { AccountDeletionStatusController } from "./api/account-deletion-status.controller";
import { AuthController } from "./api/auth.controller";
import { ContextsController } from "./api/contexts.controller";
import { MeController } from "./api/me.controller";
import { UsersController } from "./api/users.controller";
import { IdentityAuthInternalModule } from "./internal/identity-auth.internal.module";
import { IdentityProfileInternalModule } from "./internal/identity-profile.internal.module";
import { ActivePlanPublicModule } from "./public/active-plan-public.module";
import { IdentityAuthPublicModule } from "./public/identity-auth-public.module";
import { IdentityTransientDeliveryPublicModule } from "./public/identity-transient-delivery-public.module";
import { ProviderAccountPublicModule } from "./public/provider-account-public.module";
import { UserReadPublicModule } from "./public/user-read-public.module";

@Module({
  imports: [
    IdentityAuthInternalModule,
    IdentityProfileInternalModule,
    IdentityAuthPublicModule,
    IdentityTransientDeliveryPublicModule,
    UserReadPublicModule,
    ActivePlanPublicModule,
    ProviderAccountPublicModule,
  ],
  controllers: [
    AuthController,
    UsersController,
    AccountDeletionStatusController,
    MeController,
    ContextsController,
  ],
})
export class IdentityModule {}

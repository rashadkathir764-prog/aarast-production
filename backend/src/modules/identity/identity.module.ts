import { Module } from "@nestjs/common";
import { AccountDeletionStatusController } from "./api/account-deletion-status.controller";
import { AuthController } from "./api/auth.controller";
import { ContextsController } from "./api/contexts.controller";
import { MeController } from "./api/me.controller";
import { UsersController } from "./api/users.controller";
import { IdentityAuthInternalModule } from "./internal/identity-auth.internal.module";
import { IdentityProfileInternalModule } from "./internal/identity-profile.internal.module";
import { IdentityAuthPublicModule } from "./public/identity-auth-public.module";

@Module({
  imports: [
    IdentityAuthInternalModule,
    IdentityProfileInternalModule,
    IdentityAuthPublicModule,
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

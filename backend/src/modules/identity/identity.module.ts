import { Module } from "@nestjs/common";
import { AccountDeletionStatusController } from "../../users/account-deletion-status.controller";
import { AuthController } from "./api/auth.controller";
import { ContextsController } from "../../contexts/contexts.controller";
import { MeController } from "../../me/me.controller";
import { UsersController } from "../../users/users.controller";
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

import { Module } from '@nestjs/common';
import { IdentityAuthPublicModule } from '../modules/identity/public/identity-auth-public.module';
import { CollaborationPermissionPublicModule } from '../modules/collaboration/public/collaboration-permission-public.module';
import { CollaborationScopePublicModule } from '../modules/collaboration/public/collaboration-scope-public.module';
import { PrismaModule } from '../platform/database/prisma.module';
import { TimelineController } from './timeline.controller';
import { TimelineService } from './timeline.service';

@Module({
  imports: [
    IdentityAuthPublicModule,
    PrismaModule,
    CollaborationPermissionPublicModule,
    CollaborationScopePublicModule,
  ],
  controllers: [TimelineController],
  providers: [TimelineService],
})
export class TimelineModule {}

import { ForbiddenException, Injectable } from '@nestjs/common';
import { AuthenticatedUser } from './authenticated-user.interface';

@Injectable()
export class OwnershipContextService {
  isOwner(currentUser: AuthenticatedUser, ownerUserId: string): boolean {
    return currentUser.id === ownerUserId;
  }

  assertOwner(currentUser: AuthenticatedUser, ownerUserId: string): void {
    if (!this.isOwner(currentUser, ownerUserId)) {
      throw new ForbiddenException('You do not have access to this resource');
    }
  }
}

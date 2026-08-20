import { Injectable } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

/** Authenticates a structurally valid access JWT without selecting its realm. */
@Injectable()
export class JwtSessionGuard extends AuthGuard('jwt') {}

import {
  ConflictException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import * as bcryptjs from 'bcryptjs';
import { PrismaService } from '../prisma/prisma.service';
import { RegisterDto } from './dto/register.dto';
import { LoginDto } from './dto/login.dto';
import { JwtPayload } from './jwt-payload.interface';
import { SafeUser, toSafeUser } from './safe-user';

export interface AuthResponse {
  user: SafeUser;
  accessToken: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly jwtService: JwtService,
  ) {}

  async register(dto: RegisterDto): Promise<AuthResponse> {
    const existing = await this.prisma.user.findFirst({
      where: {
        OR: [
          { phone: dto.phone },
          ...(dto.email ? [{ email: dto.email }] : []),
        ],
      },
    });

    if (existing) {
      throw new ConflictException('Phone or email already registered');
    }

    const passwordHash = await bcryptjs.hash(dto.password, 10);

    const user = await this.prisma.user.create({
      data: {
        name: dto.name,
        phone: dto.phone,
        email: dto.email ?? null,
        passwordHash,
      },
    });

    const accessToken = this.signToken(user.id, user.phone);
    return { user: toSafeUser(user), accessToken };
  }

  async login(dto: LoginDto): Promise<AuthResponse> {
    const user = await this.prisma.user.findUnique({
      where: { phone: dto.phone },
    });

    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }

    if (user.status === 'DISABLED') {
      throw new UnauthorizedException('Account is disabled');
    }

    const passwordMatch = await bcryptjs.compare(dto.password, user.passwordHash);
    if (!passwordMatch) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const accessToken = this.signToken(user.id, user.phone);
    return { user: toSafeUser(user), accessToken };
  }

  private signToken(userId: string, phone: string | null): string {
    const payload: JwtPayload = { sub: userId, phone };
    return this.jwtService.sign(payload);
  }
}

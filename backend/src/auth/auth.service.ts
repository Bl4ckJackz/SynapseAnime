import { Injectable, Logger, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../entities/user.entity';
import * as bcrypt from 'bcrypt';
import { OAuth2Client } from 'google-auth-library';

@Injectable()
export class AuthService {
  private readonly logger = new Logger(AuthService.name);
  private googleClient = new OAuth2Client(process.env.GOOGLE_CLIENT_ID);

  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    private jwtService: JwtService,
  ) {}

  async validateUser(email: string, pass: string): Promise<any> {
    const user = await this.userRepository.findOne({ where: { email } });

    if (user && user.password) {
      const passwordMatch = await bcrypt.compare(pass, user.password);
      if (passwordMatch) {
        const { password, ...result } = user;
        return result;
      }
    }
    return null;
  }

  async findUserById(id: string): Promise<any> {
    return this.userRepository.findOne({ where: { id } });
  }

  async validateUserById(id: string): Promise<any> {
    const user = await this.userRepository.findOne({ where: { id } });
    if (user) {
      const { password, ...result } = user;
      return result;
    }
    return null;
  }

  async login(user: any) {
    const payload = { username: user.email, sub: user.id };
    return {
      access_token: this.jwtService.sign(payload),
      user: {
        id: user.id,
        email: user.email,
        nickname: user.nickname,
        avatarUrl: user.avatarUrl,
      },
    };
  }

  async register(email: string, pass: string, nickname: string) {
    const existing = await this.userRepository.findOne({ where: { email } });
    if (existing) {
      throw new UnauthorizedException('User already exists');
    }

    const hashedPassword = await bcrypt.hash(pass, 10);
    const user = this.userRepository.create({
      email,
      password: hashedPassword,
      nickname,
    });

    await this.userRepository.save(user);
    return this.login(user);
  }

  async loginWithGoogle(token: string) {
    try {
      const ticket = await this.googleClient.verifyIdToken({
        idToken: token,
        audience: process.env.GOOGLE_CLIENT_ID,
      });

      const payload = ticket.getPayload();
      if (!payload || !payload.email) {
        throw new UnauthorizedException('Invalid Google Token payload');
      }

      const { email, sub: googleId, name, picture } = payload;

      // Check if user exists
      let user = await this.userRepository.findOne({ where: { email } });

      if (user) {
        // Update googleId if missing
        if (!user.googleId) {
          user.googleId = googleId;
          user.avatarUrl = picture; // Update avatar
          await this.userRepository.save(user);
        }
      } else {
        // Create new user via Google
        user = this.userRepository.create({
          email,
          nickname: name || email.split('@')[0],
          googleId,
          avatarUrl: picture,
          // No password for google users, type allows optional
        });
        await this.userRepository.save(user);
      }

      return this.login(user);
    } catch (e) {
      this.logger.error('Google Auth Error', e instanceof Error ? e.stack : e);
      throw new UnauthorizedException('Invalid Google Token');
    }
  }
}

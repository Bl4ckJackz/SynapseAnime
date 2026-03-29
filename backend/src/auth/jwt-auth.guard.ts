import { Injectable, ExecutionContext, Logger, UnauthorizedException } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  private readonly logger = new Logger(JwtAuthGuard.name);

  canActivate(context: ExecutionContext) {
    return super.canActivate(context);
  }

  handleRequest(err, user, info) {
    if (err || !user) {
      this.logger.log(`[JwtAuthGuard] Auth failed. User: ${user ? 'Found' : 'Missing'}, Error: ${err}, Info: ${info}`);
      throw err || new UnauthorizedException();
    }
    return user;
  }
}

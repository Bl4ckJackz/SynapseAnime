import { Injectable, ExecutionContext, UnauthorizedException } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  canActivate(context: ExecutionContext) {
    return super.canActivate(context);
  }

  handleRequest(err, user, info) {
    if (err || !user) {
      console.log(`[JwtAuthGuard] Auth failed. User: ${user ? 'Found' : 'Missing'}, Error: ${err}, Info: ${info}`);
      throw err || new UnauthorizedException();
    }
    return user;
  }
}

import {
  WebSocketGateway,
  WebSocketServer,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Injectable, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';

@Injectable()
@WebSocketGateway({
  cors: {
    origin: '*',
  },
  namespace: 'history',
})
export class HistoryGateway
  implements OnGatewayConnection, OnGatewayDisconnect
{
  @WebSocketServer()
  server: Server;

  private logger = new Logger('HistoryGateway');

  // Map to track active connections per user: userId -> Set<SocketId>
  private userConnections = new Map<string, Set<string>>();

  constructor(private jwtService: JwtService) {}

  async handleConnection(client: Socket) {
    try {
      // 1. Extract token
      const token =
        client.handshake.auth?.token ||
        client.handshake.query?.token ||
        (client.handshake.headers?.authorization?.split(' ')[1] as string);

      if (!token) {
        console.log(
          `[HistoryGateway] Client ${client.id} failed auth: No token`,
        );
        client.disconnect();
        return;
      }

      // 2. Verify token
      const payload = await this.jwtService.verifyAsync(token);
      const userId = payload.sub; // Assuming 'sub' is userId

      // 3. Join room
      client.join(`user_${userId}`);
      console.log(
        `[HistoryGateway] User ${userId} connected and joined room user_${userId}`,
      );

      if (!this.userConnections.has(userId)) {
        this.userConnections.set(userId, new Set());
      }
      this.userConnections.get(userId)?.add(client.id);
    } catch (e) {
      console.error(`[HistoryGateway] Connection error:`, e.message);
      client.disconnect();
    }
  }

  handleDisconnect(client: Socket) {
    const queryToken = client.handshake.query.token;
    return typeof queryToken === 'string' ? queryToken : undefined;
  }

  // Method to be called by UsersService
  notifyHistoryUpdate(userId: string) {
    this.server.to(`user_${userId}`).emit('history_updated');
    this.logger.debug(`Emitted history_updated to user_${userId}`);
  }
}

import {
    WebSocketGateway,
    WebSocketServer,
    OnGatewayConnection,
    OnGatewayDisconnect,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Injectable, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { Download } from '../entities/download.entity';

@Injectable()
@WebSocketGateway({
    cors: {
        origin: process.env.CORS_ORIGINS
            ? process.env.CORS_ORIGINS.split(',')
            : ['http://localhost:3000', 'http://localhost:5173'],
    },
    namespace: 'downloads',
})
export class DownloadGateway
    implements OnGatewayConnection, OnGatewayDisconnect {
    @WebSocketServer()
    server: Server;

    private logger = new Logger('DownloadGateway');

    // Map to track active connections per user: userId -> Set<SocketId>
    private userConnections = new Map<string, Set<string>>();

    constructor(private jwtService: JwtService) { }

    async handleConnection(client: Socket) {
        try {
            // 1. Extract token
            const token =
                client.handshake.auth?.token ||
                client.handshake.query?.token ||
                (client.handshake.headers?.authorization?.split(' ')[1] as string);

            if (!token) {
                this.logger.warn(
                    `Client ${client.id} failed auth: No token`,
                );
                client.disconnect();
                return;
            }

            // 2. Verify token
            const payload = await this.jwtService.verifyAsync(token);
            const userId = payload.sub;

            // 3. Join room
            client.join(`user_${userId}`);
            this.logger.log(
                `User ${userId} connected and joined room user_${userId}`,
            );

            if (!this.userConnections.has(userId)) {
                this.userConnections.set(userId, new Set());
            }
            this.userConnections.get(userId)?.add(client.id);
        } catch (e) {
            this.logger.error(`Connection error: ${e.message}`);
            client.disconnect();
        }
    }

    handleDisconnect(client: Socket) {
        // Cleanup could be added here if needed, but for now we just let the socket disconnect
    }

    notifyDownloadProgress(userId: string, download: Download) {
        this.server.to(`user_${userId}`).emit('download_progress', download);
    }
}

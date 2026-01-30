import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';
import * as path from 'path';
import * as fs from 'fs';

interface NotificationPayload {
  title: string;
  body: string;
  data?: Record<string, string>;
}

@Injectable()
export class FcmService {
  private readonly logger = new Logger(FcmService.name);
  private isInitialized = false;

  constructor(private readonly configService: ConfigService) {
    this.initialize();
  }

  private async initialize() {
    if (admin.apps.length > 0) {
      this.isInitialized = true;
      return;
    }

    const serviceAccountPath = this.configService.get<string>(
      'FIREBASE_SERVICE_ACCOUNT_PATH',
    );
    const databaseUrl = this.configService.get<string>('FIREBASE_DATABASE_URL');
    const projectId = this.configService.get<string>('FIREBASE_PROJECT_ID');

    try {
      let credential;

      if (serviceAccountPath && fs.existsSync(serviceAccountPath)) {
        // Load from file (User request scenario)
        const serviceAccount = JSON.parse(
          fs.readFileSync(path.resolve(serviceAccountPath), 'utf8'),
        );
        credential = admin.credential.cert(serviceAccount);
        this.logger.log(
          `Initializing FCM with service account file: ${serviceAccountPath}`,
        );
      } else if (projectId) {
        // Fallback to Env Vars
        credential = admin.credential.cert({
          projectId: projectId,
          privateKey: this.configService
            .get<string>('FIREBASE_PRIVATE_KEY')
            ?.replace(/\\n/g, '\n'),
          clientEmail: this.configService.get<string>('FIREBASE_CLIENT_EMAIL'),
        });
        this.logger.log('Initializing FCM with ENV variables');
      } else {
        this.logger.warn(
          'FCM not configured (missing credentials). Running in Mock mode.',
        );
        return;
      }

      admin.initializeApp({
        credential,
        databaseURL: databaseUrl,
      });

      this.isInitialized = true;
      this.logger.log('FCM initialized successfully');
    } catch (error) {
      this.logger.error(`Failed to initialize FCM: ${error.message}`);
    }
  }

  async sendToDevice(
    fcmToken: string,
    notification: NotificationPayload,
  ): Promise<boolean> {
    if (!this.isInitialized) {
      this.logger.log(
        `[MOCK] Would send notification to ${fcmToken.substring(0, 10)}...`,
      );
      this.logger.log(`[MOCK] Title: ${notification.title}`);
      this.logger.log(`[MOCK] Body: ${notification.body}`);
      return true;
    }

    try {
      await admin.messaging().send({
        token: fcmToken,
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: notification.data,
      });
      this.logger.log(`Notification sent to ${fcmToken.substring(0, 10)}...`);
      return true;
    } catch (error) {
      this.logger.error(`Failed to send notification: ${error.message}`);
      return false;
    }
  }

  async sendToMultiple(
    fcmTokens: string[],
    notification: NotificationPayload,
  ): Promise<number> {
    // FCM multicast allows sending to up to 500 tokens at once
    if (!this.isInitialized) {
      return fcmTokens.length; // Mock success
    }

    if (fcmTokens.length === 0) return 0;

    try {
      const response = await admin.messaging().sendEachForMulticast({
        tokens: fcmTokens,
        notification: {
          title: notification.title,
          body: notification.body,
        },
        data: notification.data,
      });
      return response.successCount;
    } catch (error) {
      this.logger.error(
        `Failed to send multicast notification: ${error.message}`,
      );
      return 0;
    }
  }
}

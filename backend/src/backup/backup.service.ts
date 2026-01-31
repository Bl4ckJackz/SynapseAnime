import { Injectable, OnModuleInit, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as admin from 'firebase-admin';
import { WatchHistory } from '../entities/watch-history.entity';
import { User } from '../entities/user.entity';

@Injectable()
export class BackupService implements OnModuleInit {
  private readonly logger = new Logger(BackupService.name);
  private db: admin.firestore.Firestore;

  constructor(
    @InjectRepository(WatchHistory)
    private historyRepo: Repository<WatchHistory>,
    @InjectRepository(User)
    private userRepo: Repository<User>,
  ) {}

  onModuleInit() {
    // Initialize Firebase only if credentials exist and not already initialized
    if (process.env.GOOGLE_APPLICATION_CREDENTIALS && !admin.apps.length) {
      try {
        admin.initializeApp({
          credential: admin.credential.cert(
            process.env.GOOGLE_APPLICATION_CREDENTIALS,
          ),
        });
        this.db = admin.firestore();
        this.logger.log('Firebase initialized for Backup/Sync');
      } catch (e) {
        this.logger.error('Failed to initialize Firebase for backup', e);
      }
    } else if (admin.apps.length) {
      this.db = admin.firestore();
    }
  }

  /**
   * Syncs a user's watch history to Firestore
   */
  async syncUserHistory(userId: string) {
    if (!this.db) return;

    try {
      const history = await this.historyRepo.find({
        where: { user: { id: userId } },
        relations: ['user', 'episode'],
      });

      if (history.length === 0) return;

      const batch = this.db.batch();
      const userRef = this.db.collection('users').doc(userId);
      const historyCollection = userRef.collection('watch_history');

      // Sync each history item
      for (const item of history) {
        if (!item.episode) continue;

        const docRef = historyCollection.doc(
          `${item.episode.animeId}_${item.episodeId}`,
        );
        batch.set(
          docRef,
          {
            animeId: item.episode.animeId,
            episodeId: item.episodeId,
            progress: item.progressSeconds,
            completed: item.completed,
            lastUpdated: new Date(),
          },
          { merge: true },
        );
      }

      await batch.commit();
      this.logger.log(`Synced ${history.length} items for user ${userId}`);
    } catch (e) {
      this.logger.error(`Failed to sync user history for ${userId}`, e);
    }
  }
}

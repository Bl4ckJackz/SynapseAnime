import {
  Entity,
  Column,
  PrimaryGeneratedColumn,
  CreateDateColumn,
  OneToMany,
  OneToOne,
  JoinColumn,
} from 'typeorm';
import { Watchlist } from './watchlist.entity';
import { WatchHistory } from './watch-history.entity';
import { ReadingHistory } from './reading-history.entity';
import { UserPreference } from './user-preference.entity';
import { NotificationSettings } from './notification-settings.entity';
import { Subscription } from './subscription.entity';
import { Payment } from './payment.entity';
import { AdImpression } from './ad.entity';

export enum SubscriptionTier {
  FREE = 'free',
  PREMIUM = 'premium',
}

export enum SubscriptionStatus {
  ACTIVE = 'active',
  CANCELLED = 'cancelled',
  EXPIRED = 'expired',
}

@Entity()
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  email: string;

  @Column({ nullable: true })
  password?: string; // Nullable for Google Auth users

  @Column()
  nickname: string;

  @Column({ nullable: true })
  googleId?: string;

  @Column({ nullable: true })
  avatarUrl?: string;

  @Column({ type: 'varchar', nullable: true })
  fcmToken?: string;

  @Column({
    type: 'varchar',
    enum: SubscriptionTier,
    default: SubscriptionTier.FREE,
  })
  subscriptionTier: SubscriptionTier;

  @Column({
    type: 'varchar',
    enum: SubscriptionStatus,
    nullable: true,
  })
  subscriptionStatus: SubscriptionStatus;

  @Column({ nullable: true })
  subscriptionExpiresAt: Date;

  @Column('simple-array', { nullable: true })
  readingList: string[]; // Manga IDs

  @CreateDateColumn()
  createdAt: Date;

  @OneToMany(() => Watchlist, (watchlist) => watchlist.user)
  watchlist?: Watchlist[];

  @OneToMany(() => WatchHistory, (watchHistory) => watchHistory.user)
  watchHistory?: WatchHistory[];

  @OneToMany(() => ReadingHistory, (readingHistory) => readingHistory.user)
  readingHistory?: ReadingHistory[];

  @OneToMany(() => Subscription, (subscription) => subscription.user)
  subscriptions?: Subscription[];

  @OneToMany(() => Payment, (payment) => payment.user)
  payments?: Payment[];

  @OneToMany(() => AdImpression, (adImpression) => adImpression.user)
  adImpressions?: AdImpression[];

  @OneToOne(() => UserPreference, (preference) => preference.user)
  preference?: UserPreference;

  @OneToOne(
    () => NotificationSettings,
    (notificationSettings) => notificationSettings.user,
  )
  @JoinColumn()
  notificationSettings?: NotificationSettings;
}

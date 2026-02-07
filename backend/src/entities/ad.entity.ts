import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
} from 'typeorm';
import { User } from './user.entity';

@Entity('ads')
export class Ad {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  title: string;

  @Column({ type: 'text' })
  content: string;

  @Column()
  advertiser: string;

  @Column()
  adType: 'video' | 'banner' | 'native' | 'interstitial';

  @Column()
  targetAudience: 'all' | 'free_users' | 'premium_users';

  @Column({ type: 'simple-json', nullable: true })
  targetingCriteria?: {
    genres?: string[];
    demographics?: string[];
    behavior?: string[];
  };

  @Column({ type: 'int', default: 0 })
  impressions: number;

  @Column({ type: 'int', default: 0 })
  clicks: number;

  @Column({ type: 'float', default: 0 })
  ctr: number; // Click-through rate

  @Column({ nullable: true })
  startDate: Date;

  @Column({ nullable: true })
  endDate: Date;

  @Column({ default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

@Entity('ad_impressions')
export class AdImpression {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  adId: string;

  @Column()
  userId: string;

  @Column()
  sessionId: string;

  @Column({ type: 'int', nullable: true })
  durationWatched?: number; // For video ads

  @Column({ default: false })
  wasClicked: boolean;

  @CreateDateColumn()
  timestamp: Date;

  @ManyToOne(() => User, (user) => user.adImpressions)
  user: User;
}

import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  OneToOne,
  JoinColumn,
} from 'typeorm';
import { User } from './user.entity';

@Entity('notification_settings')
export class NotificationSettings {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @Column({ default: true })
  globalEnabled: boolean;

  @Column({ type: 'text', default: JSON.stringify({}) })
  animeSettings: string; // Store as JSON string for SQLite compatibility

  @OneToOne(() => User, (user) => user.notificationSettings, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'userId' })
  user: User;
}

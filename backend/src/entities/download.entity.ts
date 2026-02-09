import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from './user.entity';

export enum DownloadStatus {
  PENDING = 'pending',
  DOWNLOADING = 'downloading',
  COMPLETED = 'completed',
  FAILED = 'failed',
  CANCELLED = 'cancelled',
}

@Entity('downloads')
export class Download {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @Column()
  animeId: string;

  @Column()
  animeName: string;

  @Column()
  episodeId: string;

  @Column({ type: 'int' })
  episodeNumber: number;

  @Column({ nullable: true })
  episodeTitle: string;

  @Column({
    type: 'varchar',
    default: DownloadStatus.PENDING,
  })
  status: DownloadStatus;

  @Column({ type: 'int', default: 0 })
  progress: number; // 0-100

  @Column({ nullable: true })
  filePath: string;

  @Column({ nullable: true })
  fileName: string;

  @Column({ nullable: true })
  errorMessage: string;

  @Column({ type: 'text', nullable: true })
  streamUrl: string;

  @Column({ nullable: true })
  thumbnailPath: string;

  @Column({ type: 'text', nullable: true })
  thumbnailUrl: string;

  @Column({ nullable: true })
  source: string; // e.g., 'animeunity', 'hianime'

  @CreateDateColumn()
  createdAt: Date;

  @Column({ type: 'datetime', nullable: true })
  completedAt: Date;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;
}

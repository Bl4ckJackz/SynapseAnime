import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  OneToOne,
  JoinColumn,
  UpdateDateColumn,
} from 'typeorm';
import { User } from './user.entity';

@Entity('download_settings')
export class DownloadSettings {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @Column({ nullable: true })
  downloadPath: string; // Local/server path for downloads

  @Column({ default: false })
  useServerFolder: boolean; // If true, download to server folder instead of local

  @Column({ nullable: true })
  serverFolderPath: string; // Path on the server for downloads

  @UpdateDateColumn()
  updatedAt: Date;

  @OneToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;
}

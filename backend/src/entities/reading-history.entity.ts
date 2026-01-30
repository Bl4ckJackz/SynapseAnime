import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  UpdateDateColumn,
} from 'typeorm';
import { User } from './user.entity';
import { Manga } from './manga.entity';
import { Chapter } from './chapter.entity';

@Entity('reading_history')
export class ReadingHistory {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @ManyToOne(() => User, (user) => user.readingHistory)
  user: User;

  @ManyToOne(() => Manga)
  manga: Manga;

  @ManyToOne(() => Chapter)
  chapter: Chapter;

  @Column({ type: 'float', default: 0 })
  progress: number; // Percentage or page number

  @UpdateDateColumn()
  lastReadAt: Date;
}

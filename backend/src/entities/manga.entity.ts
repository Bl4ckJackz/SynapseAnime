import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  OneToMany,
} from 'typeorm';
import { Chapter } from './chapter.entity';

export enum MangaStatus {
  ONGOING = 'ongoing',
  COMPLETED = 'completed',
  HIATUS = 'hiatus',
  CANCELLED = 'cancelled',
}

@Entity('manga')
export class Manga {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  mangadexId: string;

  @Column()
  title: string;

  @Column({ type: 'simple-json', nullable: true })
  altTitles: Record<string, string>;

  @Column({ type: 'text' })
  description: string;

  @Column('simple-array', { nullable: true })
  authors: string[];

  @Column('simple-array', { nullable: true })
  artists: string[];

  @Column('simple-array')
  genres: string[];

  @Column('simple-array', { nullable: true })
  tags: string[];

  @Column({
    type: 'varchar',
    enum: MangaStatus,
    default: MangaStatus.ONGOING,
  })
  status: MangaStatus;

  @Column({ type: 'int', nullable: true })
  year: number;

  @Column({ nullable: true })
  coverImage: string;

  @Column({ type: 'float', default: 0 })
  rating: number;

  @OneToMany(() => Chapter, (chapter) => chapter.manga)
  chapters: Chapter[];

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}

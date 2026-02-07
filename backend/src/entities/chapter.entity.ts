import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  CreateDateColumn,
} from 'typeorm';
import { Manga } from './manga.entity';

@Entity('chapter')
export class Chapter {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  mangadexChapterId: string;

  @Column({ type: 'float' })
  number: number;

  @Column({ nullable: true })
  title: string;

  @Column({ type: 'float', nullable: true })
  volume?: number;

  @Column({ type: 'int', default: 0 })
  pages: number;

  @Column()
  language: string;

  @Column({ nullable: true })
  scanlationGroup: string;

  @Column()
  publishedAt: Date;

  @ManyToOne(() => Manga, (manga) => manga.chapters)
  manga: Manga;

  @Column()
  mangaId: string;

  @CreateDateColumn()
  createdAt: Date;
}

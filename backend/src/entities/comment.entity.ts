import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
  JoinColumn,
  OneToMany,
} from 'typeorm';
import { User } from './user.entity';
import { Anime } from './anime.entity';
import { Manga } from './manga.entity';
import { Episode } from './episode.entity';

@Entity('comments')
export class Comment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @Column({ type: 'text' })
  text: string;

  @Column({ type: 'int', nullable: true })
  rating: number; // 1-5 stars, optional

  // Target identifiers - one of these should be set
  @Column({ nullable: true })
  animeId: string;

  @Column({ nullable: true })
  mangaId: string;

  @Column({ nullable: true })
  episodeId: string;

  // For threaded replies
  @Column({ nullable: true })
  parentId: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  // Relations
  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;

  @ManyToOne(() => Anime, { onDelete: 'CASCADE', nullable: true })
  @JoinColumn({ name: 'animeId' })
  anime: Anime;

  @ManyToOne(() => Manga, { onDelete: 'CASCADE', nullable: true })
  @JoinColumn({ name: 'mangaId' })
  manga: Manga;

  @ManyToOne(() => Episode, { onDelete: 'CASCADE', nullable: true })
  @JoinColumn({ name: 'episodeId' })
  episode: Episode;

  @ManyToOne(() => Comment, { onDelete: 'CASCADE', nullable: true })
  @JoinColumn({ name: 'parentId' })
  parent: Comment;

  @OneToMany(() => Comment, (comment) => comment.parent)
  replies: Comment[];
}

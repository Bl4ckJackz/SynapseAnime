import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  CreateDateColumn,
  Unique,
} from 'typeorm';
import { User } from './user.entity';
import { Anime } from './anime.entity';
import { Manga } from './manga.entity';

@Entity('watchlist')
@Unique(['userId', 'animeId', 'mangaId'])
export class Watchlist {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @Column({ nullable: true })
  animeId: string | null;

  @Column({ nullable: true })
  mangaId: string | null;

  @CreateDateColumn()
  addedAt: Date;

  @ManyToOne(() => User, (user) => user.watchlist, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;

  @ManyToOne(() => Anime, (anime) => anime.watchlist, {
    onDelete: 'CASCADE',
    nullable: true,
  })
  @JoinColumn({ name: 'animeId' })
  anime: Anime;

  @ManyToOne(() => Manga, { onDelete: 'CASCADE', nullable: true })
  @JoinColumn({ name: 'mangaId' })
  manga: Manga;
}

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

@Entity('watchlist')
@Unique(['userId', 'animeId'])
export class Watchlist {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @Column()
  animeId: string;

  @CreateDateColumn()
  addedAt: Date;

  @ManyToOne(() => User, (user) => user.watchlist, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;

  @ManyToOne(() => Anime, (anime) => anime.watchlist, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'animeId' })
  anime: Anime;
}

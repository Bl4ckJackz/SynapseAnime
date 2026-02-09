import {
  Entity,
  PrimaryColumn,
  Column,
  ManyToOne,
  OneToMany,
  JoinColumn,
} from 'typeorm';
import { Anime } from './anime.entity';
import { WatchHistory } from './watch-history.entity';

@Entity('episodes')
export class Episode {
  @PrimaryColumn()
  id: string;

  @Column()
  animeId: string;

  @Column({ type: 'int' })
  number: number;

  @Column()
  title: string;

  @Column({ type: 'int', default: 0 })
  duration: number; // in seconds

  @Column({ nullable: true })
  thumbnail: string;

  @Column()
  streamUrl: string;

  @Column({ nullable: true })
  source: string;

  @ManyToOne(() => Anime, (anime) => anime.episodes, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'animeId' })
  anime: Anime;

  // Temporarily commenting out the relation to avoid circular dependency issues
  // @OneToMany(() => WatchHistory, (watchHistory) => watchHistory.episode)
  // watchHistory: WatchHistory[];
}

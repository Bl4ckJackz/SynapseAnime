import {
  Entity,
  PrimaryColumn,
  Column,
  CreateDateColumn,
  OneToMany,
} from 'typeorm';
import { Episode } from './episode.entity';
import { Watchlist } from './watchlist.entity';
import { ReleaseSchedule } from './release-schedule.entity';
import { StreamingSource } from '../types/streaming.types';

export enum AnimeStatus {
  ONGOING = 'ongoing',
  COMPLETED = 'completed',
  UPCOMING = 'upcoming',
}

@Entity('anime')
export class Anime {
  @PrimaryColumn()
  id: string;

  @Column({ nullable: true })
  malId: number;

  @Column()
  title: string;

  @Column({ nullable: true })
  titleEnglish: string;

  @Column({ nullable: true })
  titleJapanese: string;

  @Column({ type: 'text' })
  description: string;

  @Column({ type: 'text', nullable: true })
  synopsis: string;

  @Column({ nullable: true })
  coverUrl: string;

  @Column({ nullable: true })
  bannerImage: string;

  @Column({ nullable: true })
  trailerUrl: string;

  @Column('simple-array')
  genres: string[];

  @Column('simple-array', { nullable: true })
  studios: string[];

  @Column({
    type: 'varchar',
    enum: AnimeStatus,
    default: AnimeStatus.ONGOING,
  })
  status: AnimeStatus;

  @Column({ type: 'varchar', nullable: true })
  duration: string;

  @Column({ type: 'varchar', nullable: true })
  type: string;

  @Column({ type: 'int' })
  releaseYear: number;

  @Column({ type: 'simple-json', nullable: true })
  aired: { from: Date; to?: Date };

  @Column({ type: 'float', default: 0 })
  rating: number;

  @Column({ type: 'int', default: 0 })
  popularity: number;

  @Column({ type: 'int', default: 0 })
  totalEpisodes: number;

  @Column({ type: 'simple-json', nullable: true })
  streamingSources: StreamingSource[];

  @CreateDateColumn()
  createdAt: Date;

  @OneToMany(() => Episode, (episode) => episode.anime)
  episodes: Episode[];

  @OneToMany(() => Watchlist, (watchlist) => watchlist.anime)
  watchlist: Watchlist[];

  @OneToMany(() => ReleaseSchedule, (schedule) => schedule.anime)
  releaseSchedules: ReleaseSchedule[];
}

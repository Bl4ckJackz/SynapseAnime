import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { Anime } from './anime.entity';

@Entity('release_schedules')
export class ReleaseSchedule {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  animeId: string;

  @Column({ type: 'int' })
  episodeNumber: number;

  @Column({ type: 'datetime' })
  releaseDate: Date;

  @Column({ default: false })
  notified: boolean;

  @ManyToOne(() => Anime, (anime) => anime.releaseSchedules, {
    onDelete: 'CASCADE',
  })
  @JoinColumn({ name: 'animeId' })
  anime: Anime;
}

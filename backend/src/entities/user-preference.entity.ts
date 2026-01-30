import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  OneToOne,
  JoinColumn,
} from 'typeorm';
import { User } from './user.entity';

@Entity('user_preferences')
export class UserPreference {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @Column('simple-array', { default: '' })
  preferredLanguages: string[];

  @Column('simple-array', { default: '' })
  preferredGenres: string[];

  @OneToOne('User', 'preference', { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'userId' })
  user: User;
}

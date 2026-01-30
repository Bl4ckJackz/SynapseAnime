import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
} from 'typeorm';

@Entity('news')
export class News {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  source: 'myanimelist' | 'anilist' | 'custom';

  @Column({ nullable: true })
  sourceId?: string;

  @Column()
  title: string;

  @Column({ type: 'text' })
  content: string;

  @Column({ type: 'text' })
  excerpt: string;

  @Column({ nullable: true })
  coverImage?: string;

  @Column({
    type: 'varchar',
  })
  category: string;

  @Column('simple-array', { nullable: true })
  tags: string[];

  @Column({ type: 'datetime' })
  publishedAt: Date;

  @Column({ nullable: true })
  externalUrl?: string;

  @Column({ default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
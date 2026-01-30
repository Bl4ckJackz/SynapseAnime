import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  ManyToOne,
} from 'typeorm';
import { User } from './user.entity';

@Entity('payments')
export class Payment {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  userId: string;

  @Column()
  subscriptionId: string;

  @Column({ type: 'float' })
  amount: number;

  @Column()
  currency: string;

  @Column()
  status: 'pending' | 'completed' | 'failed' | 'refunded';

  @Column()
  paymentMethod: 'stripe' | 'paypal' | 'credit_card' | 'debit_card';

  @Column({ nullable: true })
  transactionId?: string;

  @Column({ nullable: true })
  receiptUrl?: string;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;

  @ManyToOne(() => User, user => user.payments)
  user: User;
}
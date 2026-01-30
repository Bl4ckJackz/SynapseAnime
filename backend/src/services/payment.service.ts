import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Payment } from '../entities/payment.entity';
import { User } from '../entities/user.entity';
import { Subscription } from '../entities/subscription.entity';
import { ConfigService } from '@nestjs/config';
import Stripe from 'stripe';

@Injectable()
export class PaymentService {
  private stripe: Stripe;

  constructor(
    @InjectRepository(Payment)
    private paymentRepository: Repository<Payment>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(Subscription)
    private subscriptionRepository: Repository<Subscription>,
    private configService: ConfigService,
  ) {
    const stripeKey = configService.get<string>('STRIPE_SECRET_KEY');
    if (!stripeKey) {
      console.warn('Stripe secret key not found. Payment features will be disabled.');
    }
    this.stripe = new Stripe(stripeKey || 'sk_test_placeholder', {
      apiVersion: '2024-11-20.acacia' as any, // Using 'as any' to bypass version check
    });
  }

  async createPaymentIntent(userId: string, amount: number, currency: string = 'usd'): Promise<string> {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    
    if (!user) {
      throw new Error('User not found');
    }

    const paymentIntent = await this.stripe.paymentIntents.create({
      amount: amount * 100, // Convert to cents
      currency,
      metadata: {
        userId: user.id,
      },
      automatic_payment_methods: {
        enabled: true,
      },
    });

    return paymentIntent.client_secret!;
  }

  async processSubscriptionPayment(userId: string, subscriptionId: string): Promise<Payment> {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    const subscription = await this.subscriptionRepository.findOne({ where: { id: subscriptionId } });

    if (!user || !subscription) {
      throw new Error('User or subscription not found');
    }

    // In a real implementation, this would charge the user's saved payment method
    // For now, we'll simulate a successful payment
    const payment = new Payment();
    payment.userId = userId;
    payment.subscriptionId = subscriptionId;
    payment.amount = subscription.amount;
    payment.currency = 'usd';
    payment.status = 'completed';
    payment.paymentMethod = 'stripe';
    payment.transactionId = `txn_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
    payment.receiptUrl = `https://receipts.example.com/${payment.transactionId}`;

    return await this.paymentRepository.save(payment);
  }

  async refundPayment(paymentId: string, reason?: string): Promise<Payment> {
    const payment = await this.paymentRepository.findOne({ where: { id: paymentId } });

    if (!payment) {
      throw new Error('Payment not found');
    }

    if (payment.status !== 'completed') {
      throw new Error('Cannot refund a payment that is not completed');
    }

    try {
      // Create refund in Stripe
      await this.stripe.refunds.create({
        payment_intent: payment.transactionId,
        reason: reason as any, // Type assertion to bypass strict typing
      });

      // Update payment status
      payment.status = 'refunded';
      return await this.paymentRepository.save(payment);
    } catch (error) {
      console.error('Error processing refund:', error);
      throw new Error('Failed to process refund');
    }
  }

  async getPaymentHistory(userId: string): Promise<Payment[]> {
    return await this.paymentRepository.find({
      where: { userId },
      order: { createdAt: 'DESC' },
    });
  }

  async getPaymentById(paymentId: string): Promise<Payment | null> {
    return await this.paymentRepository.findOne({ where: { id: paymentId } });
  }

  async handlePaymentWebhook(payload: Buffer, signature: string): Promise<void> {
    const webhookSecret = this.configService.get<string>('STRIPE_WEBHOOK_SECRET');
    
    let event: Stripe.Event;
    
    try {
      event = this.stripe.webhooks.constructEvent(payload, signature, webhookSecret!);
    } catch (err) {
      console.error(`Webhook signature verification failed: ${err.message}`);
      throw err;
    }

    switch (event.type) {
      case 'payment_intent.succeeded':
        await this.handlePaymentIntentSucceeded(event.data.object);
        break;
      case 'payment_intent.payment_failed':
        await this.handlePaymentIntentFailed(event.data.object);
        break;
      case 'charge.refunded':
        await this.handleChargeRefunded(event.data.object);
        break;
      default:
        console.log(`Unhandled event type: ${event.type}`);
    }
  }

  private async handlePaymentIntentSucceeded(paymentIntent: Stripe.PaymentIntent): Promise<void> {
    const userId = paymentIntent.metadata?.userId;
    
    if (!userId) {
      console.error('No userId found in payment intent metadata');
      return;
    }

    // Create payment record
    const payment = new Payment();
    payment.userId = userId;
    payment.subscriptionId = paymentIntent.metadata?.subscriptionId || '';
    payment.amount = paymentIntent.amount / 100; // Convert from cents
    payment.currency = paymentIntent.currency;
    payment.status = 'completed';
    payment.paymentMethod = 'stripe';
    payment.transactionId = paymentIntent.id;
    
    // Generate a mock receipt URL
    payment.receiptUrl = `https://receipts.example.com/${paymentIntent.id}`;
    
    await this.paymentRepository.save(payment);
  }

  private async handlePaymentIntentFailed(paymentIntent: Stripe.PaymentIntent): Promise<void> {
    const userId = paymentIntent.metadata?.userId;
    
    if (!userId) {
      console.error('No userId found in payment intent metadata');
      return;
    }

    // Create payment record with failed status
    const payment = new Payment();
    payment.userId = userId;
    payment.subscriptionId = paymentIntent.metadata?.subscriptionId || '';
    payment.amount = paymentIntent.amount / 100; // Convert from cents
    payment.currency = paymentIntent.currency;
    payment.status = 'failed';
    payment.paymentMethod = 'stripe';
    payment.transactionId = paymentIntent.id;
    
    await this.paymentRepository.save(payment);
  }

  private async handleChargeRefunded(charge: Stripe.Charge): Promise<void> {
    // Find the payment record associated with this charge
    const payment = await this.paymentRepository.findOne({
      where: { transactionId: charge.id },
    });

    if (payment) {
      payment.status = 'refunded';
      await this.paymentRepository.save(payment);
    }
  }

  async createPayPalPayment(userId: string, amount: number, currency: string = 'usd'): Promise<any> {
    // This would integrate with PayPal's API
    // For now, we'll return a mock response
    console.log(`Creating PayPal payment for user ${userId}, amount: ${amount} ${currency}`);
    
    return {
      id: `paypal_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
      status: 'created',
      redirectUrl: `https://paypal.example.com/pay/${userId}`,
    };
  }

  async verifyPayment(paymentId: string): Promise<boolean> {
    const payment = await this.paymentRepository.findOne({ where: { id: paymentId } });
    
    if (!payment) {
      return false;
    }

    if (payment.status === 'completed') {
      return true;
    }

    // If payment is pending, verify with payment processor
    if (payment.paymentMethod === 'stripe' && payment.transactionId) {
      try {
        const stripePayment = await this.stripe.paymentIntents.retrieve(payment.transactionId);
        if (stripePayment.status === 'succeeded') {
          payment.status = 'completed';
          await this.paymentRepository.save(payment);
          return true;
        }
      } catch (error) {
        console.error('Error verifying payment with Stripe:', error);
      }
    }

    return payment.status === 'completed';
  }
}
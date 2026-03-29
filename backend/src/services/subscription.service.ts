import { Injectable, Logger } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, IsNull, Not } from 'typeorm';
import { User } from '../entities/user.entity';
import {
  Subscription,
  SubscriptionStatus,
  SubscriptionTier,
} from '../entities/subscription.entity';
import { Payment } from '../entities/payment.entity';
import { ConfigService } from '@nestjs/config';
import Stripe from 'stripe';

@Injectable()
export class SubscriptionService {
  private readonly logger = new Logger(SubscriptionService.name);
  private stripe: Stripe;

  constructor(
    @InjectRepository(User)
    private userRepository: Repository<User>,
    @InjectRepository(Subscription)
    private subscriptionRepository: Repository<Subscription>,
    @InjectRepository(Payment)
    private paymentRepository: Repository<Payment>,
    private configService: ConfigService,
  ) {
    const stripeKey = configService.get<string>('STRIPE_SECRET_KEY');
    if (!stripeKey) {
      this.logger.warn(
        'Stripe secret key not found. Subscription features will be disabled.',
      );
    }
    this.stripe = new Stripe(stripeKey || 'sk_test_placeholder', {
      apiVersion: '2024-11-20.acacia' as any,
    });
  }

  async createCheckoutSession(
    userId: string,
    plan: 'premium',
  ): Promise<string> {
    const user = await this.userRepository.findOne({ where: { id: userId } });

    if (!user) {
      throw new Error('User not found');
    }

    // Determine price based on plan
    const prices = {
      premium: this.configService.get<string>('STRIPE_PREMIUM_PRICE_ID'),
    };

    const session = await this.stripe.checkout.sessions.create({
      payment_method_types: ['card'],
      line_items: [
        {
          price: prices[plan], // This should be configured in your Stripe dashboard
          quantity: 1,
        },
      ],
      mode: 'subscription',
      success_url: `${process.env.FRONTEND_URL}/subscription/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${process.env.FRONTEND_URL}/subscription/cancel`,
      customer_email: user.email,
      metadata: {
        userId: user.id,
      },
    });

    return session.id;
  }

  async handleWebhook(payload: Buffer, signature: string): Promise<void> {
    const webhookSecret = this.configService.get<string>(
      'STRIPE_WEBHOOK_SECRET',
    );

    let event: Stripe.Event;

    try {
      event = this.stripe.webhooks.constructEvent(
        payload,
        signature,
        webhookSecret!,
      );
    } catch (err) {
      this.logger.error(`Webhook signature verification failed: ${err.message}`);
      throw err;
    }

    switch (event.type) {
      case 'checkout.session.completed':
        await this.handleCheckoutSessionCompleted(event.data.object);
        break;
      case 'invoice.payment_succeeded':
        await this.handleInvoicePaymentSucceeded(event.data.object);
        break;
      case 'customer.subscription.updated':
        await this.handleSubscriptionUpdated(event.data.object);
        break;
      case 'customer.subscription.deleted':
        await this.handleSubscriptionDeleted(event.data.object);
        break;
      default:
        this.logger.log(`Unhandled event type: ${event.type}`);
    }
  }

  private async handleCheckoutSessionCompleted(
    session: Stripe.Checkout.Session,
  ): Promise<void> {
    const userId = session.metadata?.userId;

    if (!userId) {
      this.logger.error('No userId found in session metadata');
      return;
    }

    // Find or create subscription record
    let subscription = await this.subscriptionRepository.findOne({
      where: {
        userId: userId,
        stripeSubscriptionId: session.subscription as string,
      },
    });

    if (!subscription) {
      subscription = new Subscription();
      subscription.userId = userId;
      subscription.stripeSubscriptionId = session.subscription as string;
      subscription.stripeCustomerId = session.customer as string;
      subscription.tier = SubscriptionTier.PREMIUM;
      subscription.status = SubscriptionStatus.ACTIVE;

      // Calculate dates based on Stripe subscription
      const stripeSubscription = await this.stripe.subscriptions.retrieve(
        session.subscription as string,
      );

      subscription.startDate = new Date(
        (stripeSubscription as any).current_period_start * 1000,
      );
      subscription.endDate = new Date(
        (stripeSubscription as any).current_period_end * 1000,
      );
      subscription.amount =
        (stripeSubscription as any).items.data[0].price.unit_amount / 100; // Convert cents to dollars

      await this.subscriptionRepository.save(subscription);
    }

    // Update user subscription status
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (user) {
      user.subscriptionTier = SubscriptionTier.PREMIUM;
      user.subscriptionStatus = SubscriptionStatus.ACTIVE;
      user.subscriptionExpiresAt = new Date(subscription.endDate);
      await this.userRepository.save(user);
    }
  }

  private async handleInvoicePaymentSucceeded(
    invoice: Stripe.Invoice,
  ): Promise<void> {
    // Handle successful recurring payment
    const subscriptionId = (invoice as any).subscription as string;

    const subscription = await this.subscriptionRepository.findOne({
      where: { stripeSubscriptionId: subscriptionId },
    });

    if (subscription) {
      // Update end date to next billing cycle
      const stripeSubscription =
        await this.stripe.subscriptions.retrieve(subscriptionId);
      subscription.endDate = new Date(
        (stripeSubscription as any).current_period_end * 1000,
      );
      await this.subscriptionRepository.save(subscription);

      // Update user expiration date
      const user = await this.userRepository.findOne({
        where: { id: subscription.userId },
      });
      if (user) {
        user.subscriptionExpiresAt = new Date(subscription.endDate);
        await this.userRepository.save(user);
      }
    }
  }

  private async handleSubscriptionUpdated(
    subscription: Stripe.Subscription,
  ): Promise<void> {
    const dbSubscription = await this.subscriptionRepository.findOne({
      where: { stripeSubscriptionId: subscription.id },
    });

    if (dbSubscription) {
      // Update status based on Stripe subscription status
      switch (subscription.status) {
        case 'active':
          dbSubscription.status = SubscriptionStatus.ACTIVE;
          break;
        case 'canceled':
        case 'unpaid':
        case 'incomplete_expired':
          dbSubscription.status = SubscriptionStatus.CANCELLED;
          break;
        case 'past_due':
          // Could implement grace period logic here
          break;
      }

      // Update dates
      dbSubscription.startDate = new Date(
        (subscription as any).current_period_start * 1000,
      );
      dbSubscription.endDate = new Date(
        (subscription as any).current_period_end * 1000,
      );

      await this.subscriptionRepository.save(dbSubscription);

      // Update user status
      const user = await this.userRepository.findOne({
        where: { id: dbSubscription.userId },
      });
      if (user) {
        user.subscriptionStatus = dbSubscription.status;
        user.subscriptionExpiresAt = new Date(dbSubscription.endDate);

        if (dbSubscription.status === SubscriptionStatus.ACTIVE) {
          user.subscriptionTier = SubscriptionTier.PREMIUM;
        } else {
          user.subscriptionTier = SubscriptionTier.FREE;
        }

        await this.userRepository.save(user);
      }
    }
  }

  private async handleSubscriptionDeleted(
    subscription: Stripe.Subscription,
  ): Promise<void> {
    const dbSubscription = await this.subscriptionRepository.findOne({
      where: { stripeSubscriptionId: subscription.id },
    });

    if (dbSubscription) {
      dbSubscription.status = SubscriptionStatus.CANCELLED;
      await this.subscriptionRepository.save(dbSubscription);

      // Update user status
      const user = await this.userRepository.findOne({
        where: { id: dbSubscription.userId },
      });
      if (user) {
        user.subscriptionStatus = SubscriptionStatus.CANCELLED;
        user.subscriptionTier = SubscriptionTier.FREE;
        await this.userRepository.save(user);
      }
    }
  }

  async cancelSubscription(userId: string): Promise<void> {
    const user = await this.userRepository.findOne({ where: { id: userId } });

    if (!user) {
      throw new Error('User not found');
    }

    // Find active subscription
    const subscription = await this.subscriptionRepository.findOne({
      where: {
        userId: userId,
        status: SubscriptionStatus.ACTIVE,
        stripeSubscriptionId: Not(IsNull()),
      },
    });

    if (!subscription || !subscription.stripeSubscriptionId) {
      throw new Error('No active subscription found');
    }

    // Cancel subscription in Stripe
    await this.stripe.subscriptions.cancel(subscription.stripeSubscriptionId);

    // Update local subscription status
    subscription.status = SubscriptionStatus.CANCELLED;
    await this.subscriptionRepository.save(subscription);

    // Update user status
    user.subscriptionStatus = SubscriptionStatus.CANCELLED;
    user.subscriptionTier = SubscriptionTier.FREE;
    await this.userRepository.save(user);
  }

  async checkSubscriptionStatus(
    userId: string,
  ): Promise<{ isActive: boolean; tier: SubscriptionTier }> {
    const user = await this.userRepository.findOne({ where: { id: userId } });

    if (!user) {
      return { isActive: false, tier: SubscriptionTier.FREE };
    }

    // Check if subscription has expired
    if (user.subscriptionExpiresAt && user.subscriptionExpiresAt < new Date()) {
      // Update status in DB if expired
      user.subscriptionStatus = SubscriptionStatus.EXPIRED;
      user.subscriptionTier = SubscriptionTier.FREE;
      await this.userRepository.save(user);

      return { isActive: false, tier: SubscriptionTier.FREE };
    }

    return {
      isActive: user.subscriptionStatus === SubscriptionStatus.ACTIVE,
      tier: user.subscriptionTier,
    };
  }

  async getSubscriptionDetails(userId: string): Promise<Subscription | null> {
    return await this.subscriptionRepository.findOne({
      where: {
        userId: userId,
        status: SubscriptionStatus.ACTIVE,
      },
      order: { createdAt: 'DESC' },
    });
  }
}

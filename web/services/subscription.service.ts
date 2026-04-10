import { apiClient } from "./api-client";
import type { User } from "@/types/user";

export interface CheckoutSession {
  url: string;
  sessionId: string;
}

class SubscriptionService {
  async createCheckoutSession(priceId?: string): Promise<CheckoutSession> {
    return apiClient.post<CheckoutSession>("/monetization/checkout", {
      priceId,
    });
  }

  async cancelSubscription(): Promise<void> {
    return apiClient.post<void>("/monetization/cancel");
  }

  async getSubscriptionStatus(): Promise<User> {
    return apiClient.get<User>("/users/profile");
  }
}

export const subscriptionService = new SubscriptionService();

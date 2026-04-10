export type SubscriptionTier = "free" | "premium";
export type SubscriptionStatus = "active" | "cancelled" | "expired";

export interface User {
  id: string;
  email: string;
  nickname?: string;
  avatarUrl?: string;
  googleId?: string;
  fcmToken?: string;
  subscriptionTier: SubscriptionTier;
  subscriptionStatus?: SubscriptionStatus;
  subscriptionExpiresAt?: string;
  readingList?: string[];
  preference?: UserPreference;
  createdAt: string;
}

export interface UserPreference {
  id: string;
  userId: string;
  preferredLanguages: string[];
  preferredGenres: string[];
}

export interface NotificationSettings {
  id: string;
  userId: string;
  globalEnabled: boolean;
  animeSettings: string;
}

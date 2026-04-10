import { apiClient } from "./api-client";
import type { NotificationSettings } from "@/types/user";

class NotificationService {
  getSettings(): Promise<NotificationSettings> {
    return apiClient.get<NotificationSettings>("/notifications/settings");
  }

  updateSettings(data: {
    globalEnabled?: boolean;
    animeId?: string;
    animeEnabled?: boolean;
  }): Promise<NotificationSettings> {
    return apiClient.put<NotificationSettings>(
      "/notifications/settings",
      data,
    );
  }
}

export const notificationService = new NotificationService();

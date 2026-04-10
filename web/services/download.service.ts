import { apiClient } from "./api-client";
import type { Download, DownloadSettings } from "@/types/download";

class DownloadService {
  getQueue(): Promise<Download[]> {
    return apiClient.get<Download[]>("/download/queue");
  }

  getHistory(limit?: number): Promise<Download[]> {
    return apiClient.get<Download[]>("/download/history", { limit });
  }

  downloadEpisode(
    animeId: string,
    episodeId: string,
    source?: string,
  ): Promise<{ message: string; download: Download }> {
    return apiClient.post<{ message: string; download: Download }>(
      `/download/episode/${animeId}/${episodeId}${source ? `?source=${source}` : ""}`,
    );
  }

  downloadFromUrl(data: {
    url: string;
    animeName: string;
    episodeNumber: number;
    episodeTitle?: string;
  }): Promise<{ message: string; download: Download }> {
    return apiClient.post<{ message: string; download: Download }>(
      "/download/url",
      data,
    );
  }

  cancelDownload(id: string): Promise<void> {
    return apiClient.delete<void>(`/download/${id}`);
  }

  deleteDownloadFile(id: string): Promise<void> {
    return apiClient.delete<void>(`/download/${id}/file`);
  }

  clearHistory(): Promise<void> {
    return apiClient.delete<void>("/download/clear");
  }

  getSettings(): Promise<DownloadSettings> {
    return apiClient.get<DownloadSettings>("/download/settings");
  }

  updateSettings(
    data: Partial<Pick<DownloadSettings, "downloadPath" | "useServerFolder" | "serverFolderPath">>,
  ): Promise<DownloadSettings> {
    return apiClient.put<DownloadSettings>("/download/settings", data);
  }
}

export const downloadService = new DownloadService();

export type DownloadStatus =
  | "pending"
  | "downloading"
  | "completed"
  | "failed"
  | "cancelled";

export interface Download {
  id: string;
  userId: string;
  animeId: string;
  animeName: string;
  episodeId: string;
  episodeNumber: number;
  episodeTitle?: string;
  status: DownloadStatus;
  progress: number;
  filePath?: string;
  fileName?: string;
  errorMessage?: string;
  streamUrl?: string;
  thumbnailPath?: string;
  thumbnailUrl?: string;
  source?: string;
  createdAt: string;
  completedAt?: string;
}

export interface DownloadSettings {
  id: string;
  userId: string;
  downloadPath?: string;
  useServerFolder: boolean;
  serverFolderPath?: string;
  updatedAt: string;
}

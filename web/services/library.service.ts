import { apiClient } from "./api-client";

export interface Folder {
  id: string;
  name: string;
  path: string;
  videoCount?: number;
}

export interface LibraryVideo {
  id: string;
  name: string;
  path: string;
  size?: number;
  duration?: number;
}

const API_BASE_URL =
  process.env.NEXT_PUBLIC_API_URL || "http://localhost:3005";

class LibraryService {
  getFolders(): Promise<Folder[]> {
    return apiClient.get<Folder[]>("/library/folders");
  }

  getFolderVideos(folderId: string): Promise<LibraryVideo[]> {
    return apiClient.get<LibraryVideo[]>(
      `/library/folder/${folderId}/videos`,
    );
  }

  getStreamUrl(videoId: string): string {
    return `${API_BASE_URL}/library/stream/${videoId}/direct`;
  }

  getHlsUrl(videoId: string): string {
    return `${API_BASE_URL}/library/stream/${videoId}/playlist.m3u8`;
  }
}

export const libraryService = new LibraryService();

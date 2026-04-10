export type MangaStatus = "ongoing" | "completed" | "hiatus" | "cancelled";

export interface Manga {
  id: string;
  mangadexId: string;
  title: string;
  altTitles?: Record<string, string>;
  description: string;
  authors: string[];
  artists: string[];
  genres: string[];
  tags: string[];
  status: MangaStatus;
  year?: number;
  coverImage?: string;
  rating: number;
  createdAt: string;
  updatedAt: string;
}

export interface Chapter {
  id: string;
  mangadexChapterId: string;
  number: number;
  title?: string;
  volume?: number;
  pages: number;
  language: string;
  scanlationGroup?: string;
  publishedAt: string;
  mangaId: string;
  createdAt: string;
}

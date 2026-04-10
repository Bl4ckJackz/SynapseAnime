export type NewsSource = "myanimelist" | "anilist" | "custom";

export interface News {
  id: string;
  source: NewsSource;
  sourceId?: string;
  title: string;
  content: string;
  excerpt: string;
  coverImage?: string;
  category: string;
  tags: string[];
  publishedAt: string;
  externalUrl?: string;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

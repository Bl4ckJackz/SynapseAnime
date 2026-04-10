import type { User } from "./user";

export interface Comment {
  id: string;
  userId: string;
  user?: User;
  text: string;
  rating?: number;
  animeId?: string;
  mangaId?: string;
  episodeId?: string;
  parentId?: string;
  replies?: Comment[];
  createdAt: string;
  updatedAt: string;
}

export interface RatingInfo {
  averageRating: number;
  totalRatings: number;
}

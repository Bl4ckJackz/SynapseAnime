import { Anime } from '../../entities/anime.entity';

export interface UserContext {
  userId: string;
  preferredGenres: string[];
  preferredLanguages: string[];
  watchedAnimeIds: string[];
}

export interface RecommendationRequest {
  message: string;
  context: UserContext;
}

export interface RecommendationResponse {
  message: string;
  recommendedAnimeIds: string[];
}

export interface ChatMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
}

export interface ChatRequest {
  messages: ChatMessage[];
  context: UserContext;
}

export abstract class LlmAdapter {
  abstract recommend(
    request: RecommendationRequest,
    availableAnime: Anime[],
  ): Promise<RecommendationResponse>;

  abstract chat(request: ChatRequest): Promise<string>;
}

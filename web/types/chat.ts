import type { Anime } from "./anime";

export interface ChatMessage {
  id: string;
  content: string;
  isUser: boolean;
  timestamp: string;
  recommendations?: Anime[];
}

export interface AiRecommendationResponse {
  recommendations: Anime[];
  explanation: string;
}

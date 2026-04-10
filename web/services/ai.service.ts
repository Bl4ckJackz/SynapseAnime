import { apiClient } from "./api-client";
import type { ChatMessage } from "@/types/chat";

class AiService {
  async chat(
    messages: { role: string; content: string }[],
  ): Promise<ChatMessage> {
    return apiClient.post<ChatMessage>("/ai/chat", { messages });
  }

  async recommend(message: string): Promise<unknown> {
    return apiClient.post("/ai/recommend", { message });
  }
}

export const aiService = new AiService();

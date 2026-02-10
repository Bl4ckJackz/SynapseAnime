import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import axios from 'axios';
import {
  LlmAdapter,
  RecommendationRequest,
  RecommendationResponse,
  ChatRequest,
} from './llm.adapter';
import { Anime } from '../../entities/anime.entity';

@Injectable()
export class PerplexityAdapter extends LlmAdapter implements OnModuleInit {
  private readonly logger = new Logger(PerplexityAdapter.name);
  private readonly apiKey: string;
  private readonly apiUrl = 'https://api.perplexity.ai/chat/completions';

  constructor(private readonly configService: ConfigService) {
    super();
    this.apiKey = this.configService.get<string>('PERPLEXITY_API_KEY') || '';
    if (!this.apiKey) {
      this.logger.warn(
        'PERPLEXITY_API_KEY is not defined. AI features will not work.',
      );
    } else {
      this.logger.log(`Perplexity Adapter initialized with Key: ${this.apiKey.substring(0, 8)}...`);
    }
  }

  async recommend(
    request: RecommendationRequest,
    availableAnime: Anime[],
  ): Promise<RecommendationResponse> {
    // For specific recommendations, we can construct a prompt
    // However, since we are moving towards a unified chat,
    // we might want to leverage the chat method here or implement specific logic.
    // For now, let's use a simple implementation that calls the chat API.

    const prompt = `
      You are an expert anime recommender.
      User Context:
      - Preferred Genres: ${request.context.preferredGenres.join(', ')}
      - Recently Watched: ${request.context.watchedAnimeIds.slice(0, 5).join(', ')}

      Available Anime Database (subset):
      ${availableAnime
        .slice(0, 50) // Limit context size
        .map(
          (a) =>
            `- ID: ${a.id}, Title: ${a.title}, Genres: ${a.genres.join(', ')}, Rating: ${a.rating}`,
        )
        .join('\n')}

      User Request: "${request.message}"

      Recommend 5 anime from the provided list that match the user request and preferences.
      Return ONLY a JSON object with this format:
      {
        "message": "A friendly message explaining the recommendations",
        "recommendedAnimeIds": ["id1", "id2", ...]
      }
    `;

    try {
      const response = await this.callPerplexity([
        {
          role: 'system',
          content: 'You are a helpful anime assistant. Return JSON only.',
        },
        { role: 'user', content: prompt },
      ]);

      const content = response.choices[0].message.content;
      // Extract JSON from potential markdown code blocks
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        return JSON.parse(jsonMatch[0]);
      } else {
        return JSON.parse(content);
      }
    } catch (error) {
      this.logger.error(
        'Error generating recommendations via Perplexity',
        error,
      );
      // Fallback or empty response
      return {
        message:
          'Mi dispiace, non riesco a generare raccomandazioni al momento.',
        recommendedAnimeIds: [],
      };
    }
  }

  async chat(request: ChatRequest): Promise<string> {
    const { messages, context } = request;

    const systemPrompt = `
      You are an intelligent AI assistant for an Anime/Manga tracking application.
      You have access to the user's preferences and statistics.
      
      User Profile:
      - Favorite Genres: ${context.preferredGenres.join(', ')}
      - Watched Anime Count: ${context.watchedAnimeIds.length}
      
      Your goal is to helpful, friendly, and knowledgeable about anime and manga.
      You can recommend content, discuss trends, and provide news.
      Always answer in Italian.
    `;

    // Sanitize messages:
    // 1. Remove Any existing system messages (we add our own)
    // 2. Ensure the first message is from 'user' (remove leading assistant messages)
    // 3. Ensure alternating roles (merge consecutive same-role messages)

    let cleanMessages = messages.filter(m => m.role !== 'system');

    // Remove leading assistant messages
    while (cleanMessages.length > 0 && cleanMessages[0].role !== 'user') {
      cleanMessages.shift();
    }

    // If no messages left (e.g. only had assistant welcome), add a generic user prompt or fail gracefully
    if (cleanMessages.length === 0) {
      // This shouldn't happen if the user actually sent a message, 
      // but if they did, cleanMessages should have at least that one user message.
      // If purely empty, maybe return the welcome message again? 
      // But the controller calls this when user sends something.
      return "Ciao! Come posso aiutarti?";
    }

    // Merge consecutive messages
    const mergedMessages: any[] = [];
    if (cleanMessages.length > 0) {
      let currentMsg = { ...cleanMessages[0] };

      for (let i = 1; i < cleanMessages.length; i++) {
        const nextMsg = cleanMessages[i];
        if (nextMsg.role === currentMsg.role) {
          currentMsg.content += "\n\n" + nextMsg.content;
        } else {
          mergedMessages.push(currentMsg);
          currentMsg = { ...nextMsg };
        }
      }
      mergedMessages.push(currentMsg);
    }

    const fullMessages = [
      { role: 'system', content: systemPrompt },
      ...mergedMessages,
    ];

    try {
      this.logger.debug(`Sending ${fullMessages.length} messages to Perplexity`);
      const response = await this.callPerplexity(fullMessages);
      return response.choices[0].message.content;
    } catch (error) {
      this.logger.error('Error in chat via Perplexity', error);
      return 'Mi dispiace, si è verificato un errore nella comunicazione con il cervello AI.';
    }
  }

  async onModuleInit() {
    this.logger.log('Testing Perplexity connection...');
    try {
      await this.callPerplexity([{ role: 'user', content: 'Ping' }]);
      this.logger.log('Perplexity connection check: SUCCESS');
    } catch (e) {
      this.logger.error('Perplexity connection check: FAILED');
      // Already logged in callPerplexity
    }
  }

  private async callPerplexity(messages: any[]): Promise<any> {
    if (!this.apiKey) {
      this.logger.error('Perplexity API Key missing in callPerplexity');
      throw new Error('Perplexity API Key missing');
    }

    this.logger.debug(`Calling Perplexity with model: sonar`);

    try {
      const { data } = await axios.post(
        this.apiUrl,
        {
          model: 'sonar',
          messages: messages,
          temperature: 0.7,
        },
        {
          headers: {
            Authorization: `Bearer ${this.apiKey}`,
            'Content-Type': 'application/json',
          },
        },
      );
      return data;
    } catch (error) {
      // Log concise error details
      const errorInfo = {
        message: error.message,
        name: error.name,
        code: error.code,
        status: error.response?.status,
        data: error.response?.data,
      };

      this.logger.error(
        `Error calling Perplexity: ${error.message}`,
        JSON.stringify(errorInfo, null, 2)
      );
      // Ensure we see this validation error
      if (error.response?.data) {
        console.error("PERPLEXITY API ERROR BODY:", JSON.stringify(error.response.data, null, 2));
      }
      throw error;
    }
  }
}

import { Injectable } from '@nestjs/common';
import {
  LlmAdapter,
  RecommendationRequest,
  RecommendationResponse,
} from './llm.adapter';
import { Anime } from '../../entities/anime.entity';

@Injectable()
export class MockLlmAdapter extends LlmAdapter {
  async recommend(
    request: RecommendationRequest,
    availableAnime: Anime[],
  ): Promise<RecommendationResponse> {
    const { message, context } = request;
    const messageLower = message.toLowerCase();

    // Simple keyword-based matching for demo
    let matchedAnime = availableAnime.filter((anime) => {
      // Check if any genre matches user preferences
      const hasPreferredGenre = anime.genres.some((genre) =>
        context.preferredGenres.some(
          (pref) => pref.toLowerCase() === genre.toLowerCase(),
        ),
      );

      // Check if message mentions any genre
      const mentionsGenre = anime.genres.some((genre) =>
        messageLower.includes(genre.toLowerCase()),
      );

      // Check if message mentions the title
      const mentionsTitle = messageLower.includes(anime.title.toLowerCase());

      // Exclude already watched
      const notWatched = !context.watchedAnimeIds.includes(anime.id);

      return (
        (hasPreferredGenre || mentionsGenre || mentionsTitle) && notWatched
      );
    });

    // If no specific matches, recommend top rated
    if (matchedAnime.length === 0) {
      matchedAnime = availableAnime
        .filter((anime) => !context.watchedAnimeIds.includes(anime.id))
        .sort((a, b) => b.rating - a.rating)
        .slice(0, 5);
    }

    // Limit to top 5
    matchedAnime = matchedAnime.slice(0, 5);

    // Generate response message
    const responseMessage = this.generateResponse(message, matchedAnime);

    return {
      message: responseMessage,
      recommendedAnimeIds: matchedAnime.map((a) => a.id),
    };
  }

  private generateResponse(
    userMessage: string,
    recommendations: Anime[],
  ): string {
    if (recommendations.length === 0) {
      return 'Non ho trovato anime che corrispondono alla tua richiesta. Prova a descrivere meglio cosa stai cercando!';
    }

    const animeList = recommendations
      .map((a) => `• **${a.title}** (${a.genres.join(', ')}) - ⭐ ${a.rating}`)
      .join('\n');

    const intros = [
      'Ecco alcune raccomandazioni perfette per te! 🎬',
      'Ho trovato degli anime che potrebbero piacerti! ✨',
      'Basandomi sui tuoi gusti, ti consiglio questi: 🌟',
    ];

    const intro = intros[Math.floor(Math.random() * intros.length)];

    return `${intro}\n\n${animeList}\n\nVuoi saperne di più su qualcuno di questi?`;
  }
}
